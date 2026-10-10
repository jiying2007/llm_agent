#!/usr/bin/env python3
"""Collect schema-bound Software M5 measured-runtime smoke evidence.

The collector can either execute the pinned ADK runtime evaluator or validate and
wrap an existing raw runtime report. Production evidence is fail-closed against
adk.lock and the checked-out agent-dev-kit gitlink identity.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import shlex
import subprocess
import tempfile
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


EVIDENCE_SCHEMA = "llm-agent-runtime-smoke-evidence/v1"
DEFAULT_MODEL = "gpt-6.1-sol"
DEFAULT_REASONING_EFFORT = "medium"
REASONING_EFFORTS = ("low", "medium", "high", "xhigh", "max")
DEFAULT_LIMIT = 1
MAX_JSON_BYTES = 2 * 1024 * 1024
TASK_IDENTITY_SCOPE = "parsed-ordered-selected-task-sequence"
GRADER_CONTRACT = "adk-runtime-routing-grader/v1"
PROMPT_VERSION = "adk-runtime-routing-v1"


class SmokeEvidenceError(RuntimeError):
    """Fail-closed runtime smoke evidence error."""


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def _sha256_file(path: Path) -> str:
    from tools.codex_assets.intake_io import _sha256_file as safe_hash
    try:
        return safe_hash(path.absolute())
    except (OSError, ValueError, RuntimeError) as exc:
        raise SmokeEvidenceError("cannot safely hash runtime evidence input") from exc


def _unique_json_fields(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise SmokeEvidenceError("runtime evidence input contains duplicate JSON fields")
        result[key] = value
    return result


def _reject_nonfinite_number(raw: str) -> float:
    value = float(raw)
    if not math.isfinite(value):
        raise SmokeEvidenceError("runtime evidence input contains a non-finite number")
    return value


def _load_json(path: Path, label: str) -> dict[str, Any]:
    return _load_json_snapshot(path, label)[0]


def _load_json_snapshot(path: Path, label: str) -> tuple[dict[str, Any], bytes]:
    try:
        from tools.codex_assets.intake_io import read_bytes
        raw = read_bytes(path.absolute(), label=label, max_bytes=MAX_JSON_BYTES)
        if len(raw) > MAX_JSON_BYTES:
            raise SmokeEvidenceError(f"{label} exceeds byte budget")
        value = json.loads(
            raw.decode("utf-8"), object_pairs_hook=_unique_json_fields,
            parse_constant=_reject_nonfinite_number, parse_float=_reject_nonfinite_number,
        )
    except (OSError, UnicodeError, ValueError, RuntimeError) as exc:
        raise SmokeEvidenceError(f"invalid {label}: {path}") from exc
    if not isinstance(value, dict):
        raise SmokeEvidenceError(f"{label} must be a JSON object")
    return value, raw


def _write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _preflight_new_output(path: Path) -> None:
    if path.is_symlink() or any(parent.is_symlink() for parent in path.parents):
        raise SmokeEvidenceError("diagnostic output contains a symbolic link")
    if path.exists():
        raise SmokeEvidenceError("diagnostic output already exists")


def _write_new_json(path: Path, value: Mapping[str, Any]) -> None:
    """Create exclusively through directory descriptors; never follow links."""
    path = path.absolute()
    descriptor = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parent.parts[1:]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=descriptor)
            os.close(descriptor)
            descriptor = child
        output = os.open(path.name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                         0o600, dir_fd=descriptor)
        with os.fdopen(output, "w", encoding="utf-8") as stream:
            json.dump(value, stream, ensure_ascii=False, sort_keys=True, indent=2)
            stream.write("\n")
    except OSError as exc:
        raise SmokeEvidenceError("cannot safely create diagnostic output") from exc
    finally:
        os.close(descriptor)


def _read_lock(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise SmokeEvidenceError(f"cannot read ADK lock: {path}") from exc
    for line in lines:
        if not line or line.lstrip().startswith("#"):
            continue
        if "=" not in line:
            raise SmokeEvidenceError(f"invalid ADK lock line: {line}")
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    required = (
        "agent-dev-kit.version",
        "agent-dev-kit.commit",
        "agent-dev-kit.tree",
        "agent-dev-kit.manifest_blob",
    )
    missing = [key for key in required if not values.get(key)]
    if missing:
        raise SmokeEvidenceError("ADK lock is missing fields: " + ", ".join(missing))
    return values


def _run_git(adk_root: Path, *args: str) -> str:
    try:
        completed = subprocess.run(
            ["git", "-C", str(adk_root), *args],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeEvidenceError("cannot inspect checked-out agent-dev-kit git identity") from exc
    if completed.returncode != 0 or not completed.stdout.strip():
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise SmokeEvidenceError(f"cannot inspect checked-out agent-dev-kit git identity: {detail}")
    return completed.stdout.strip()


def _manifest_digest(manifest: Mapping[str, Any]) -> str:
    payload = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _parse_generated_at(value: str | None) -> datetime:
    if value is None:
        return datetime.now(timezone.utc).replace(microsecond=0)
    if not value.endswith("Z"):
        raise SmokeEvidenceError("--generated-at must be an ISO-8601 UTC timestamp ending in Z")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise SmokeEvidenceError("--generated-at is invalid") from exc
    return parsed.astimezone(timezone.utc).replace(microsecond=0)


def _format_time(value: datetime) -> str:
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _reject_hidden_index_entries(root: Path) -> None:
    """A clean status cannot certify source when Git hides tracked changes."""
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-v", "-z"], check=False,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeEvidenceError("cannot inspect source index flags") from exc
    if result.returncode != 0:
        raise SmokeEvidenceError("cannot inspect source index flags")
    if any(entry[:1] == b"S" or entry[:1].islower()
           for entry in result.stdout.split(b"\0") if entry):
        raise SmokeEvidenceError("source index contains assume-unchanged or skip-worktree entries")


def _verify_pinned_bytes(adk_root: Path, relative: str, raw: bytes) -> None:
    """Hash the consumed snapshot without invoking worktree filters."""
    expected = _run_git(adk_root, "rev-parse", "HEAD:" + relative)
    try:
        result = subprocess.run(
            ["git", "-C", str(adk_root), "hash-object", "--no-filters", "--stdin"],
            input=raw, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeEvidenceError("cannot bind consumed source to pinned blob") from exc
    if result.returncode != 0 or result.stdout.strip() != expected.encode("ascii"):
        raise SmokeEvidenceError("consumed source bytes differ from pinned HEAD blob: " + relative)


def _reject_ignored_executable_inputs(root: Path) -> None:
    """Ignored sourceless modules can run despite a clean Git status."""
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files", "--others", "--ignored", "--exclude-standard", "-z"],
            check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeEvidenceError("cannot inspect ignored source inputs") from exc
    if result.returncode != 0:
        raise SmokeEvidenceError("cannot inspect ignored source inputs")
    for entry in result.stdout.split(b"\0"):
        if not entry:
            continue
        path = Path(entry.decode("utf-8"))
        governed = len(path.parts) == 1 or path.parts[0] in {"src", "scripts", "tools", "tests"}
        normal_cache = path.parent.name == "__pycache__" and path.suffix == ".pyc"
        if governed and not normal_cache and path.suffix.lower() in {".py", ".pyc", ".pyo", ".sh", ".so", ".pyd"}:
            raise SmokeEvidenceError("source contains ignored executable inputs")


def _validate_source_identity(root: Path) -> tuple[dict[str, str], dict[str, Any], Path]:
    lock = _read_lock(root / "adk.lock")
    source_path = root / "agent-dev-kit"
    if source_path.is_symlink() or not source_path.is_dir():
        raise SmokeEvidenceError("agent-dev-kit source must be a local non-symlink checkout")
    adk_root = source_path.resolve()
    if Path(_run_git(adk_root, "rev-parse", "--show-toplevel")).resolve() != adk_root:
        raise SmokeEvidenceError("agent-dev-kit source is not an independent checkout")
    manifest_path = adk_root / "manifest.json"
    if not manifest_path.is_file():
        raise SmokeEvidenceError("agent-dev-kit/manifest.json is missing; initialize the pinned gitlink/submodule first")
    manifest, manifest_bytes = _load_json_snapshot(manifest_path, "ADK manifest")
    if manifest.get("version") != lock["agent-dev-kit.version"]:
        raise SmokeEvidenceError("ADK manifest version does not match adk.lock")

    actual_commit = _run_git(adk_root, "rev-parse", "HEAD")
    actual_tree = _run_git(adk_root, "rev-parse", "HEAD^{tree}")
    actual_manifest_blob = _run_git(adk_root, "rev-parse", "HEAD:manifest.json")
    expected = {
        "commit": lock["agent-dev-kit.commit"],
        "tree": lock["agent-dev-kit.tree"],
        "manifest_blob": lock["agent-dev-kit.manifest_blob"],
    }
    actual = {
        "commit": actual_commit,
        "tree": actual_tree,
        "manifest_blob": actual_manifest_blob,
    }
    for field, value in expected.items():
        if actual[field] != value:
            raise SmokeEvidenceError(f"checked-out ADK {field} does not match adk.lock")
    _reject_hidden_index_entries(adk_root)
    _reject_ignored_executable_inputs(adk_root)
    _verify_pinned_bytes(adk_root, "manifest.json", manifest_bytes)
    state = subprocess.run(
        ["git", "-C", str(adk_root), "status", "--porcelain", "--untracked-files=all"],
        check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20,
    )
    if state.returncode != 0 or state.stdout.strip():
        raise SmokeEvidenceError("checked-out ADK source must be clean for measured runtime evidence")
    return lock, manifest, adk_root


def _selected_tasks(path: Path, limit: int) -> tuple[list[dict[str, Any]], str]:
    selected, digest, _ = _selected_task_snapshot(path, limit)
    return selected, digest


def _selected_task_snapshot(path: Path, limit: int) -> tuple[list[dict[str, Any]], str, bytes]:
    try:
        from tools.codex_assets.intake_io import read_bytes
        raw = read_bytes(path.absolute(), label="runtime smoke task dataset", max_bytes=1024 * 1024)
        if len(raw) > 1024 * 1024:
            raise SmokeEvidenceError("runtime smoke task dataset exceeds byte budget")
        lines = raw.decode("utf-8").splitlines()
        tasks = [json.loads(
            line, object_pairs_hook=_unique_json_fields,
            parse_constant=_reject_nonfinite_number, parse_float=_reject_nonfinite_number,
        ) for line in lines if line.strip()]
    except (OSError, UnicodeError, ValueError, RuntimeError) as exc:
        raise SmokeEvidenceError("runtime smoke task dataset is invalid") from exc
    if len(tasks) < limit or any(not isinstance(task, dict) for task in tasks):
        raise SmokeEvidenceError("runtime smoke task dataset has insufficient valid cases")
    selected = tasks[:limit]
    for task in selected:
        if any(not isinstance(task.get(field), str) or not task[field] for field in ("id", "prompt", "category", "expected_skill")):
            raise SmokeEvidenceError("runtime smoke task labels are invalid")
        if not isinstance(task.get("expected_safe"), bool):
            raise SmokeEvidenceError("runtime smoke task safety label is invalid")
    if len({task["id"] for task in selected}) != limit:
        raise SmokeEvidenceError("runtime smoke task IDs are duplicated")
    digest = hashlib.sha256((_canonical(selected) + b"\n")).hexdigest()
    return selected, digest, raw


def _validate_raw_report(
    report: Mapping[str, Any], model: str, limit: int, manifest_digest: str,
    selected_tasks: Sequence[Mapping[str, Any]], task_digest: str,
) -> None:
    if report.get("schema_version") != 1 or report.get("suite") != "runtime-routing":
        raise SmokeEvidenceError("runtime report schema/suite is invalid")
    if report.get("runtime") != "codex" or report.get("condition") != "adk":
        raise SmokeEvidenceError("runtime report must be codex/adk")
    if report.get("requested_model") != model:
        raise SmokeEvidenceError("runtime report requested_model does not match collector model")
    if (
        report.get("manifest_sha256") != manifest_digest
        or report.get("task_set_sha256") != task_digest
        or report.get("task_set_identity_scope") != TASK_IDENTITY_SCOPE
        or report.get("task_snapshot_frozen") is not True
        or report.get("source_snapshot_atomic") is not False
        or report.get("grader_contract") != GRADER_CONTRACT
        or report.get("prompt_version") != PROMPT_VERSION
    ):
        raise SmokeEvidenceError("runtime report source, task or grader identity is invalid")
    reported_models = report.get("reported_models")
    if not isinstance(reported_models, list) or not reported_models or any(
        not isinstance(item, str) or not item for item in reported_models
    ):
        raise SmokeEvidenceError("runtime report has no valid observed model")
    if reported_models != [model]:
        raise SmokeEvidenceError("runtime report observed model differs from the exact requested model")
    if not isinstance(report.get("runtime_version"), str) or not str(report["runtime_version"]).strip():
        raise SmokeEvidenceError("runtime report runtime_version is missing")
    if report.get("status") != "pass":
        raise SmokeEvidenceError("runtime report is not passing")
    total = report.get("total")
    passed = report.get("passed")
    if isinstance(total, bool) or not isinstance(total, int) or total != limit:
        raise SmokeEvidenceError("runtime report total does not match requested limit")
    if type(passed) is not int or passed != total:
        raise SmokeEvidenceError("runtime report did not pass every measured task")
    gates = report.get("quality_gate")
    from tools.codex_assets.m5_runtime_contract import GATES
    if not isinstance(gates, dict) or set(gates) != GATES or not all(value is True for value in gates.values()):
        raise SmokeEvidenceError("runtime report quality gates are not all passing")
    results = report.get("results")
    if not isinstance(results, list) or len(results) != total:
        raise SmokeEvidenceError("runtime report result count is invalid")
    observed_models: set[str] = set()
    for index, item in enumerate(results):
        if not isinstance(item, dict):
            raise SmokeEvidenceError(f"runtime result {index} is not an object")
        if item.get("status") != "pass" or item.get("route_ok") is not True or item.get("safe_ok") is not True:
            raise SmokeEvidenceError(f"runtime result {index} is not a complete route+safety pass")
        if item.get("error") is not None:
            raise SmokeEvidenceError(f"runtime result {index} contains a runtime error")
        task = selected_tasks[index]
        prompt_digest = hashlib.sha256(task["prompt"].encode("utf-8")).hexdigest()
        if (
            item.get("id") != task["id"]
            or item.get("prompt_sha256") != prompt_digest
            or item.get("category") != task["category"]
            or item.get("expected_skill") != task["expected_skill"]
            or item.get("expected_safe") is not task["expected_safe"]
            or item.get("expected_route") != task["expected_skill"]
            or item.get("actual_skill") != task["expected_skill"]
            or item.get("actual_safe") is not task["expected_safe"]
            or item.get("requested_model") != model
            or not isinstance(item.get("reported_models"), list)
            or not item["reported_models"]
        ):
            raise SmokeEvidenceError(f"runtime result {index} differs from frozen task or model identity")
        if any(not isinstance(observed, str) or not observed for observed in item["reported_models"]):
            raise SmokeEvidenceError(f"runtime result {index} has invalid observed models")
        observed_models.update(item["reported_models"])
        usage = item.get("usage")
        if (
            not isinstance(usage, dict)
            or isinstance(usage.get("total_tokens"), bool)
            or not isinstance(usage.get("total_tokens"), int)
            or usage["total_tokens"] < 0
        ):
            raise SmokeEvidenceError(f"runtime result {index} token usage is invalid")
    if sorted(observed_models) != reported_models:
        raise SmokeEvidenceError("runtime report observed model list differs from its cases")


def _execute_runtime(
    root: Path,
    adk_root: Path,
    raw_output: Path,
    model: str,
    limit: int,
    tasks: Path,
    runtime_path: Path | None = None,
    reasoning_effort: str = DEFAULT_REASONING_EFFORT,
    observe_provider_model: bool = False,
) -> dict[str, Any] | None:
    if reasoning_effort not in REASONING_EFFORTS:
        raise SmokeEvidenceError("unsupported reasoning effort")
    if observe_provider_model and runtime_path is None:
        raise SmokeEvidenceError("provider observation requires a selected executable")
    failure_path = raw_output.with_name(raw_output.stem + "-observation-failure.json")
    if observe_provider_model:
        _preflight_new_output(failure_path)
    # -B only prevents cache writes; a fresh prefix also isolates cache reads.
    with tempfile.TemporaryDirectory(prefix="m5-runtime-pycache-") as directory:
        environment = dict(os.environ, PYTHONPYCACHEPREFIX=directory)
        environment.pop("PYTHONPATH", None)
        for key in list(environment):
            if key in {"BASH_ENV", "ENV"} or key.startswith("BASH_FUNC_"):
                environment.pop(key)
        if runtime_path is not None:
            # Keep the original launcher path/argv[0], including relative resources.
            launcher = Path(directory) / "codex"
            options = ["--ignore-user-config", "-c", 'model_reasoning_effort="' + reasoning_effort + '"']
            quoted_runtime = shlex.quote(str(runtime_path))
            executor = quoted_runtime + " exec "
            if observe_provider_model:
                from tools.codex_assets.intake_io import read_bytes
                helper = Path(__file__).with_name("codex_model_observer.py")
                helper_bytes = read_bytes(helper.absolute(), label="provider observer", max_bytes=256 * 1024)
                frozen_helper = Path(directory) / "observer.py"
                frozen_helper.write_bytes(helper_bytes)
                receipts = Path(directory) / "observations"
                executor = " ".join(shlex.quote(value) for value in
                                    (sys.executable, "-I", str(frozen_helper), "--allow-network", "--binary",
                                     str(runtime_path), "--receipt-dir", str(receipts), "--")) + " "
            launcher.write_text('#!/bin/sh\nif [ "$1" = "exec" ]; then\nshift\nexec '
                                + executor
                                + " ".join(shlex.quote(option) for option in options) + ' "$@"\nfi\nexec '
                                + quoted_runtime + ' "$@"\n')
            launcher.chmod(0o700)
            environment["PATH"] = directory + os.pathsep + environment.get("PATH", os.defpath)
        try:
            _execute_runtime_in_environment(root, adk_root, raw_output, model, limit, tasks, environment)
        except SmokeEvidenceError:
            if observe_provider_model:
                failures = [_load_json(path, "provider failure diagnostics")
                            for path in sorted(receipts.glob("*.failure.json"))]
                _write_new_json(failure_path,
                            {"status": "fail", "qualification": False, "diagnostics": failures})
            raise
        if observe_provider_model:
            records = [_load_json(path, "provider model observation") for path in sorted(receipts.glob("*.json"))]
            if len(records) != limit or any(record.get("model") != model or record.get("completed") is not True
                                            for record in records):
                raise SmokeEvidenceError("provider model observations are incomplete")
            return {"scope": "upstream-response-openai-model-header", "adapter_sha256": hashlib.sha256(helper_bytes).hexdigest(),
                    "records": records}
    return None


def _execute_runtime_in_environment(
    root: Path, adk_root: Path, raw_output: Path, model: str, limit: int,
    tasks: Path, environment: Mapping[str, str],
) -> None:
    devkit = adk_root / "scripts" / "devkit.sh"
    if not devkit.is_file():
        raise SmokeEvidenceError("pinned ADK devkit.sh is missing")
    if not tasks.is_file():
        raise SmokeEvidenceError(f"runtime smoke tasks are missing: {tasks}")
    try:
        capability = subprocess.run(
            ["bash", str(devkit), "eval", "run", "--help"], cwd=str(adk_root),
            env=environment, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeEvidenceError("cannot inspect pinned ADK runtime eval capability") from exc
    if capability.returncode != 0 or any(
        option not in capability.stdout for option in ("--max-new-results", "--approve-unknown-cost")
    ):
        raise SmokeEvidenceError("pinned ADK runtime eval lacks the bounded-cost CLI contract")
    raw_output.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "bash",
        str(devkit),
        "eval",
        "run",
        "--suite",
        "runtime",
        "--tasks",
        str(tasks),
        "--limit",
        str(limit),
        "--runtime",
        "codex",
        "--model",
        model,
        "--condition",
        "adk",
        "--execute",
        "--max-new-results",
        str(limit),
        "--approve-unknown-cost",
        "--output",
        str(raw_output),
    ]
    try:
        completed = subprocess.run(command, cwd=str(adk_root), env=environment, check=False, timeout=600)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeEvidenceError("ADK runtime smoke execution could not complete") from exc
    if completed.returncode != 0:
        raise SmokeEvidenceError(f"ADK runtime smoke execution failed with exit code {completed.returncode}")
    if not raw_output.is_file():
        raise SmokeEvidenceError("ADK runtime smoke execution did not write the raw report")


def collect(
    root: Path,
    output: Path,
    *,
    raw_result: Path | None,
    raw_output: Path | None,
    execute: bool,
    model: str,
    limit: int,
    tasks: Path | None,
    runtime_binary: Path | None,
    generated_at: str | None,
    review_days: int,
    approve_unknown_cost: bool = False,
    reasoning_effort: str = DEFAULT_REASONING_EFFORT,
    observe_provider_model: bool = False,
    allow_network: bool = False,
) -> dict[str, Any]:
    if observe_provider_model and (not execute or not allow_network or limit != 1):
        raise SmokeEvidenceError("provider observation requires --execute --allow-network and --limit 1")
    if reasoning_effort not in REASONING_EFFORTS:
        raise SmokeEvidenceError("unsupported reasoning effort")
    if execute and not approve_unknown_cost:
        raise SmokeEvidenceError("--execute requires --approve-unknown-cost")
    if not execute and approve_unknown_cost:
        raise SmokeEvidenceError("--approve-unknown-cost requires --execute")
    root = root.resolve()
    lock, manifest, adk_root = _validate_source_identity(root)
    if execute == (raw_result is not None):
        raise SmokeEvidenceError("choose exactly one of --execute or --raw-result")
    if limit < 1 or limit > 10:
        raise SmokeEvidenceError("--limit must be between 1 and 10")
    if review_days < 1 or review_days > 90:
        raise SmokeEvidenceError("--review-days must be between 1 and 90")

    model_observation = None
    if execute:
        if raw_output is None:
            raise SmokeEvidenceError("--raw-output is required with --execute")
        raw_path = raw_output.absolute()
        task_path = tasks.absolute() if tasks else adk_root / "tests" / "fixtures" / "software_m5_eval_tasks.jsonl"
        # Validate the lexical input and output before any potentially paid eval.
        selected_tasks, task_digest, frozen_tasks = _selected_task_snapshot(task_path, limit)
        if task_path == adk_root / "tests/fixtures/software_m5_eval_tasks.jsonl":
            _verify_pinned_bytes(adk_root, "tests/fixtures/software_m5_eval_tasks.jsonl", frozen_tasks)
        if raw_path.is_symlink() or any(parent.is_symlink() for parent in raw_path.parents):
            raise SmokeEvidenceError("runtime raw output contains a symbolic link")
        if raw_path.exists():
            raise SmokeEvidenceError("runtime raw output already exists")
        from tools.codex_assets.intake_io import read_bytes
        executable = str(runtime_binary.absolute()) if runtime_binary else shutil.which("codex")
        if executable is None:
            raise SmokeEvidenceError("codex runtime binary is not installed")
        runtime_path = Path(executable).resolve()
        if not runtime_path.is_file() or not os.access(runtime_path, os.X_OK):
            raise SmokeEvidenceError("selected runtime binary is not an executable regular file")
        runtime_digest = _sha256_file(runtime_path)
        with tempfile.TemporaryDirectory(prefix="m5-runtime-tasks-") as directory:
            execution_tasks = Path(directory) / "tasks.jsonl"
            execution_tasks.write_bytes(frozen_tasks)
            options = {"observe_provider_model": True} if observe_provider_model else {}
            model_observation = _execute_runtime(root, adk_root, raw_path, model, limit, execution_tasks,
                                                 Path(executable).absolute(), reasoning_effort, **options)
        if Path(executable).resolve() != runtime_path or _sha256_file(runtime_path) != runtime_digest:
            raise SmokeEvidenceError("selected runtime binary changed during execution")
        if read_bytes(task_path, label="runtime tasks", max_bytes=1024 * 1024) != frozen_tasks:
            raise SmokeEvidenceError("runtime task dataset changed during execution")
    else:
        assert raw_result is not None
        raw_path = raw_result.absolute()
        task_path = tasks.absolute() if tasks else adk_root / "tests" / "fixtures" / "software_m5_eval_tasks.jsonl"
        selected_tasks, task_digest, frozen_tasks = _selected_task_snapshot(task_path, limit)
        if task_path == adk_root / "tests/fixtures/software_m5_eval_tasks.jsonl":
            _verify_pinned_bytes(adk_root, "tests/fixtures/software_m5_eval_tasks.jsonl", frozen_tasks)

    report, raw_snapshot = _load_json_snapshot(raw_path, "runtime smoke report")
    _validate_raw_report(report, model, limit, _manifest_digest(manifest), selected_tasks, task_digest)
    post_lock, post_manifest, post_adk_root = _validate_source_identity(root)
    if post_lock != lock or _manifest_digest(post_manifest) != _manifest_digest(manifest) or post_adk_root != adk_root:
        raise SmokeEvidenceError("ADK source identity changed during runtime smoke collection")

    if not execute:
        runtime_path = runtime_binary.resolve() if runtime_binary else None
        if runtime_path is None:
            executable = shutil.which("codex")
            if executable is None:
                raise SmokeEvidenceError("codex runtime binary is not installed")
            runtime_path = Path(executable).resolve()
        runtime_digest = _sha256_file(runtime_path)
    elif _sha256_file(runtime_path) != runtime_digest:
        raise SmokeEvidenceError("selected runtime binary changed before evidence publication")

    generated = _parse_generated_at(generated_at)
    review_after = (generated + timedelta(days=review_days)).date().isoformat()
    manifest_version = str(manifest["version"])
    evidence_id = f"codex-{manifest_version}-runtime-smoke-{generated.date().strftime('%Y%m%d')}"

    evidence: dict[str, Any] = {
        "schema": EVIDENCE_SCHEMA,
        "evidence_id": evidence_id,
        "generated_at": _format_time(generated),
        "review_after": review_after,
        "runtime": "codex",
        "runtime_version": report["runtime_version"],
        "runtime_binary_sha256": runtime_digest,
        "requested_model": model,
        "adk_commit": lock["agent-dev-kit.commit"],
        "adk_tree": lock["agent-dev-kit.tree"],
        "manifest_blob": lock["agent-dev-kit.manifest_blob"],
        "manifest_version": manifest_version,
        "manifest_sha256": _manifest_digest(manifest),
        "raw_result_sha256": hashlib.sha256(raw_snapshot).hexdigest(),
        "collection": {
            "collector": "tools.codex_assets.runtime_smoke_evidence",
            "runtime_identity": "selected-executable-pre-post-sha256" if execute else "unverified-import",
            "requested_reasoning_effort": reasoning_effort if execute else None,
            "reasoning_identity_scope": "cli-config-override" if execute else "unverified-import",
            "user_config_loaded": False if execute else None,
            "task_limit": limit,
            "tasks_sha256": hashlib.sha256(frozen_tasks).hexdigest(),
            "raw_report_retained_in_repository": False,
        },
        "result": report,
        "raw_content_stored": False,
    }
    if observe_provider_model:
        evidence["collection"]["model_observation"] = model_observation
    evidence["evidence_sha256"] = _digest(evidence)
    _write_json(output.resolve(), evidence)
    return evidence


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="runtime_smoke_evidence")
    parser.add_argument("--root", default=".")
    parser.add_argument("--output", required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--execute", action="store_true")
    mode.add_argument("--raw-result")
    parser.add_argument("--approve-unknown-cost", action="store_true")
    parser.add_argument("--observe-provider-model", action="store_true")
    parser.add_argument("--allow-network", action="store_true")
    parser.add_argument("--raw-output")
    parser.add_argument("--tasks")
    parser.add_argument("--runtime-binary")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--reasoning-effort", choices=REASONING_EFFORTS, default=DEFAULT_REASONING_EFFORT)
    parser.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    parser.add_argument("--generated-at")
    parser.add_argument("--review-days", type=int, default=30)
    parser.add_argument("--summary-json", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        evidence = collect(
            Path(args.root),
            Path(args.output),
            raw_result=Path(args.raw_result) if args.raw_result else None,
            raw_output=Path(args.raw_output) if args.raw_output else None,
            execute=bool(args.execute),
            model=args.model,
            limit=args.limit,
            tasks=Path(args.tasks) if args.tasks else None,
            runtime_binary=Path(args.runtime_binary) if args.runtime_binary else None,
            generated_at=args.generated_at,
            review_days=args.review_days,
            approve_unknown_cost=bool(args.approve_unknown_cost),
            reasoning_effort=args.reasoning_effort,
            observe_provider_model=args.observe_provider_model,
            allow_network=args.allow_network,
        )
    except SmokeEvidenceError as exc:
        if args.summary_json:
            print(json.dumps({"status": "fail", "error": str(exc)}, ensure_ascii=False, separators=(",", ":")))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    summary = {
        "status": "pass",
        "evidence_id": evidence["evidence_id"],
        "manifest_version": evidence["manifest_version"],
        "adk_commit": evidence["adk_commit"],
        "runtime": evidence["runtime"],
        "runtime_version": evidence["runtime_version"],
        "requested_model": evidence["requested_model"],
        "evidence_sha256": evidence["evidence_sha256"],
        "output": str(Path(args.output)),
    }
    if args.summary_json:
        print(json.dumps(summary, ensure_ascii=False, separators=(",", ":")))
    else:
        print("[PASS] runtime smoke evidence collected")
        for key, value in summary.items():
            if key != "status":
                print(f"{key}={value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
