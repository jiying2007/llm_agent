from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Mapping

EVIDENCE_SCHEMA = "llm-agent-runtime-portability-evidence/v1"
CHECK_SCHEMA = "llm-agent-runtime-portability-check/v1"
DEFAULT_EVIDENCE = "reports/long-term-assets/runtime-portability-current.json"
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
READY_BINDING_STATUSES = {"source-set-bound", "ready", "active"}


class PortabilityError(RuntimeError):
    """Evidence exists but violates the portability contract."""


class PortabilityBlocked(RuntimeError):
    """Required real external evidence or an eligible runtime binding is absent."""


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


def _load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise PortabilityBlocked(f"{label} is missing: {path}") from exc
    except (OSError, json.JSONDecodeError) as exc:
        raise PortabilityError(f"{label} is invalid: {path}") from exc
    if not isinstance(value, dict):
        raise PortabilityError(f"{label} must be a JSON object")
    return value


def _repo_path(root: Path, value: Any, label: str) -> Path:
    if not isinstance(value, str) or not value:
        raise PortabilityError(f"{label} must be a non-empty repository-relative path")
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts:
        raise PortabilityError(f"{label} must stay inside the repository")
    path = (root / relative).resolve()
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise PortabilityError(f"{label} resolves outside the repository") from exc
    if not path.is_file() or path.is_symlink():
        raise PortabilityError(f"{label} must reference a regular tracked evidence file: {value}")
    return path


def _require_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise PortabilityError(f"{label} must be a non-empty string")
    return value.strip()


def _require_sha256(value: Any, label: str) -> str:
    text = _require_text(value, label)
    if not SHA256.fullmatch(text):
        raise PortabilityError(f"{label} must be a lowercase SHA-256 digest")
    return text


def _require_full_sha(value: Any, label: str) -> str:
    text = _require_text(value, label)
    if not FULL_SHA.fullmatch(text):
        raise PortabilityError(f"{label} must be an exact 40-character git SHA")
    return text


def _nonempty(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, (list, dict, tuple, set)):
        return bool(value)
    return True


def _contains_verification_pass_claim(value: Any) -> bool:
    if isinstance(value, dict):
        for key, item in value.items():
            normalized = str(key).lower().replace("-", "_")
            if normalized in {"verification_pass", "verification_status", "domain_verification_status"}:
                if item is True or (isinstance(item, str) and item.lower() in {"pass", "passed", "success"}):
                    return True
            if _contains_verification_pass_claim(item):
                return True
    elif isinstance(value, list):
        return any(_contains_verification_pass_claim(item) for item in value)
    return False


def _contract(root: Path) -> dict[str, Any]:
    contract = _load_object(root / "manifests/digital_worker_runtime_pilot.json", "runtime pilot contract")
    if contract.get("schema_version") != 3 or contract.get("contract_version") != "1.2":
        raise PortabilityError("runtime pilot contract version is unsupported")
    if contract.get("status") != "report-only":
        raise PortabilityError("runtime pilot contract must remain report-only")
    rules = contract.get("hard_rules")
    if not isinstance(rules, dict):
        raise PortabilityError("runtime pilot hard rules are missing")
    required_rules = (
        "runtime_output_is_not_verification_pass",
        "runtime_local_conformance_is_not_domain_verification",
        "execution_receipt_must_not_contain_verification_pass",
        "same_verifier_and_reviewer_standard",
        "missing_runtime_health_is_blocked_not_pass",
        "missing_runtime_binding_identity_is_blocked_not_pass",
        "missing_adk_release_identity_is_blocked_not_pass",
        "missing_runtime_source_set_identity_is_blocked_not_pass",
        "missing_runtime_distribution_identity_is_blocked_not_pass",
    )
    if any(rules.get(key) is not True for key in required_rules):
        raise PortabilityError("runtime pilot hard rules are incomplete or weakened")
    return contract


def _authoritative_adk(root: Path) -> dict[str, str]:
    interface = _load_object(root / "manifests/adk_interface.lock.json", "ADK interface lock")
    promotion = _load_object(root / "reports/promotion/agent-dev-kit/promotion-evidence.json", "ADK promotion evidence")
    source = promotion.get("source")
    release = promotion.get("release")
    if interface.get("schema") != "llm-agent-adk-interface-lock/v1":
        raise PortabilityError("ADK interface lock schema is unsupported")
    if not isinstance(source, dict) or not isinstance(release, dict):
        raise PortabilityError("ADK promotion evidence source/release is missing")
    expected = {
        "version": interface.get("version"),
        "commit": interface.get("commit"),
        "tree": interface.get("tree"),
        "manifest_blob": interface.get("manifest_blob"),
        "artifact_sha256": release.get("artifact_sha256"),
    }
    if any(not isinstance(value, str) or not value for value in expected.values()):
        raise PortabilityError("authoritative ADK identity is incomplete")
    for field in ("version", "commit", "tree", "manifest_blob"):
        if source.get(field) != expected[field]:
            raise PortabilityError(f"ADK promotion source.{field} does not match interface lock")
    if release.get("release_eligible") is not True:
        raise PortabilityError("ADK promotion evidence is not release eligible")
    return {key: str(value) for key, value in expected.items()}


def _validate_adk_identity(evidence: Mapping[str, Any], expected: Mapping[str, str]) -> None:
    identity = evidence.get("adk_release_identity")
    if not isinstance(identity, dict):
        raise PortabilityError("adk_release_identity is missing")
    for field, value in expected.items():
        if identity.get(field) != value:
            raise PortabilityError(f"adk_release_identity.{field} does not match authoritative release identity")


def _receipt_binding(
    root: Path,
    runtime: str,
    run: Mapping[str, Any],
    required_identity_fields: list[str],
    frozen_digest: str,
) -> tuple[str, dict[str, Any]]:
    ref = _require_text(run.get("execution_receipt_ref"), f"{runtime}.execution_receipt_ref")
    expected_digest = _require_sha256(run.get("execution_receipt_sha256"), f"{runtime}.execution_receipt_sha256")
    path = _repo_path(root, ref, f"{runtime} execution receipt")
    actual_digest = _sha256_file(path)
    if actual_digest != expected_digest:
        raise PortabilityError(f"{runtime} execution receipt digest does not match content")
    receipt = _load_object(path, f"{runtime} execution receipt")
    if receipt.get("status") != "completed":
        raise PortabilityError(f"{runtime} execution receipt status must be completed, not a verification PASS")
    if receipt.get("runtime") != runtime:
        raise PortabilityError(f"{runtime} execution receipt runtime identity does not match")
    if receipt.get("frozen_inputs_sha256") != frozen_digest:
        raise PortabilityError(f"{runtime} execution receipt is not bound to the shared frozen task")
    if receipt.get("verification_pass_claimed") is not False:
        raise PortabilityError(f"{runtime} execution receipt must explicitly disclaim verification PASS")
    if _contains_verification_pass_claim(receipt):
        raise PortabilityError(f"{runtime} execution receipt contains a forbidden verification PASS claim")
    receipt_identity = receipt.get("runtime_identity")
    if not isinstance(receipt_identity, dict):
        raise PortabilityError(f"{runtime} execution receipt runtime_identity is missing")
    for field in required_identity_fields:
        if field == "execution_receipt_ref":
            continue
        if receipt_identity.get(field) != run.get(field):
            raise PortabilityError(f"{runtime} execution receipt identity field drift: {field}")
    return actual_digest, receipt


def _validate_external_result(
    root: Path,
    evidence: Mapping[str, Any],
    field: str,
    digest_field: str,
    label: str,
    comparison_id: str,
    frozen_digest: str,
    receipt_digests: Mapping[str, str],
    standard_id: str,
    *,
    require_independent: bool,
) -> dict[str, Any]:
    ref = _require_text(evidence.get(field), field)
    expected_digest = _require_sha256(evidence.get(digest_field), digest_field)
    path = _repo_path(root, ref, label)
    actual_digest = _sha256_file(path)
    if actual_digest != expected_digest:
        raise PortabilityError(f"{label} digest does not match content")
    value = _load_object(path, label)
    if value.get("status") != "pass":
        raise PortabilityError(f"{label} must be passing")
    if value.get("comparison_id") != comparison_id or value.get("frozen_inputs_sha256") != frozen_digest:
        raise PortabilityError(f"{label} is not bound to this comparison/frozen task")
    if value.get("standard_id") != standard_id:
        raise PortabilityError(f"{label} does not use the shared verifier/reviewer standard")
    source_repository = value.get("source_repository")
    if source_repository != "jiying2007/digital-worker":
        raise PortabilityError(f"{label} must originate from jiying2007/digital-worker")
    _require_full_sha(value.get("source_commit"), f"{label}.source_commit")
    bound_receipts = value.get("execution_receipts")
    if not isinstance(bound_receipts, dict) or bound_receipts != dict(receipt_digests):
        raise PortabilityError(f"{label} does not bind the exact execution receipt set")
    if require_independent and value.get("independent") is not True:
        raise PortabilityError(f"{label} must be explicitly independent")
    return value


def check(root: Path, evidence_path: Path | None = None) -> dict[str, Any]:
    root = root.resolve()
    contract = _contract(root)
    expected_adk = _authoritative_adk(root)
    evidence = (evidence_path or (root / DEFAULT_EVIDENCE)).resolve()
    try:
        evidence.relative_to(root)
    except ValueError as exc:
        raise PortabilityError("runtime portability evidence must stay inside the repository") from exc
    if not evidence.is_file():
        raise PortabilityBlocked(
            f"LTA-02 real comparison evidence is not available at {evidence.relative_to(root).as_posix()}"
        )
    data = _load_object(evidence, "runtime portability evidence")
    if data.get("schema") != EVIDENCE_SCHEMA:
        raise PortabilityError("runtime portability evidence schema is unsupported")
    comparison_id = _require_text(data.get("comparison_id"), "comparison_id")
    controlled_task = data.get("controlled_task")
    if not isinstance(controlled_task, dict):
        raise PortabilityError("controlled_task must be an object")
    frozen_fields = contract.get("frozen_inputs")
    if not isinstance(frozen_fields, list) or not frozen_fields:
        raise PortabilityError("runtime pilot frozen_inputs contract is invalid")
    missing_frozen = [field for field in frozen_fields if field not in controlled_task or not _nonempty(controlled_task[field])]
    if missing_frozen:
        raise PortabilityError("controlled_task is missing frozen inputs: " + ", ".join(missing_frozen))
    if controlled_task.get("adk_release_identity_ref") != "manifests/adk_interface.lock.json":
        raise PortabilityError("controlled_task.adk_release_identity_ref must bind the canonical ADK interface lock")
    frozen_digest = _digest(controlled_task)
    if data.get("frozen_inputs_sha256") != frozen_digest:
        raise PortabilityError("frozen_inputs_sha256 does not match controlled_task")
    _validate_adk_identity(data, expected_adk)

    candidates = {
        item.get("runtime"): item
        for item in contract.get("candidate_runtime_bindings", [])
        if isinstance(item, dict) and isinstance(item.get("runtime"), str)
    }
    required_identity_fields = contract.get("runtime_identity_required")
    if not isinstance(required_identity_fields, list) or not required_identity_fields:
        raise PortabilityError("runtime_identity_required contract is invalid")
    required_count = 2
    runs = data.get("runtime_runs")
    if not isinstance(runs, list) or len(runs) < required_count:
        raise PortabilityBlocked("LTA-02 requires at least two real runtime execution receipts")

    seen: set[str] = set()
    receipt_digests: dict[str, str] = {}
    for index, raw in enumerate(runs):
        if not isinstance(raw, dict):
            raise PortabilityError(f"runtime_runs[{index}] must be an object")
        runtime = _require_text(raw.get("runtime"), f"runtime_runs[{index}].runtime")
        if runtime in seen:
            raise PortabilityError(f"duplicate runtime in comparison evidence: {runtime}")
        seen.add(runtime)
        candidate = candidates.get(runtime)
        if not isinstance(candidate, dict):
            raise PortabilityError(f"runtime is not declared by the comparison contract: {runtime}")
        if candidate.get("status") not in READY_BINDING_STATUSES:
            raise PortabilityBlocked(f"runtime binding is not source-set-bound/ready: {runtime}")
        if raw.get("healthy") is not True:
            raise PortabilityBlocked(f"runtime binding is not healthy: {runtime}")
        missing_identity = [field for field in required_identity_fields if not _nonempty(raw.get(field))]
        if missing_identity:
            raise PortabilityError(f"{runtime} runtime identity is incomplete: {', '.join(missing_identity)}")
        _require_full_sha(raw.get("runtime_binding_commit"), f"{runtime}.runtime_binding_commit")
        if candidate.get("target") != raw.get("runtime_target"):
            raise PortabilityError(f"{runtime} runtime_target does not match the declared binding target")
        candidate_repository = candidate.get("repository")
        if candidate_repository is not None and raw.get("runtime_binding_repository") != candidate_repository:
            raise PortabilityError(f"{runtime} runtime binding repository does not match the contract")
        receipt_digest, _receipt = _receipt_binding(
            root,
            runtime,
            raw,
            [str(field) for field in required_identity_fields],
            frozen_digest,
        )
        receipt_digests[runtime] = receipt_digest

    if len(seen) < required_count:
        raise PortabilityBlocked("LTA-02 requires two distinct healthy runtime bindings")

    standard_id = _require_text(data.get("verification_standard_id"), "verification_standard_id")
    verification = _validate_external_result(
        root,
        data,
        "domain_verification_ref",
        "domain_verification_sha256",
        "digital-worker domain verification",
        comparison_id,
        frozen_digest,
        receipt_digests,
        standard_id,
        require_independent=False,
    )
    review = _validate_external_result(
        root,
        data,
        "independent_review_ref",
        "independent_review_sha256",
        "digital-worker independent review",
        comparison_id,
        frozen_digest,
        receipt_digests,
        standard_id,
        require_independent=True,
    )
    if verification.get("source_commit") != review.get("source_commit"):
        raise PortabilityError("domain verification and independent review must bind the same digital-worker source commit")

    return {
        "schema": CHECK_SCHEMA,
        "status": "pass",
        "qualification": "LTA-02",
        "comparison_id": comparison_id,
        "work_item_id": controlled_task.get("work_item_id"),
        "frozen_inputs_sha256": frozen_digest,
        "agent_dev_kit": expected_adk,
        "runtimes": sorted(seen),
        "execution_receipts": dict(sorted(receipt_digests.items())),
        "verification_standard_id": standard_id,
        "digital_worker_commit": verification.get("source_commit"),
        "evidence": evidence.relative_to(root).as_posix(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Fail-closed LTA-02 cross-runtime portability certifier")
    parser.add_argument("--root", default=".")
    parser.add_argument("--evidence")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root)
    evidence = Path(args.evidence) if args.evidence else None
    try:
        result = check(root, evidence)
        exit_code = 0
    except PortabilityBlocked as exc:
        result = {"schema": CHECK_SCHEMA, "status": "blocked", "qualification": "LTA-02", "reason": str(exc)}
        exit_code = 2
    except (OSError, ValueError, PortabilityError, json.JSONDecodeError) as exc:
        result = {"schema": CHECK_SCHEMA, "status": "fail", "qualification": "LTA-02", "error": str(exc)}
        exit_code = 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
