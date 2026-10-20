"""Bounded, read-only follow-up of six existing qualification trackers.

This report preserves canonical checker results; it creates no qualification,
human verdict, field observation, signature, runtime execution or release grant.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from tools.codex_assets.intake_io import _reject_symlink_chain, decode_json, read_bytes
from tools.control_plane.process_budget import ProcessBudgetError, run_bounded

SCHEMA = "llm-agent-qualification-followup/v1"
COMMAND_TIMEOUT = 45.0
MAX_STDOUT = 512 * 1024
MAX_STDERR = 16 * 1024
MAX_REPORT = 4 * 1024 * 1024
CHANGE_IDS = (
    "20261016-skill-catalog-competition",
    "20261016-effort-evidence-v1",
    "20261016-skill-description-discovery",
)
REVIEW_FILES = ("state.yaml", "checklist.md", "verify-report.md", "requirements.md",
                "design.md", "proposal.md", "tasks.md", "negative-results.md", "review-report.md")
KEY_INPUTS = (
    "adk.lock", "manifests/adk_interface.lock.json", "manifests/long_term_asset_qualification.json",
    "manifests/software_m5_policy.json", "manifests/software_m5_pilot_ledger.json",
    "manifests/product_maturity_scorecard.json", "reports/current-status.md",
    "reports/field-evidence/software-m5-v5-events.jsonl",
    "reports/long-term-assets/longitudinal-operation-current.json",
    "reports/runtime-evidence/effect-value/evidence-index.json",
    "reports/promotion/agent-dev-kit/promotion-evidence.json",
    "reports/promotion/agent-dev-kit/promotion-attestation.json",
    "agent-dev-kit/manifest.json", "agent-dev-kit/.adk/harness-readiness.json",
    "agent-dev-kit/manifests/harness_readiness_contracts.json",
    "agent-dev-kit/manifests/agent_value_contracts.json",
    "agent-dev-kit/manifests/agent_value_trust_registry.json",
    "agent-dev-kit/manifests/native_conformance_trust_registry.json",
    "tools/control_plane/qualification_followup.py", "tools/control_plane/process_budget.py",
    "tools/control_plane/effect_readiness.py", "tools/control_plane/longitudinal_operation.py",
    "tools/control_plane/native_target_readiness.py", "tools/codex_assets/software_m5_diagnostics.py",
)
NEXT_ACTIONS = {
    "root-236": ("If product deployment/release is in scope, use canonical current-candidate certification.",
                 "Collect current-candidate signed runtime and independent pilot evidence; use the existing M5 qualification and certifier.",
                 "Default diagnostics do not reverify the existing component signature."),
    "root-154": ("Review a source/model/task/intervention-bound preregistration before actual trials.",
                 "Collect genuine signed managed observations covering every current asset, then obtain real per-asset Owner decisions."),
    "root-67": ("Collect the registered pilot's actual end-window field observation and complete incident/regression/recovery/risk accounting.",
                "Obtain human review after all events are recorded, then promote canonical evidence through the existing certifier and protected PR."),
    "adk-153": ("Use an authenticated, version-pinned native runtime only after reviewed zero-incremental-cost execution conditions exist.",
                "Replay the genuine signed native receipt through the existing managed registry and production loader."),
    "adk-205": ("Have the registered human owner review each dimension using its existing evidence and actual review date.",
                "Rerun the existing Harness gate; elapsed dates and source checks do not supply human verification."),
}


@dataclass(frozen=True)
class Check:
    id: str
    title: str
    schema_key: str
    schema: str
    command: tuple[str, ...]


def _checks(root: Path) -> tuple[Check, ...]:
    python = sys.executable
    prefix = (python, "-m")
    tail = ("--root", str(root), "--summary-json")
    return (
        Check("root-236", "Conditional current-source Product M5", "schema", "llm-agent-current-m5-diagnostics/v1",
              prefix + ("tools.codex_assets.software_m5_diagnostics",) + tail),
        Check("root-154", "Governed effect/value evidence", "schema", "llm-agent-effect-readiness/v1",
              prefix + ("tools.control_plane.effect_readiness",) + tail + ("--require-evidence",)),
        Check("root-67", "Independent longitudinal operation", "schema", "llm-agent-longitudinal-operation-check/v1",
              prefix + ("tools.control_plane.longitudinal_operation",) + tail),
        Check("adk-153", "Native target conformance", "schema", "llm-agent-native-target-readiness/v1",
              prefix + ("tools.control_plane.native_target_readiness",) + tail + ("--require-native",)),
        Check("adk-205", "Human Harness freshness review", "schema_version", "adk-harness-readiness-report/v1",
              prefix + ("agent_dev_kit.cli", "harness", "readiness", "--root", str(root / "agent-dev-kit"),
                        "--contract", str(root / "agent-dev-kit/manifests/harness_readiness_contracts.json"),
                        "--gate", "--summary-json")),
    )


def _json(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def _digest(value: Any) -> str:
    return hashlib.sha256(_json(value)).hexdigest()


def _issue(identifier: str) -> str:
    repository = "llm_agent" if identifier.startswith("root-") else "agent-dev-kit"
    return "https://github.com/jiying2007/" + repository + "/issues/" + identifier.split("-")[1]


def _review_paths() -> list[str]:
    return ["agent-dev-kit/docs/changes/" + change + "/" + name
            for change in CHANGE_IDS for name in REVIEW_FILES]


def _file_identity(root: Path, relative: str) -> dict[str, Any]:
    path = root / relative
    _reject_symlink_chain(path)
    if not path.exists():
        return {"present": False}
    raw = read_bytes(path, label=relative, max_bytes=16 * 1024 * 1024)
    return {"present": True, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def _git_identity(root: Path) -> dict[str, str]:
    completed = run_bounded(
        ("git", "-C", str(root), "rev-parse", "--show-toplevel", "HEAD", "HEAD^{tree}"),
        timeout=5, max_stdout=4096, max_stderr=1024,
    )
    lines = completed.stdout.decode("utf-8", errors="strict").splitlines()
    if (completed.returncode or len(lines) != 3 or Path(lines[0]).resolve() != root
            or any(re.fullmatch("[0-9a-f]{40}", value) is None for value in lines[1:])):
        raise ValueError("source is not an exact Git worktree: " + root.name)
    return {"head": lines[1], "tree": lines[2]}


def _snapshot(root: Path) -> dict[str, Any]:
    sources: dict[str, Any] = {"root": _git_identity(root)}
    for name in ("agent-dev-kit", "codex"):
        path = root / name
        _reject_symlink_chain(path)
        sources[name] = _git_identity(path) if (path / ".git").exists() else {"materialized": False}
    inputs: dict[str, Any] = {}
    total = 0
    for relative in KEY_INPUTS + tuple(_review_paths()):
        inputs[relative] = _file_identity(root, relative)
        total += inputs[relative].get("bytes", 0)
        if total > 64 * 1024 * 1024:
            raise ValueError("key input total byte budget exceeded")
    return {"git": sources, "inputs": inputs,
            "scope": "key source/evidence inputs; canonical checkers validate nested evidence",
            "sha256": _digest({"git": sources, "inputs": inputs})}


def _texts(values: Any) -> list[str]:
    if not isinstance(values, list):
        return []
    return [value[:1024] for value in values[:32] if isinstance(value, str)]


def _classify(check: Check, data: Mapping[str, Any], code: int) -> tuple[bool, list[str]]:
    if data.get(check.schema_key) != check.schema:
        raise ValueError("unexpected checker schema")
    if code not in (0, 2):
        raise ValueError("checker returned an unexpected exit code")
    if check.id in ("root-154", "adk-153"):
        flag = "effect_evidence_ready" if check.id == "root-154" else "native_verified"
        if data.get("status") != "pass" or type(data.get(flag)) is not bool or type(data.get("software_ready")) is not bool:
            raise ValueError("invalid source/readiness result")
        ready = data["software_ready"] and data[flag]
        expected_terminal = "ready" if ready else "blocked-external-evidence" if data["software_ready"] else "blocked-software"
        if data.get("terminal_status") != expected_terminal:
            raise ValueError("inconsistent terminal readiness result")
        remaining = _texts(data.get("blockers"))
    elif check.id == "root-67":
        if data.get("status") not in ("pass", "blocked") or "simulated" in data:
            raise ValueError("invalid or simulated longitudinal result")
        ready = data["status"] == "pass"
        remaining = _texts([data.get("reason")])
    elif check.id == "root-236":
        if data.get("status") != "blocked" or data.get("read_only") is not True or not isinstance(data.get("stages"), dict):
            raise ValueError("invalid conditional M5 diagnostics")
        if data.get("model_invocations") != 0 or data.get("write_performed") is not False:
            raise ValueError("M5 diagnostics crossed the read-only boundary")
        if data.get("software_m5_certified") is not False or data.get("release_authorized") is not False:
            raise ValueError("M5 diagnostics cannot provide qualification authority")
        ready = False  # This existing diagnostics command never certifies a product.
        remaining = _texts(data.get("blocking_gates"))
    else:
        if data.get("mode") != "gate" or data.get("overall_status") not in ("pass", "partial", "needs-review", "blocked", "not-applicable"):
            raise ValueError("invalid Harness gate result")
        scan = data.get("scan")
        if not isinstance(scan, dict) or scan.get("errors") or scan.get("truncated") is not False:
            raise ValueError("Harness scan is incomplete")
        dimensions = data.get("dimensions")
        if not isinstance(dimensions, list) or not dimensions:
            raise ValueError("Harness dimensions are missing")
        ready = data["overall_status"] == "pass"
        remaining = _texts([str(d.get("dimension_id")) + ":" + str(b.get("code"))
                            for d in dimensions if isinstance(d, dict)
                            for b in d.get("blockers", []) if isinstance(b, dict)])
    if code != (0 if ready else 2):
        raise ValueError("checker exit code contradicts its qualification result")
    return bool(ready), remaining


def _collect_command(root: Path, check: Check, env: Mapping[str, str]) -> dict[str, Any]:
    item: dict[str, Any] = {
        "id": check.id, "title": check.title, "issue_url": _issue(check.id),
        "scan_status": "error", "status": "error", "qualification_ready": False,
        "command": list(check.command), "command_exit": None, "result": None,
        "remaining_evidence": [], "next_actions": list(NEXT_ACTIONS[check.id]),
    }
    if check.id == "root-236":
        item.update(scope="conditional-product-release", activation="not-assessed-by-diagnostics",
                    diagnostics_only=True, component_signature_reverified=False)
    phase = "command"
    try:
        completed = run_bounded(check.command, root, timeout=COMMAND_TIMEOUT,
                                max_stdout=MAX_STDOUT, max_stderr=MAX_STDERR, env=env)
        item["command_exit"] = completed.returncode
        item["stderr"] = {"bytes": len(completed.stderr), "sha256": hashlib.sha256(completed.stderr).hexdigest()}
        item["stdout"] = {"bytes": len(completed.stdout), "sha256": hashlib.sha256(completed.stdout).hexdigest()}
        phase = "json"
        data = decode_json(completed.stdout, "qualification checker output")
        if not isinstance(data, dict):
            raise ValueError("checker output must be one JSON object")
        phase = "schema"
        ready, remaining = _classify(check, data, completed.returncode)
        item["result"] = data
        item.update(scan_status="complete", status="ready" if ready else "blocked",
                    qualification_ready=ready, remaining_evidence=remaining)
        if ready:
            item["next_actions"] = []
    except (OSError, RuntimeError, ValueError, TypeError) as exc:
        item["error"] = "command-budget-exceeded" if isinstance(exc, ProcessBudgetError) else {
            "command": "command-could-not-complete", "json": "invalid-checker-json",
            "schema": "invalid-checker-schema-or-status",
        }[phase]
        item["remaining_evidence"] = ["checker-error; retain qualification boundary"]
    return item


def _review_inventory(root: Path) -> dict[str, Any]:
    item: dict[str, Any] = {
        "id": "adk-201", "title": "Human semantic review of three historical changes",
        "issue_url": _issue("adk-201"), "scan_status": "complete",
        "status": "human-review-required", "qualification_ready": False,
        "command": None, "command_exit": None,
        "remaining_evidence": ["authentic recorded human Spec/Quality/risk verdict"],
        "next_actions": ["Review the existing three change packages; record an actual human verdict under the existing workflow.",
                         "CI, a verified YAML stage, and this file inventory do not provide semantic human approval."],
        "result": {"schema": "llm-agent-human-review-inventory/v1", "changes": [],
                   "semantic_review_performed": False, "owner_verdict_verified": False},
    }
    for change in CHANGE_IDS:
        files: dict[str, Any] = {}
        for name in REVIEW_FILES:
            relative = "agent-dev-kit/docs/changes/" + change + "/" + name
            try:
                files[name] = _file_identity(root, relative)
            except (OSError, RuntimeError, ValueError):
                files[name] = {"error": "unsafe-or-unreadable-review-input"}
                item.update(scan_status="error", status="error")
        item["result"]["changes"].append({"change_id": change, "files": files})
    return item


def _not_run(identifier: str, title: str, command: tuple[str, ...] | None) -> dict[str, Any]:
    return {"id": identifier, "title": title, "issue_url": _issue(identifier),
            "scan_status": "error", "status": "error", "qualification_ready": False,
            "execution_status": "not-run", "command": list(command) if command else None,
            "command_exit": None, "result": None, "error": "verified-root-source-required",
            "remaining_evidence": ["verified regular Git source and safe key inputs"],
            "next_actions": ["Restore the verified source, then rerun the read-only collection."]}


def collect(root: Path) -> dict[str, Any]:
    root = root.absolute()
    report: dict[str, Any] = {
        "schema": SCHEMA, "generated_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "scan_status": "complete", "qualification_all_ready": False, "report_only": True,
        "release_authorized": False, "may_fill_owner": False, "provider_execution_performed": False,
        "source_before": None, "source_after": None, "input_digest": None,
        "source_consistent": False, "errors": [], "items": [],
    }
    try:
        _reject_symlink_chain(root)
        root = root.resolve()
        report["source_before"] = _snapshot(root)
        report["input_digest"] = report["source_before"]["sha256"]
    except (OSError, RuntimeError, ValueError):
        report["errors"].append("source-before-invalid")
        report["scan_status"] = "error"
        report["items"] = [_not_run(check.id, check.title, check.command) for check in _checks(root)]
        report["items"].append(_not_run("adk-201", "Human semantic review of three historical changes", None))
        return report
    env = dict(os.environ)
    env.update(PYTHONPATH=os.pathsep.join((str(root), str(root / "agent-dev-kit/src"))),
               PYTHONDONTWRITEBYTECODE="1", TZ="UTC")
    for check in _checks(root):
        report["items"].append(_collect_command(root, check, env))
    report["items"].append(_review_inventory(root))
    try:
        report["source_after"] = _snapshot(root)
        report["source_consistent"] = report["source_before"] == report["source_after"]
        if not report["source_consistent"]:
            report["errors"].append("source-inputs-changed-during-scan")
    except (OSError, RuntimeError, ValueError):
        report["errors"].append("source-after-invalid")
    if not report["source_consistent"]:
        for item in report["items"]:
            item.update(scan_status="error", status="error", qualification_ready=False,
                        error="source-inputs-not-stable")
    if report["errors"] or any(item["scan_status"] == "error" for item in report["items"]):
        report["scan_status"] = "error"
    report["qualification_all_ready"] = report["scan_status"] == "complete" and all(
        item["qualification_ready"] for item in report["items"])
    if len(_json(report)) > MAX_REPORT:
        report.update(scan_status="error", qualification_all_ready=False)
        report["errors"].append("aggregate-report-byte-budget-exceeded")
        for item in report["items"]:
            item.update(result=None, scan_status="error", status="error", qualification_ready=False)
    return report


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    report = collect(Path(args.root))
    print(_json(report).decode("utf-8"))
    return 0 if report["scan_status"] == "complete" else 1


if __name__ == "__main__":
    raise SystemExit(main())
