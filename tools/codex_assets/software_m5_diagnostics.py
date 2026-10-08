"""Read-only current-candidate gaps, separate from historical qualification."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
from typing import Any, Callable, Sequence

from tools.codex_assets import software_m5_v3 as certifier
from tools.codex_assets import software_m5_v3_core as core

SCHEMA = "llm-agent-current-m5-diagnostics/v1"


def _stage(operation: Callable[[], Any]) -> dict[str, Any]:
    try:
        value = operation()
        return {"status": "pass", "result": value}
    except (core.M5Error, OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        return {"status": "fail", "reason": str(exc)}


def _lock(root: Path) -> dict[str, str]:
    try:
        from tools.codex_assets.intake_io import read_bytes

        text = read_bytes(root / "adk.lock", label="current ADK lock", max_bytes=8192).decode("utf-8")
    except (ImportError, OSError, ValueError, RuntimeError) as exc:
        raise core.M5Error("current ADK lock is unavailable or unsafe") from exc
    result = {}
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in result:
            raise core.M5Error("current ADK lock contains duplicate keys")
        result[key] = value
    if result.get("schema") != "llm-agent-adk-lock/v2":
        raise core.M5Error("current ADK lock schema is invalid")
    for name in ("version", "commit", "tree", "manifest_blob"):
        if not result.get("agent-dev-kit." + name):
            raise core.M5Error("current ADK candidate identity is incomplete")
    return result


def _qualification(root: Path, policy: dict[str, Any], candidate: dict[str, str]) -> dict[str, Any]:
    result = core._validate_qualification_record(root, policy)
    record = core._load_object(core._repo_path(root, policy["qualification_record"], "qualification"), "qualification")
    identity = record.get("adk")
    if not isinstance(identity, dict) or any(identity.get(key) != value for key, value in candidate.items()):
        raise core.M5Error("qualification identity is historical or does not bind current candidate")
    return result


def diagnose(root: Path) -> dict[str, Any]:
    root = root.resolve()
    stages: dict[str, Any] = {}
    result: dict[str, Any] = {"schema": SCHEMA, "status": "blocked", "read_only": True,
                              "model_invocations": 0, "write_performed": False,
                              "software_m5_certified": False, "release_authorized": False,
                              "stages": stages, "historical_qualification_modified": False}
    lock_stage = _stage(lambda: _lock(root))
    stages["candidate"] = lock_stage
    if lock_stage["status"] != "pass":
        result["blocking_gates"] = ["candidate"]
        return result
    lock = lock_stage["result"]
    candidate = {name: lock["agent-dev-kit." + name] for name in ("version", "commit", "tree", "manifest_blob")}
    result["current_candidate"] = candidate
    policy_stage = _stage(lambda: core._load_object(root / "manifests/software_m5_policy.json", "M5 policy"))
    stages["policy"] = {"status": policy_stage["status"]}
    if policy_stage["status"] != "pass":
        stages["policy"] = policy_stage
        result["blocking_gates"] = ["policy"]
        return result
    historical = policy_stage["result"]
    old_release = historical.get("release")
    result["historical_candidate_version"] = old_release.get("candidate_version") if isinstance(old_release, dict) else None
    stages["policy_contract"] = _stage(lambda: core._validate_policy(historical))
    current = copy.deepcopy(historical)
    release = current.get("release")
    if not isinstance(release, dict):
        result["blocking_gates"] = ["policy_contract"]
        return result
    for key, value in candidate.items():
        release["candidate_" + key] = value
    promotion_stage = _stage(lambda: core._load_object(core._repo_path(root, release["promotion_evidence"], "promotion"), "promotion"))
    if promotion_stage["status"] == "pass":
        published = promotion_stage["result"].get("release")
        if isinstance(published, dict):
            release["candidate_artifact_sha256"] = published.get("artifact_sha256")
    stages["promotion_claims"] = _stage(lambda: core._validate_promotion(root, current))
    # Claims and a nonempty bundle never establish cryptographic verification.
    stages["promotion_signature"] = {"status": "blocked", "reason": "fresh pinned-verifier readback required"}
    stages["runtime"] = _stage(lambda: core._validate_runtime(root, current))
    stages["field"] = _stage(lambda: certifier._validate_field(root, current))
    stages["qualification"] = _stage(lambda: _qualification(root, current, candidate))
    historical_status = _stage(lambda: certifier.check(root))
    stages["historical_declaration"] = {"status": "fail", "reason": "historical declaration is not current qualification"}
    if historical_status["status"] == "pass":
        status = historical_status["result"]
        stages["historical_declaration"]["observed"] = {key: status.get(key) for key in ("integrity_status", "declaration_status", "software_m5_certified")}
    result["blocking_gates"] = [name for name, value in stages.items() if value["status"] != "pass"]
    result["next_actions"] = ["verify actual promotion with pinned identity/issuer", "collect new current-candidate measured runtime evidence after authorization", "review current qualification and declaration without overwriting history"]
    result["diagnostics_sha256"] = hashlib.sha256(json.dumps(result, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    return result


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    result = diagnose(Path(args.root))
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0 if result["status"] == "pass" else 2


if __name__ == "__main__":
    raise SystemExit(main())
