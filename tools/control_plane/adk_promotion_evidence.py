from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import Any

EVIDENCE_SCHEMA = "adk-promotion-evidence/v1"
EXPECTED_REPOSITORY = "jiying2007/agent-dev-kit"
EXPECTED_REF = "refs/heads/main"
EXPECTED_EVENT = "push"
EXPECTED_WORKFLOW = "agent-dev-kit-ci"
EXPECTED_WORKFLOW_REF = "jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_PYTHON = ["3.11", "3.12"]


def _load_lock(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#"):
            continue
        if "=" not in raw:
            raise ValueError(f"invalid lock line: {raw}")
        key, value = raw.split("=", 1)
        values[key] = value
    if values.get("schema") != "llm-agent-adk-lock/v2":
        raise ValueError("adk.lock schema must be llm-agent-adk-lock/v2")
    required = [
        "agent-dev-kit.version",
        "agent-dev-kit.commit",
        "agent-dev-kit.tree",
        "agent-dev-kit.manifest_blob",
    ]
    missing = [key for key in required if not values.get(key)]
    if missing:
        raise ValueError("adk.lock missing fields: " + ", ".join(missing))
    return values


def _parse_time(value: Any) -> dt.datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise ValueError("issued_at must be RFC3339 UTC ending in Z")
    try:
        parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise ValueError("issued_at is not valid RFC3339") from exc
    if parsed.tzinfo is None:
        raise ValueError("issued_at must be timezone-aware")
    return parsed.astimezone(dt.UTC)


def _expect_hex(value: Any, regex: re.Pattern[str], field: str) -> str:
    if not isinstance(value, str) or regex.fullmatch(value) is None:
        raise ValueError(f"{field} has invalid digest shape")
    return value


def verify_evidence_claims(
    *,
    evidence_path: Path,
    lock_path: Path,
    interface_path: Path,
    now: dt.datetime | None = None,
    max_age_days: int = 30,
) -> dict[str, Any]:
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    interface = json.loads(interface_path.read_text(encoding="utf-8"))
    lock = _load_lock(lock_path)
    if not isinstance(evidence, Mapping):
        raise ValueError("promotion evidence root must be an object")
    if not isinstance(interface, Mapping):
        raise ValueError("interface lock root must be an object")
    if evidence.get("schema") != EVIDENCE_SCHEMA:
        raise ValueError(f"promotion evidence schema must be {EVIDENCE_SCHEMA}")

    source = evidence.get("source")
    contracts = evidence.get("contracts")
    ci = evidence.get("ci")
    release = evidence.get("release")
    provenance = evidence.get("provenance")
    for name, value in (
        ("source", source),
        ("contracts", contracts),
        ("ci", ci),
        ("release", release),
        ("provenance", provenance),
    ):
        if not isinstance(value, Mapping):
            raise ValueError(f"promotion evidence {name} must be an object")

    assert isinstance(source, Mapping)
    assert isinstance(contracts, Mapping)
    assert isinstance(ci, Mapping)
    assert isinstance(release, Mapping)
    assert isinstance(provenance, Mapping)

    expected_identity = {
        "version": lock["agent-dev-kit.version"],
        "commit": lock["agent-dev-kit.commit"],
        "tree": lock["agent-dev-kit.tree"],
        "manifest_blob": lock["agent-dev-kit.manifest_blob"],
    }
    for key, expected in expected_identity.items():
        actual = source.get(key)
        if actual != expected:
            raise ValueError(f"promotion evidence source.{key} does not match adk.lock")
        if interface.get(key) != expected:
            raise ValueError(f"interface lock {key} does not match adk.lock")

    _expect_hex(source.get("commit"), HEX40, "source.commit")
    _expect_hex(source.get("tree"), HEX40, "source.tree")
    _expect_hex(source.get("manifest_blob"), HEX40, "source.manifest_blob")
    _expect_hex(source.get("manifest_sha256"), HEX64, "source.manifest_sha256")
    for field in ("contract_registry_sha256", "schema_set_sha256", "release_manifest_sha256"):
        _expect_hex(contracts.get(field), HEX64, f"contracts.{field}")
    _expect_hex(release.get("artifact_sha256"), HEX64, "release.artifact_sha256")

    if source.get("repository") != EXPECTED_REPOSITORY:
        raise ValueError("promotion evidence must come from the canonical ADK repository")
    if source.get("ref") != EXPECTED_REF or source.get("event") != EXPECTED_EVENT:
        raise ValueError("promotion evidence must come from a push to main")
    if source.get("workflow") != EXPECTED_WORKFLOW or source.get("workflow_ref") != EXPECTED_WORKFLOW_REF:
        raise ValueError("promotion evidence must come from the canonical ADK CI workflow")
    if not isinstance(source.get("run_id"), int) or int(source["run_id"]) < 1:
        raise ValueError("source.run_id must be a positive integer")
    if not isinstance(source.get("run_attempt"), int) or int(source["run_attempt"]) < 1:
        raise ValueError("source.run_attempt must be a positive integer")
    _expect_hex(source.get("workflow_sha"), HEX40, "source.workflow_sha")

    for key in ("contract_matrix", "regression_matrix"):
        matrix = ci.get(key)
        if not isinstance(matrix, Mapping) or matrix.get("status") != "success" or matrix.get("python") != REQUIRED_PYTHON:
            raise ValueError(f"ci.{key} must prove successful Python 3.11/3.12 coverage")
    if ci.get("static_security") != "success" or ci.get("deterministic_eval_package") != "success":
        raise ValueError("promotion evidence required CI claims are not all successful")

    if not isinstance(release.get("release_eligible"), bool):
        raise ValueError("release.release_eligible must be a boolean")
    if provenance.get("subject") != "promotion-evidence.json" or provenance.get("format") != "sigstore-bundle/v1":
        raise ValueError("promotion evidence provenance contract is invalid")

    issued_at = _parse_time(evidence.get("issued_at"))
    current = (now or dt.datetime.now(dt.UTC)).astimezone(dt.UTC)
    if issued_at > current + dt.timedelta(minutes=5):
        raise ValueError("promotion evidence issued_at is in the future")
    if current - issued_at > dt.timedelta(days=max_age_days):
        raise ValueError("promotion evidence is stale")

    return {
        "schema": "llm-agent-adk-promotion-evidence-verification/v1",
        "status": "pass",
        "candidate": expected_identity,
        "source_repository": source["repository"],
        "source_run_id": source["run_id"],
        "source_run_attempt": source["run_attempt"],
        "source_workflow": source["workflow"],
        "issued_at": evidence["issued_at"],
        "release_eligible": release["release_eligible"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Verify portable ADK promotion evidence claims")
    parser.add_argument("--evidence", default="reports/promotion/agent-dev-kit/promotion-evidence.json")
    parser.add_argument("--lock", default="adk.lock")
    parser.add_argument("--interface", default="manifests/adk_interface.lock.json")
    parser.add_argument("--max-age-days", type=int, default=30)
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = verify_evidence_claims(
            evidence_path=Path(args.evidence),
            lock_path=Path(args.lock),
            interface_path=Path(args.interface),
            max_age_days=args.max_age_days,
        )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        result = {
            "schema": "llm-agent-adk-promotion-evidence-verification/v1",
            "status": "fail",
            "error": str(exc),
        }
        if args.summary_json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
