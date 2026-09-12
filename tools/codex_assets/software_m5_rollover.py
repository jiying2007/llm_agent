#!/usr/bin/env python3
"""Finalize current-ADK Software M5 qualification from measured runtime evidence.

The command never invokes a model. It accepts a previously collected measured
runtime-smoke evidence file, binds it to the current adk.lock and signed ADK
promotion, updates the M5 policy/qualification/scorecard/current-status as one
transaction, and rolls everything back unless both the existing Software M5
certifier and the current-source status projection pass with fresh authorization.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

from tools.codex_assets.software_m5_v3 import check as software_m5_check
from tools.control_plane.status_projection import (
    _projection_digest,
    _projection_inputs,
    project as status_project,
    refresh_current_status,
)

EVIDENCE_SCHEMA = "llm-agent-runtime-smoke-evidence/v1"
QUALIFICATION_SCHEMA = "llm-agent-m5-qualification-record/v1"


class RolloverError(RuntimeError):
    pass


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RolloverError(f"invalid {label}: {path}") from exc
    if not isinstance(value, dict):
        raise RolloverError(f"{label} must be a JSON object")
    return value


def _write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _read_lock(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
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
        raise RolloverError("adk.lock missing fields: " + ", ".join(missing))
    return values


def _git(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=30,
    )
    if completed.returncode != 0:
        raise RolloverError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout.strip()


def _parse_time(value: Any, label: str) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise RolloverError(f"{label} must be an ISO-8601 UTC timestamp ending in Z")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise RolloverError(f"{label} is invalid") from exc
    return parsed.astimezone(timezone.utc)


def _validate_runtime(path: Path, lock: Mapping[str, str]) -> dict[str, Any]:
    evidence = _load_json(path, "measured runtime evidence")
    if evidence.get("schema") != EVIDENCE_SCHEMA:
        raise RolloverError("measured runtime evidence schema is invalid")
    expected = {
        "manifest_version": lock["agent-dev-kit.version"],
        "adk_commit": lock["agent-dev-kit.commit"],
        "adk_tree": lock["agent-dev-kit.tree"],
        "manifest_blob": lock["agent-dev-kit.manifest_blob"],
    }
    for field, value in expected.items():
        if evidence.get(field) != value:
            raise RolloverError(f"measured runtime evidence {field} does not match current adk.lock")
    if evidence.get("runtime") != "codex" or evidence.get("requested_model") != "gpt-5.5":
        raise RolloverError("measured runtime evidence must be codex/gpt-5.5")
    generated = _parse_time(evidence.get("generated_at"), "measured runtime generated_at")
    if generated > datetime.now(timezone.utc):
        raise RolloverError("measured runtime evidence is future-dated")
    result = evidence.get("result")
    if not isinstance(result, dict) or result.get("status") != "pass":
        raise RolloverError("measured runtime result is not passing")
    if result.get("runtime") != "codex" or result.get("condition") != "adk":
        raise RolloverError("nested runtime result must describe codex/adk")
    if result.get("requested_model") != evidence.get("requested_model"):
        raise RolloverError("nested runtime result model does not match evidence")
    gates = result.get("quality_gate")
    if not isinstance(gates, dict) or not gates or not all(value is True for value in gates.values()):
        raise RolloverError("measured runtime quality gates are not all passing")
    stored = evidence.get("evidence_sha256")
    unsigned = dict(evidence)
    unsigned.pop("evidence_sha256", None)
    if stored != _digest(unsigned):
        raise RolloverError("measured runtime evidence_sha256 does not match content")
    return evidence


def _validate_promotion(root: Path, lock: Mapping[str, str]) -> dict[str, Any]:
    evidence = _load_json(root / "reports/promotion/agent-dev-kit/promotion-evidence.json", "promotion evidence")
    source = evidence.get("source")
    release = evidence.get("release")
    if evidence.get("schema") != "adk-promotion-evidence/v1" or not isinstance(source, dict) or not isinstance(release, dict):
        raise RolloverError("promotion evidence schema/source/release is invalid")
    expected = {
        "version": lock["agent-dev-kit.version"],
        "commit": lock["agent-dev-kit.commit"],
        "tree": lock["agent-dev-kit.tree"],
        "manifest_blob": lock["agent-dev-kit.manifest_blob"],
    }
    for field, value in expected.items():
        if source.get(field) != value:
            raise RolloverError(f"promotion evidence source.{field} does not match adk.lock")
    if source.get("repository") != "jiying2007/agent-dev-kit" or source.get("ref") != "refs/heads/main" or source.get("event") != "push":
        raise RolloverError("promotion evidence is not bound to agent-dev-kit main push")
    run_id = source.get("run_id")
    if isinstance(run_id, bool) or not isinstance(run_id, int) or run_id <= 0:
        raise RolloverError("promotion evidence run_id is invalid")
    if release.get("release_eligible") is not True or not isinstance(release.get("artifact_sha256"), str):
        raise RolloverError("promotion evidence is not release eligible")
    return evidence


def _replace_refs(value: Any, old_runtime: str, new_runtime: str, old_record: str, new_record: str) -> Any:
    if isinstance(value, str):
        return new_runtime if value == old_runtime else new_record if value == old_record else value
    if isinstance(value, list):
        return [_replace_refs(item, old_runtime, new_runtime, old_record, new_record) for item in value]
    if isinstance(value, dict):
        return {key: _replace_refs(item, old_runtime, new_runtime, old_record, new_record) for key, item in value.items()}
    return value


def _update_policy(
    policy: Mapping[str, Any],
    lock: Mapping[str, str],
    promotion: Mapping[str, Any],
    runtime_rel: str,
    qualification_rel: str,
    today: str,
) -> dict[str, Any]:
    updated = copy.deepcopy(policy)
    release = updated.get("release")
    runtime = updated.get("runtime_qualification")
    if not isinstance(release, dict) or not isinstance(runtime, dict):
        raise RolloverError("Software M5 policy release/runtime sections are missing")
    release.update({
        "candidate_version": lock["agent-dev-kit.version"],
        "candidate_commit": lock["agent-dev-kit.commit"],
        "candidate_tree": lock["agent-dev-kit.tree"],
        "candidate_manifest_blob": lock["agent-dev-kit.manifest_blob"],
        "candidate_artifact_sha256": promotion["release"]["artifact_sha256"],
        "candidate_artifact_status": "available",
        "candidate_release_eligible": True,
    })
    runtime["measured_evidence"] = [runtime_rel]
    updated["qualification_record"] = qualification_rel
    if "updated_at" in updated:
        updated["updated_at"] = today
    return updated


def _build_record(
    root: Path,
    previous: Mapping[str, Any],
    lock: Mapping[str, str],
    promotion: Mapping[str, Any],
    runtime_rel: str,
    recorded_at: str,
    source_baseline: str,
    root_integration_run_id: int,
    compatibility: Sequence[str],
) -> dict[str, Any]:
    required_runs: list[dict[str, Any]] = [
        {
            "repository": "jiying2007/agent-dev-kit",
            "run_id": promotion["source"]["run_id"],
            "scope": "signed-promotion-main",
            "conclusion": "success",
        },
        {
            "repository": "jiying2007/llm_agent",
            "run_id": root_integration_run_id,
            "scope": "current-adk-source-integration-fresh-main",
            "conclusion": "success",
        },
    ]
    for item in previous.get("required_runs", []):
        if not isinstance(item, dict):
            continue
        if item.get("scope") in {"independent-repository-onboarding", "independent-pilot-start"} and item.get("conclusion") == "success":
            required_runs.append(copy.deepcopy(item))
    record: dict[str, Any] = {
        "schema": QUALIFICATION_SCHEMA,
        "recorded_at": recorded_at,
        "basis": "current signed ADK promotion + current measured Codex smoke + existing governed independent pilot baseline",
        "source_baseline": source_baseline,
        "adk": {
            "version": lock["agent-dev-kit.version"],
            "commit": lock["agent-dev-kit.commit"],
            "tree": lock["agent-dev-kit.tree"],
            "manifest_blob": lock["agent-dev-kit.manifest_blob"],
            "promotion_run_id": promotion["source"]["run_id"],
            "promotion_evidence_sha256": _sha256_file(root / "reports/promotion/agent-dev-kit/promotion-evidence.json"),
            "promotion_attestation_sha256": _sha256_file(root / "reports/promotion/agent-dev-kit/promotion-attestation.json"),
        },
        "required_runs": required_runs,
        "field_baseline": copy.deepcopy(previous.get("field_baseline", {})),
        "runtime_baseline": {
            "measured_evidence": [runtime_rel],
            "compatibility_evidence": list(compatibility),
        },
        "historical_continuity": copy.deepcopy(previous.get("historical_continuity", {})),
        "operational_followups_non_blocking": True,
    }
    record["record_sha256"] = _digest(record)
    return record


def _update_scorecard(
    scorecard: Mapping[str, Any],
    version: str,
    old_runtime: str,
    runtime_rel: str,
    old_record: str,
    qualification_rel: str,
    today: str,
) -> dict[str, Any]:
    updated = _replace_refs(copy.deepcopy(scorecard), old_runtime, runtime_rel, old_record, qualification_rel)
    updated["updated_at"] = today
    software = updated.get("software_m5")
    working = updated.get("working_candidate")
    if not isinstance(software, dict) or not isinstance(working, dict):
        raise RolloverError("product maturity scorecard current-candidate sections are missing")
    software.update({
        "readiness_status": "m5-ready",
        "eligibility_status": "release-qualified",
        "certification_status": "pass",
        "certified": True,
        "candidate_version": version,
        "blocking_gates": [],
    })
    if isinstance(software.get("advisory_followups"), list):
        software["advisory_followups"] = [item for item in software["advisory_followups"] if item != "5_1_0_release_train"]
    working.update({
        "version": version,
        "status": "production-qualified",
        "overall_level": "M5",
        "target_status": "certified",
        "lock_state": "synchronized",
    })
    return updated


def _replace_status_field(text: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^- {re.escape(key)}:\s*.*$", re.MULTILINE)
    if not pattern.search(text):
        raise RolloverError(f"current-status baseline field is missing: {key}")
    return pattern.sub(f"- {key}: {value}", text, count=1)


def _update_status(
    root: Path,
    source_baseline: str,
    digest: str,
    lock: Mapping[str, str],
    promotion_run_id: int,
    root_integration_run_id: int,
    runtime_rel: str,
    qualification_rel: str,
    today: str,
) -> None:
    path = root / "reports/current-status.md"
    text = path.read_text(encoding="utf-8")
    fields = {
        "last_verified_at": today,
        "root_product_commit": source_baseline,
        "verified_projection_inputs_sha256": digest,
        "agent_dev_kit_commit": lock["agent-dev-kit.commit"],
        "agent_dev_kit_release_commit": lock["agent-dev-kit.commit"],
        "adk_version": lock["agent-dev-kit.version"],
        "product_maturity": "M5",
        "software_m5_readiness": "m5-ready",
        "software_m5_certified": "true",
        "terminal_mature": "true",
        "field_status": "production_qualified",
        "baseline_release_authorized": "true",
    }
    for key, value in fields.items():
        text = _replace_status_field(text, key, value)
    paragraph = (
        "当前产品按 `llm-agent-software-m5-policy/v3` 定义为 **Production-qualified M5**。"
        f"该结论绑定当前 ADK `{lock['agent-dev-kit.commit'][:12]}...` 的 release-eligible promotion evidence、"
        "keyless Sigstore 供应链证据、当前 measured Codex runtime smoke，以及 `digital-worker` 独立真实软件仓的 "
        "hash-bound field pilot start。M5 由机器认证器计算，不由本页文字声明决定。"
    )
    text = re.sub(
        r"当前产品按 `llm-agent-software-m5-policy/v3` 定义为 \*\*Production-qualified M5\*\*。.*?M5 由机器认证器计算，不由本页文字声明决定。",
        paragraph,
        text,
        count=1,
        flags=re.DOTALL,
    )
    bullets = {
        r"^- ADK final zero-debt main：.*$": f"- ADK current release main：`{lock['agent-dev-kit.commit']}`。",
        r"^- ADK promotion main CI：.*$": f"- ADK promotion main CI：`{promotion_run_id}`，signed promotion evidence/attestation 已绑定当前 identity。",
        r"^- Root final ADK integration：.*$": f"- Root current ADK integration fresh-main：`{root_integration_run_id}`。",
        r"^- Measured runtime：.*$": f"- Measured runtime：`{runtime_rel}`，result PASS，全部 quality gates=true。",
        r"^- Qualification record：.*$": f"- Qualification record：`{qualification_rel}`。",
    }
    for pattern, replacement in bullets.items():
        text = re.sub(pattern, replacement, text, count=1, flags=re.MULTILINE)
    text = text.replace("，以及 5.1.0 release train", "")
    path.write_text(text, encoding="utf-8")


def _snapshot(paths: Sequence[Path]) -> dict[Path, bytes | None]:
    return {path: path.read_bytes() if path.exists() else None for path in paths}


def _restore(snapshot: Mapping[Path, bytes | None]) -> None:
    for path, payload in snapshot.items():
        if payload is None:
            path.unlink(missing_ok=True)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(payload)


def finalize(root: Path, runtime_source: Path, root_integration_run_id: int, qualification_time: str | None = None) -> dict[str, Any]:
    root = root.resolve()
    runtime_source = runtime_source.resolve()
    if root_integration_run_id <= 0:
        raise RolloverError("--root-integration-run-id must be positive")
    source_baseline = _git(root, "rev-parse", "HEAD")
    lock = _read_lock(root / "adk.lock")
    promotion = _validate_promotion(root, lock)
    runtime = _validate_runtime(runtime_source, lock)
    generated = _parse_time(runtime["generated_at"], "measured runtime generated_at")
    today = generated.date().isoformat()
    recorded_at = qualification_time or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    _parse_time(recorded_at, "qualification time")

    version = lock["agent-dev-kit.version"]
    safe_version = re.sub(r"[^0-9A-Za-z._-]+", "-", version)
    runtime_rel = f"reports/runtime-evidence/codex-{safe_version}-runtime-smoke-{today}.json"
    qualification_rel = f"reports/runtime-evidence/software-m5-production-qualification-{safe_version}-{today}.json"

    policy_path = root / "manifests/software_m5_policy.json"
    scorecard_path = root / "manifests/product_maturity_scorecard.json"
    status_path = root / "reports/current-status.md"
    runtime_path = root / runtime_rel
    qualification_path = root / qualification_rel
    old_policy = _load_json(policy_path, "Software M5 policy")
    old_scorecard = _load_json(scorecard_path, "product maturity scorecard")
    old_record_rel = str(old_policy.get("qualification_record", ""))
    old_runtime_list = old_policy.get("runtime_qualification", {}).get("measured_evidence", [])
    compatibility = old_policy.get("runtime_qualification", {}).get("compatibility_evidence", [])
    if not isinstance(old_runtime_list, list) or len(old_runtime_list) != 1 or not isinstance(old_runtime_list[0], str):
        raise RolloverError("current policy must contain exactly one prior measured runtime evidence path")
    if not isinstance(compatibility, list) or not all(isinstance(item, str) for item in compatibility):
        raise RolloverError("runtime compatibility evidence list is invalid")
    old_runtime_rel = old_runtime_list[0]
    previous_record = _load_json(root / old_record_rel, "previous M5 qualification record")
    if runtime_path.exists() or qualification_path.exists():
        raise RolloverError("versioned rollover output already exists; refuse to overwrite historical evidence")

    touched = [policy_path, scorecard_path, status_path, runtime_path, qualification_path]
    snapshot = _snapshot(touched)
    try:
        runtime_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(runtime_source, runtime_path)
        record = _build_record(
            root,
            previous_record,
            lock,
            promotion,
            runtime_rel,
            recorded_at,
            source_baseline,
            root_integration_run_id,
            compatibility,
        )
        _write_json(qualification_path, record)
        _write_json(policy_path, _update_policy(old_policy, lock, promotion, runtime_rel, qualification_rel, today))
        _write_json(
            scorecard_path,
            _update_scorecard(old_scorecard, version, old_runtime_rel, runtime_rel, old_record_rel, qualification_rel, today),
        )

        refresh_current_status(root)
        projection_digest = _projection_digest(_projection_inputs(root))
        _update_status(
            root,
            source_baseline,
            projection_digest,
            lock,
            int(promotion["source"]["run_id"]),
            root_integration_run_id,
            runtime_rel,
            qualification_rel,
            today,
        )
        refresh_current_status(root)

        certification = software_m5_check(root)
        if certification.get("integrity_status") != "pass" or certification.get("declaration_status") != "pass" or certification.get("software_m5_certified") is not True:
            raise RolloverError("Software M5 certifier rejected rollover: " + json.dumps(certification, ensure_ascii=False, sort_keys=True))
        projection = status_project(root, generated.date())
        baseline = projection.get("last_verified_baseline", {})
        if projection.get("status") != "pass" or projection.get("release_authorized") is not True:
            raise RolloverError("status projection did not authorize the current release")
        if baseline.get("source_inputs_match") is not True or baseline.get("fresh_for_current_source") is not True:
            raise RolloverError("current release authorization lacks a fresh verified projection baseline")

        return {
            "schema": "llm-agent-software-m5-rollover/v1",
            "status": "pass",
            "source_baseline": source_baseline,
            "candidate_version": version,
            "candidate_commit": lock["agent-dev-kit.commit"],
            "runtime_evidence": runtime_rel,
            "qualification_record": qualification_rel,
            "root_integration_run_id": root_integration_run_id,
            "projection_inputs_sha256": projection["current_projection"]["inputs_sha256"],
            "release_authorized": True,
            "software_m5_certified": True,
            "changed_paths": [
                runtime_rel,
                qualification_rel,
                "manifests/software_m5_policy.json",
                "manifests/product_maturity_scorecard.json",
                "reports/current-status.md",
            ],
        }
    except Exception:
        _restore(snapshot)
        raise


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="software_m5_rollover")
    parser.add_argument("--root", default=".")
    parser.add_argument("--runtime-evidence", required=True)
    parser.add_argument("--root-integration-run-id", required=True, type=int)
    parser.add_argument("--qualification-time")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    if not args.apply:
        payload = {"schema": "llm-agent-software-m5-rollover/v1", "status": "fail", "error": "--apply is required"}
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) if args.summary_json else "[FAIL] --apply is required")
        return 2
    try:
        result = finalize(Path(args.root), Path(args.runtime_evidence), args.root_integration_run_id, args.qualification_time)
    except (OSError, ValueError, RolloverError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        payload = {"schema": "llm-agent-software-m5-rollover/v1", "status": "fail", "error": str(exc)}
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) if args.summary_json else f"[FAIL] {exc}")
        return 1
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")) if args.summary_json else json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
