"""Bounded, read-only follow-up of six existing qualification trackers.

This report consumes canonical checkers and delegated review evidence. It
creates no review, field observation, signature, runtime execution or release grant.
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

SCHEMA = "llm-agent-qualification-followup/v2"
COMMAND_TIMEOUT = 45.0
MAX_STDOUT = 512 * 1024
MAX_STDERR = 16 * 1024
MAX_REPORT = 4 * 1024 * 1024
CHANGE_IDS = (
    "20261016-skill-catalog-competition",
    "20261016-effort-evidence-v1",
    "20261016-skill-description-discovery",
)
CHANGE_HEADS = dict(zip(CHANGE_IDS, (
    "d0c7a9baac8a1942be79a027b1d6feff81079b39",
    "61ff6079dc1d994ac33fbd07a0f069d80b39341d",
    "6fa8b40977e83569a775297371759b126406adcd",
), strict=True))
CHANGE_BASES = dict(zip(CHANGE_IDS, (
    "2fe242e9e309e4111c8639e511e53f6a585a1ed7",
    CHANGE_HEADS[CHANGE_IDS[0]],
    CHANGE_HEADS[CHANGE_IDS[1]],
), strict=True))
CHANGE_PATCHES = dict(zip(CHANGE_IDS, (
    "ce839fd501c606d94c57c685a38d25b907f076416f6f75f0368ea5dec1d8081d",
    "51c0f3da381bb1559a5039ed8dffa87cac475ab30f9309227aacc76f8591a855",
    "8f2cf5749b057db7b490403b190d6b20c765d2597b4cc17a717d0e17ce293c69",
), strict=True))
REVIEW_FILES = ("state.yaml", "checklist.md", "verify-report.md", "requirements.md",
                "design.md", "proposal.md", "tasks.md", "negative-results.md", "review-report.md",
                "review-evidence.json", "provenance.md")
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
    "agent-dev-kit/.adk/review-policy.json",
    "agent-dev-kit/src/agent_dev_kit/review_evidence.py",
    "agent-dev-kit/src/agent_dev_kit/strict_json.py",
    "agent-dev-kit/src/agent_dev_kit/readiness_evidence.py",
    "tools/control_plane/qualification_followup.py", "tools/control_plane/process_budget.py",
    "tools/control_plane/effect_readiness.py", "tools/control_plane/longitudinal_operation.py",
    "tools/control_plane/adk_interface.py",
    "tools/control_plane/native_target_readiness.py", "tools/codex_assets/software_m5_diagnostics.py",
)
NEXT_ACTIONS = {
    "root-236": ("If product deployment/release is in scope, use canonical current-candidate certification.",
                 "Collect current-candidate signed runtime and independent pilot evidence; use the existing M5 qualification and certifier.",
                 "Default diagnostics do not reverify the existing component signature."),
    "root-154": ("Review a source/model/task/intervention-bound preregistration before actual trials.",
                 "Collect genuine signed managed observations covering every current asset, then validate delegated per-asset review evidence."),
    "root-67": ("Collect the registered pilot's actual end-window field observation and complete incident/regression/recovery/risk accounting.",
                "Complete delegated review after all events are recorded, then promote canonical evidence through the existing certifier and protected PR."),
    "adk-153": ("Use an authenticated, version-pinned native runtime only after reviewed zero-incremental-cost execution conditions exist.",
                "Replay the genuine signed native receipt through the existing managed registry and production loader."),
    "adk-205": ("Complete a source-bound delegated review of every Harness dimension under the pinned ADK policy.",
                "Rerun the existing Harness gate; a date change alone is not a verified review."),
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
        Check("adk-205", "Delegated Harness freshness review", "schema_version", "adk-harness-readiness-report/v1",
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


def _change_location(root: Path, change: str) -> Path | None:
    """Resolve one canonical active/archive package; ambiguous copies fail closed."""
    base = root / "agent-dev-kit/docs/changes"
    active = base / change
    archive = base / "archive"
    for path in (active, archive):
        _reject_symlink_chain(path)
    matches = [active] if active.exists() else []
    if archive.exists():
        if not archive.is_dir():
            raise ValueError("change archive is not a directory")
        with os.scandir(archive) as entries:
            for count, entry in enumerate(entries, 1):
                if count > 4096:
                    raise ValueError("change archive entry budget exceeded")
                if re.fullmatch(r"[0-9]{8}-" + re.escape(change), entry.name):
                    matches.append(Path(entry.path))
    if len(matches) > 1:
        raise ValueError("change has multiple active/archive locations")
    if not matches:
        return None
    _reject_symlink_chain(matches[0])
    if not matches[0].is_dir():
        raise ValueError("change package is not a directory")
    return matches[0]


def _review_paths(root: Path) -> list[str]:
    paths: list[str] = []
    for change in CHANGE_IDS:
        location = _change_location(root, change) or root / "agent-dev-kit/docs/changes" / change
        paths.extend((location / name).relative_to(root).as_posix() for name in REVIEW_FILES)
    return paths


def _file_identity(root: Path, relative: str) -> dict[str, Any]:
    path = root / relative
    _reject_symlink_chain(path)
    if not path.exists():
        return {"present": False}
    raw = read_bytes(path, label=relative, max_bytes=16 * 1024 * 1024)
    return {"present": True, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def _review_input_paths(root: Path, review_paths: Sequence[str]) -> set[str]:
    """Snapshot declared review inputs as well as the record that names them."""
    adk = root / "agent-dev-kit"
    result: set[str] = set()

    def relative_path(base: Path, value: Any) -> Path:
        if (not isinstance(value, str) or not value or len(value) > 4096
                or "\\" in value or any(char in value for char in "\x00\r\n")
                or Path(value).is_absolute() or any(part in ("", ".", "..") for part in value.split("/"))):
            raise ValueError("invalid review input path")
        path = base / value
        _reject_symlink_chain(path)
        result.add(path.relative_to(root).as_posix())
        return path

    def document(path: Path, *, max_bytes: int = 1024 * 1024) -> dict[str, Any] | None:
        _reject_symlink_chain(path)
        if not path.exists():
            return None
        value = decode_json(read_bytes(path, label="review snapshot input", max_bytes=max_bytes),
                            "review snapshot input")
        if not isinstance(value, dict):
            raise ValueError("review snapshot input must be an object")
        return value

    policy = document(adk / ".adk/review-policy.json")
    if policy is not None:
        authorization = policy.get("authorization")
        if not isinstance(authorization, dict):
            raise ValueError("review policy authorization is missing")
        relative_path(adk, authorization.get("path"))
    receipts = {root / name: adk for name in review_paths if name.endswith("/review-evidence.json")}

    def retain_receipt(path: Path, repository: Path) -> None:
        if path in receipts and receipts[path] != repository:
            raise ValueError("review input has ambiguous repository authority")
        receipts[path] = repository
    metadata = document(adk / ".adk/harness-readiness.json")
    if metadata is not None:
        dimensions = metadata.get("dimensions", {})
        if not isinstance(dimensions, dict) or len(dimensions) > 16:
            raise ValueError("invalid Harness review dimensions")
        for dimension in dimensions.values():
            if isinstance(dimension, dict) and "review_evidence" in dimension:
                ref = dimension["review_evidence"]
                if not isinstance(ref, dict):
                    raise ValueError("invalid Harness review reference")
                retain_receipt(relative_path(adk, ref.get("path")), adk)
    index = document(root / "reports/runtime-evidence/effect-value/evidence-index.json", max_bytes=16 * 1024 * 1024)
    if index is not None:
        entries = index.get("entries", [])
        if not isinstance(entries, list) or len(entries) > 100:
            raise ValueError("invalid effect review inventory")
        for entry in entries:
            if not isinstance(entry, dict):
                raise ValueError("invalid effect review entry")
            if "review_evidence_path" in entry:
                retain_receipt(relative_path(root, entry["review_evidence_path"]), root)
    summary = document(root / "reports/long-term-assets/longitudinal-operation-current.json")
    if summary is not None:
        review = summary.get("review", {})
        if not isinstance(review, dict):
            raise ValueError("invalid longitudinal review inventory")
        if review.get("mode") == "owner-delegated-ai":
            retain_receipt(relative_path(root, review.get("evidence_path")), root)
    for receipt, repository in sorted(receipts.items()):
        value = document(receipt)
        if value is None:
            continue
        for key in ("sources", "evidence"):
            refs = value.get(key, [])
            if not isinstance(refs, list) or len(refs) > 512:
                raise ValueError("review input reference budget exceeded")
            for ref in refs:
                if not isinstance(ref, dict) or ref.get("base") not in ("repository", "record"):
                    raise ValueError("invalid review input reference")
                relative_path(repository if ref["base"] == "repository" else receipt.parent, ref.get("path"))
    return result


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
    review_paths = _review_paths(root)
    paths = set(KEY_INPUTS) | set(review_paths) | _review_input_paths(root, review_paths)
    for relative in sorted(paths):
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
        "required_in_current_scope": check.id != "root-236",
        "command": list(check.command), "command_exit": None, "result": None,
        "remaining_evidence": [], "next_actions": list(NEXT_ACTIONS[check.id]),
    }
    if check.id == "root-236":
        item.update(scope="conditional-product-release", activation="not-assessed-by-diagnostics",
                    assessment="not-assessed", diagnostics_only=True, component_signature_reverified=False)
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
        if check.id == "root-236":
            item["status"] = "conditional"
        if ready:
            item["next_actions"] = []
    except (OSError, RuntimeError, ValueError, TypeError) as exc:
        item["error"] = "command-budget-exceeded" if isinstance(exc, ProcessBudgetError) else {
            "command": "command-could-not-complete", "json": "invalid-checker-json",
            "schema": "invalid-checker-schema-or-status",
        }[phase]
        item["remaining_evidence"] = ["checker-error; retain qualification boundary"]
    return item


def _archive_provenance(location: Path, change: str, review: dict[str, Any]) -> None:
    """Check the existing lifecycle receipt against the validated review."""
    content = read_bytes(location / "provenance.md", label="change archive provenance", max_bytes=16384).decode("utf-8")
    fields: dict[str, str] = {}
    for line in content.splitlines():
        if not line.strip().startswith("- "):
            continue
        match = re.fullmatch(r"\s*- ([a-z][a-z0-9_]*):\s*(.*?)\s*", line)
        if match is None or match[1] in fields or len(fields) >= 32:
            raise ValueError("archive provenance fields are invalid or duplicated")
        fields[match[1]] = match[2]
    expected = {
        "schema": "adk-change-provenance/v1", "authority": "ADK Canonical Change Contract", "change_id": change,
        "source_stage": "review-passed", "final_stage": "archived", "review_verdict": "pass",
        "reviewer_id": review["reviewer"]["id"], "review_record_sha256": review["record_sha256"],
    }
    if any(fields.get(key) != value for key, value in expected.items()):
        raise ValueError("archive provenance differs from the canonical review lifecycle")
    actor = fields.get("archived_by", "")
    archived_at = fields.get("archived_at", "")
    if not actor or len(actor) > 128 or not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z", archived_at):
        raise ValueError("archive provenance lacks its actual actor or timestamp")
    archived = datetime.fromisoformat(archived_at.replace("Z", "+00:00"))
    reviewed = datetime.fromisoformat(review["reviewed_at"].replace("Z", "+00:00"))
    if not reviewed <= archived <= datetime.now(UTC):
        raise ValueError("archive provenance chronology is invalid")


def _review_inventory(root: Path) -> dict[str, Any]:
    item: dict[str, Any] = {
        "id": "adk-201", "title": "Delegated semantic review of three historical changes",
        "issue_url": _issue("adk-201"), "scan_status": "complete",
        "status": "review-evidence-required", "qualification_ready": False,
        "required_in_current_scope": True,
        "command": None, "command_exit": None,
        "remaining_evidence": [],
        "next_actions": ["Complete independent delegated Spec/Quality review of each frozen change and its canonical review/archive lifecycle."],
        "result": {"schema": "llm-agent-delegated-review-inventory/v1", "changes": [],
                   "semantic_review_performed": False, "delegated_review_verified": False},
    }
    for change in CHANGE_IDS:
        record: dict[str, Any] = {"change_id": change, "review_verified": False}
        files: dict[str, Any] = {}
        try:
            location = _change_location(root, change)
            if location is None:
                record.update(location=None, reason="change-package-missing", files={})
                item["result"]["changes"].append(record)
                item["remaining_evidence"].append(change + ":change-package-missing")
                continue
            record["location"] = location.relative_to(root).as_posix()
            for name in REVIEW_FILES:
                relative = (location / name).relative_to(root).as_posix()
                files[name] = _file_identity(root, relative)
            record["files"] = files
            if not files["review-evidence.json"]["present"]:
                record["reason"] = "delegated-review-evidence-missing"
            else:
                from .adk_interface import validate_delegated_review

                review = validate_delegated_review(root / "agent-dev-kit", location / "review-evidence.json",
                                                   policy_root=root / "agent-dev-kit",
                                                   expected_subject=change, expected_scope="source-change")
                if review["record_sha256"] != files["review-evidence.json"]["sha256"]:
                    raise ValueError("review record changed during inventory")
                if review["target"] != {"base_commit": CHANGE_BASES[change], "head_commit": CHANGE_HEADS[change],
                                        "original_patch_sha256": CHANGE_PATCHES[change]}:
                    raise ValueError("historical review target differs from frozen change")
                stages = re.findall(r"^stage:\s*([a-z-]+)\s*$", read_bytes(
                    location / "state.yaml", label="change lifecycle state", max_bytes=16384,
                ).decode("utf-8"), re.MULTILINE)
                expected_stage = "archived" if location.parent.name == "archive" else "review-passed"
                if stages != [expected_stage]:
                    record["reason"] = "canonical-review-lifecycle-incomplete"
                else:
                    if expected_stage == "archived":
                        _archive_provenance(location, change, review)
                    record.update(review_verified=True, review_sha256=review["record_sha256"],
                                  reviewer=review["reviewer"], reviewed_at=review["reviewed_at"],
                                  target=review["target"], verdicts=review["verdicts"], stage=stages[0],
                                  archive_provenance_verified=expected_stage == "archived")
        except (OSError, RuntimeError, ValueError, KeyError, ImportError):
            record.update(files=files, reason="invalid-or-unavailable-delegated-review")
            item.update(scan_status="error", status="error")
        item["result"]["changes"].append(record)
        if not record["review_verified"]:
            item["remaining_evidence"].append(change + ":" + record["reason"])
    ready = item["scan_status"] == "complete" and all(
        record["review_verified"] for record in item["result"]["changes"])
    item["result"]["delegated_review_verified"] = ready
    if ready:
        item.update(status="ready", qualification_ready=True, next_actions=[])
    return item


def _not_run(identifier: str, title: str, command: tuple[str, ...] | None) -> dict[str, Any]:
    return {"id": identifier, "title": title, "issue_url": _issue(identifier),
            "scan_status": "error", "status": "error", "qualification_ready": False,
            "required_in_current_scope": identifier != "root-236",
            "execution_status": "not-run", "command": list(command) if command else None,
            "command_exit": None, "result": None, "error": "verified-root-source-required",
            "remaining_evidence": ["verified regular Git source and safe key inputs"],
            "next_actions": ["Restore the verified source, then rerun the read-only collection."]}


def collect(root: Path) -> dict[str, Any]:
    root = root.absolute()
    report: dict[str, Any] = {
        "schema": SCHEMA, "generated_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "scan_status": "complete", "qualification_all_ready": False, "report_only": True,
        "scope": "research-control-workspace", "required_qualification_ready": False,
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
        report["items"].append(_not_run("adk-201", "Delegated semantic review of three historical changes", None))
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
    report["required_qualification_ready"] = report["scan_status"] == "complete" and all(
        item["qualification_ready"] for item in report["items"] if item["required_in_current_scope"])
    if len(_json(report)) > MAX_REPORT:
        report.update(scan_status="error", qualification_all_ready=False, required_qualification_ready=False)
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
