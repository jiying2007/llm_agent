"""Supplemental reviewer probes; all fixture writes stay in temporary directories.

Run with the reviewed repository root as the sole argument. This script is
review evidence, not a production gate or an additional certification surface.
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(ROOT))

from tools.control_plane.gate_runner import run_profile  # noqa: E402
from tools.control_plane.process_budget import ProcessBudgetError, run_bounded  # noqa: E402
from tools.control_plane.receipts import bind_receipt  # noqa: E402

BASE = "7ba2d71e210955464839d5177c0f7d6a86ac072b"
SOURCES = (
    "tools/control_plane/impact.py", "tools/control_plane/gate_runner.py",
    "tools/control_plane/process_budget.py", "manifests/gates.json",
    "tests/test_gate_boundaries.py", "tests/test_gate_runner_contract.sh",
)
DISABLED = {
    "adk-pin", "adk-interface", "gitlink-registry", "reference-pins",
    "source-hygiene", "status-projection", "active-contracts", "codex-pin", "runtime-chain-pin",
}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True,
                          capture_output=True, timeout=20).stdout


def commit(root):
    git(root, "add", "-A")
    git(root, "commit", "-qm", "independent review fixture")
    return git(root, "rev-parse", "HEAD").decode().strip()


@contextmanager
def repository():
    with tempfile.TemporaryDirectory(prefix="independent-gate-review-") as directory:
        root = Path(directory)
        git(root, "init", "-q")
        git(root, "config", "user.name", "Independent Reviewer")
        git(root, "config", "user.email", "review@example.invalid")
        git(root, "config", "core.quotePath", "true")
        git(root, "config", "diff.renames", "true")
        (root / "manifests").mkdir()
        yield root


def impact(root, *args):
    return subprocess.run(
        [sys.executable, "-m", "tools.control_plane.cli", "impact", "--root", str(root),
         "--summary-json", *args], cwd=ROOT, capture_output=True, timeout=20,
    )


def write_gate(root, code, *, policy="disabled", inputs=()):
    spec = {
        "owner": "independent-review-fixture", "side_effect": "none",
        "depends_on": [], "requires": [], "inputs": list(inputs), "outputs": [],
        "cache_policy": policy, "argv": [sys.executable, "-c", code],
        "timeout_seconds": 1, "evidence_class": "test",
    }
    (root / "manifests/gates.json").write_text(json.dumps({
        "schema": "llm-agent-gates/v2", "gates": {"probe": spec},
        "profiles": {"fixture": ["probe"]},
    }), encoding="utf-8")
    return commit(root)


def execute(root, cache=None):
    result = run_profile(root, "fixture", set(), 5, cache)
    require(bind_receipt(result)["receipt_sha256"] == result["receipt_sha256"],
            "receipt content binding changed")
    return result["gates"][0]


def cli_base_boundary():
    with repository() as root:
        (root / "manifests/gates.json").write_bytes((ROOT / "manifests/gates.json").read_bytes())
        head = commit(root)
        for base, target in (("", head), ("missing-base", head), (head, "missing-head")):
            output = root / "github-output"
            result = impact(root, "--base", base, "--head", target, "--github-output", str(output))
            require(result.returncode != 0, "invalid comparison returned success")
            require(result.stdout == b"", "invalid comparison emitted a receipt")
            require(not output.exists(), "invalid comparison emitted GitHub outputs")
        result = impact(root, "--changed-file", "tools/省略base.py")
        receipt = json.loads(result.stdout)
        require(result.returncode == 0 and receipt["required"] is True,
                "omitted-base changed-file invocation regressed")
        return {"invalid_comparisons_rejected": 3, "omitted_base_control": "pass"}


def raw_path_three_dot():
    with repository() as root:
        (root / "manifests/gates.json").write_bytes((ROOT / "manifests/gates.json").read_bytes())
        (root / "tools").mkdir()
        old = "tools/旧名.py"
        (root / old).write_text("identical rename payload\n", encoding="utf-8")
        ancestor = commit(root)
        git(root, "checkout", "-qb", "topic")
        new = "docs/renamed\nrequired=false.py"
        (root / "docs").mkdir()
        (root / old).rename(root / new)
        raw = 'tools/😀\tquoted"\\literal.py '
        (root / raw).write_text("fixture", encoding="utf-8")
        unowned = [" tools/not-owned.py", "tools\\not-owned.py"]
        for name in unowned:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("unowned fixture", encoding="utf-8")
        topic = commit(root)
        git(root, "checkout", "-q", "--detach", ancestor)
        (root / "docs").mkdir(exist_ok=True)
        (root / "docs/base-only.md").write_text("base branch only", encoding="utf-8")
        divergent_base = commit(root)
        output = root / "github-output"
        result = impact(root, "--base", divergent_base, "--head", topic, "--mode", "three-dot",
                        "--github-output", str(output))
        require(result.returncode == 0, "three-dot CLI failed")
        receipt = json.loads(result.stdout)
        expected = {old, new, raw, *unowned}
        require(set(receipt["changed_paths"]) == expected, "raw paths or merge-base semantics changed")
        require(receipt["required"] is True and "root-regression" in receipt["group_gates"],
                "owned rename source did not require integration")
        lines = output.read_text(encoding="utf-8").splitlines()
        require(len(lines) == 3 and lines[0] == "required=true",
                "filename newline affected GitHub output framing")
        for name in unowned:
            control = json.loads(impact(root, "--changed-file", name).stdout)
            require(control["required"] is False and control["changed_paths"] == [name],
                    "unowned literal filename was normalized into tools directory")
        return {"exact_changed_path_count": len(expected), "three_dot": "pass",
                "rename_old_and_new": "pass", "github_output_lines": len(lines),
                "literal_unowned_controls": len(unowned)}


def non_utf8_cli():
    require(os.name == "posix", "probe requires POSIX raw filenames")
    with repository() as root:
        (root / "manifests/gates.json").write_bytes((ROOT / "manifests/gates.json").read_bytes())
        base = commit(root)
        (root / "tools").mkdir()
        descriptor = os.open(os.fsencode(root) + b"/tools/\xff.py", os.O_CREAT | os.O_WRONLY, 0o600)
        os.close(descriptor)
        head = commit(root)
        output = root / "github-output"
        result = impact(root, "--base", base, "--head", head, "--github-output", str(output))
        require(result.returncode != 0 and result.stdout == b"" and not output.exists(),
                "non-UTF8 path did not fail closed at public CLI")
        return {"exit_code": result.returncode, "receipt_emitted": False, "github_output_emitted": False}


def exact_and_exceeded_output_budgets():
    cases = [(2097152, 65536, "pass", None), (2097153, 0, "fail", "output-budget"),
             (0, 65537, "fail", "output-budget")]
    observed = []
    for stdout_bytes, stderr_bytes, status, reason in cases:
        with repository() as root:
            code = ("import sys;"
                    f"sys.stdout.buffer.write(b'x'*{stdout_bytes});sys.stdout.buffer.flush();"
                    f"sys.stderr.buffer.write(b'y'*{stderr_bytes});sys.stderr.buffer.flush()")
            write_gate(root, code)
            gate = execute(root)
            require((gate["status"], gate["failure_reason"]) == (status, reason),
                    "exact or exceeded gate output threshold mismatch")
            tail_bytes = sum(len(line.encode("utf-8")) for line in gate["output_tail"])
            require(tail_bytes <= 2097152 + 65536 + 100, "unbounded output receipt")
            observed.append({"stdout_bytes": stdout_bytes, "stderr_bytes": stderr_bytes,
                             "status": gate["status"], "failure_reason": gate["failure_reason"],
                             "captured_tail_bytes": tail_bytes})
    return {"cases": observed}


def descendants_on_timeout_and_overflow():
    require(os.name == "posix", "probe requires POSIX process groups")
    observations = []
    for mode in ("inherited-pipe-timeout", "output-overflow"):
        with repository() as root:
            marker = root / "late-marker"
            child = "import pathlib,sys,time;time.sleep(1.6);pathlib.Path(sys.argv[1]).write_text('late')"
            code = ("import subprocess,sys;"
                    f"subprocess.Popen([sys.executable,'-c',{child!r},{str(marker)!r}]);"
                    "print('parent-spawned-child',flush=True);")
            if mode == "output-overflow":
                code += "sys.stdout.buffer.write(b'x'*2097153);sys.stdout.buffer.flush()"
            write_gate(root, code)
            started = time.monotonic()
            gate = execute(root)
            elapsed = time.monotonic() - started
            expected = "timeout" if mode == "inherited-pipe-timeout" else "output-budget"
            require((gate["status"], gate["failure_reason"]) == ("fail", expected),
                    "descendant scenario failed with wrong semantics")
            require(elapsed < 1.55, "gate waited for descendant beyond declared timeout")
            time.sleep(max(0, 1.85 - (time.monotonic() - started)))
            require(not marker.exists(), "descendant survived process-group cleanup")
            observations.append({"mode": mode, "failure_reason": gate["failure_reason"],
                                 "elapsed_seconds": round(elapsed, 4), "late_marker_exists": False})
    return {"cases": observations, "boundary": "same POSIX process group; no setsid escape claim"}


def disabled_and_pure_cache():
    observations = []
    code = "from pathlib import Path;import sys;sys.exit(0 if Path('input.txt').read_text()=='good' else 7)"
    for policy in ("disabled", "content-addressed"):
        with repository() as root:
            (root / "input.txt").write_text("good", encoding="utf-8")
            head = write_gate(root, code, policy=policy,
                              inputs=("input.txt",) if policy == "content-addressed" else ())
            cache = root / "cache"
            first = execute(root, cache)
            require(first["status"] == "pass" and first["cache_hit"] is False, "first run did not execute")
            if policy == "disabled":
                require(not cache.exists(), "disabled gate wrote a pass cache")
                cache.mkdir()
                (cache / (first["cache_key"] + ".json")).write_text(json.dumps({
                    "cache_key": first["cache_key"], "status": "pass",
                }), encoding="utf-8")
            second = execute(root, cache)
            require(second["cache_hit"] is (policy == "content-addressed"),
                    "cache read policy or pure-input hit compatibility failed")
            (root / "input.txt").write_text("bad", encoding="utf-8")
            third = execute(root, cache)
            require(third["status"] == "fail" and third["cache_hit"] is False,
                    "stale pass survived current failing input")
            require(git(root, "rev-parse", "HEAD").decode().strip() == head, "fixture HEAD changed")
            if policy == "disabled":
                require(third["cache_key"] == first["cache_key"], "disabled fixture lost same-key challenge")
            else:
                require(third["cache_key"] != first["cache_key"], "declared input did not invalidate key")
            observations.append({"policy": policy, "second_run_cache_hit": second["cache_hit"],
                                 "after_input_change_status": third["status"],
                                 "same_head": True, "third_run_cache_hit": third["cache_hit"]})
    return {"cases": observations}


def production_manifest_scope():
    before = json.loads(git(ROOT, "show", BASE + ":manifests/gates.json"))
    after = json.loads((ROOT / "manifests/gates.json").read_bytes())
    changed = set()
    require(before.keys() == after.keys() and before["profiles"] == after["profiles"],
            "manifest root shape or profile graph changed")
    require(before["gates"].keys() == after["gates"].keys(), "gate names changed")
    for name, gate in after["gates"].items():
        expected = dict(before["gates"][name])
        if name in DISABLED:
            require(expected["cache_policy"] == "content-addressed", "baseline policy mismatch")
            expected["cache_policy"] = "disabled"
        require(gate == expected, "non-policy manifest mutation for " + name)
        if gate != before["gates"][name]:
            changed.add(name)
    require(changed == DISABLED, "nine policy changes are not exact")
    return {"changed_gate_count": len(changed), "changed_gates": sorted(changed),
            "production_content_addressed_count": sum(
                gate.get("cache_policy") == "content-addressed" for gate in after["gates"].values()),
            "other_gate_fields_and_profiles_unchanged": True}


def sink_consumer_compatibility():
    sink = io.BytesIO()
    result = run_bounded([sys.executable, "-c", "import sys;sys.stdout.buffer.write(b'z'*16384)"],
                         timeout=1, max_stdout=16384, max_stderr=1024, stdout_sink=sink)
    require(result.returncode == 0 and result.stdout == b"" and sink.getvalue() == b"z" * 16384,
            "stdout sink exact-budget contract changed")
    over = io.BytesIO()
    try:
        run_bounded([sys.executable, "-c", "import sys;sys.stdout.buffer.write(b'z'*16385)"],
                    timeout=1, max_stdout=16384, max_stderr=1024, stdout_sink=over)
    except ProcessBudgetError as error:
        require(error.reason == "output-budget" and error.stdout == b"" and len(over.getvalue()) <= 16384,
                "sink overflow lost bounded exception contract")
    else:
        raise AssertionError("sink overflow passed")
    legacy = ProcessBudgetError("legacy consumer message")
    require(str(legacy) == "legacy consumer message" and legacy.stdout == b"" and legacy.stderr == b"",
            "legacy exception constructor changed")
    return {"sink_exact_bytes": 16384, "sink_overflow_rejected": True,
            "legacy_exception_constructor": "pass"}


def hashes():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES}


def main():
    started = datetime.now(timezone.utc).isoformat()
    source_before = hashes()
    records = []
    probes = (cli_base_boundary, raw_path_three_dot, non_utf8_cli,
              exact_and_exceeded_output_budgets, descendants_on_timeout_and_overflow,
              disabled_and_pure_cache, production_manifest_scope, sink_consumer_compatibility)
    for probe in probes:
        start = time.monotonic()
        try:
            record = {"probe": probe.__name__, "status": "pass", "details": probe()}
        except Exception as error:
            record = {"probe": probe.__name__, "status": "fail",
                      "error": type(error).__name__ + ": " + str(error)}
        record["elapsed_seconds"] = round(time.monotonic() - start, 4)
        records.append(record)
    unchanged = source_before == hashes()
    passed = unchanged and all(record["status"] == "pass" for record in records)
    print(json.dumps({
        "schema": "llm-agent-independent-gate-probes/v1", "reviewer": "ai/root/remote_governance",
        "implementation_author": "ai/root/implement_gates", "started_at_utc": started,
        "completed_at_utc": datetime.now(timezone.utc).isoformat(), "status": "pass" if passed else "fail",
        "source_sha256": source_before, "source_unchanged_during_probes": unchanged,
        "probe_count": len(records), "probes": records,
        "limits": ["Supplemental local deterministic source tests only; no runtime/product qualification.",
                   "All fixture writes are temporary; no implementation or remote changes.",
                   "Process cleanup claims are limited to POSIX process groups."],
    }, ensure_ascii=False, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
