from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

from jsonschema import Draft202012Validator, FormatChecker

from .adk_interface import validate as validate_adk_interface

SCHEMA = "llm-agent-effect-readiness/v2"
_INDEX_SCHEMA = "llm-agent-effect-value-evidence-index/v1"
_REVIEW_SCHEMA = "llm-agent-effect-owner-review/v1"
_REQUIRED_CONTRACT_IDS = {"agent-value", "effect-trials", "effect-trial-comparison"}
_REAL_MEASUREMENT_SCOPES = {"runtime-verified", "field-verified"}
_DECISIVE_VERDICTS = {"improved", "non-inferior", "regressed"}
_REQUIRED_SIGNAL_KEYS = {
    "task-success-rate",
    "wrong-route-rate",
    "abstain-precision",
    "human-interventions-per-task",
}
MAX_JSON_BYTES = 16 * 1024 * 1024
MAX_CAMPAIGNS = 50
MAX_RECEIPTS_PER_CAMPAIGN = 500


def _canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def _ref(value: Any) -> str:
    return "ref:" + hashlib.sha256(_canonical_json_bytes(value)).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_object(path: Path, label: str, *, limit: int = MAX_JSON_BYTES) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"{label} is missing or unsafe: {path}")
    if path.stat().st_size > limit:
        raise ValueError(f"{label} exceeds byte budget")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"{label} is invalid JSON") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def _validate_schema(value: Mapping[str, Any], schema_path: Path, label: str) -> None:
    schema = _load_object(schema_path, f"{label} schema", limit=1024 * 1024)
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    error = next(validator.iter_errors(value), None)
    if error is not None:
        location = "/".join(map(str, error.absolute_path)) or "<root>"
        raise ValueError(f"{label} violates schema at {location}: {error.message}")


def _parse_time(value: Any, label: str) -> datetime:
    if not isinstance(value, str):
        raise ValueError(f"{label} must be a timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"{label} is not an ISO timestamp") from exc
    if parsed.tzinfo is None:
        raise ValueError(f"{label} must include timezone")
    return parsed.astimezone(timezone.utc)


def _resolve_evidence_ref(
    root: Path,
    evidence_root: Path,
    value: Mapping[str, Any],
    label: str,
) -> tuple[Path, str]:
    if set(value) != {"path", "sha256"}:
        raise ValueError(f"{label} must contain only path/sha256")
    raw_path, expected = value["path"], value["sha256"]
    if not isinstance(raw_path, str) or not raw_path:
        raise ValueError(f"{label}.path must be a string")
    relative = Path(raw_path)
    if relative.is_absolute() or ".." in relative.parts or "\\" in raw_path:
        raise ValueError(f"{label}.path must be safe relative path")
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"{label}.path must not traverse symlink")
    path = (root / relative).resolve()
    if not path.is_relative_to(evidence_root) or not path.is_file() or path.is_symlink():
        raise ValueError(f"{label}.path must be a regular file under evidence root")
    if not isinstance(expected, str) or len(expected) != 64:
        raise ValueError(f"{label}.sha256 must be lowercase SHA-256")
    actual = _sha256_file(path)
    if actual != expected:
        raise ValueError(f"{label} digest mismatch")
    return path, actual


def _canonical_agent_value_projection(adk: Path) -> dict[str, Any]:
    code = r"""
import json,sys
from pathlib import Path
from agent_dev_kit.agent_value import emit_measurements
from agent_dev_kit.agent_value_contracts import load_contract,validate_contract
from agent_dev_kit.agent_value_trust import load_agent_value_trust_registry
from agent_dev_kit.model import Manifest
root=Path(sys.argv[1]).resolve()
manifest=Manifest.load(root)
contract=load_contract(root/"manifests/agent_value_contracts.json")
report=validate_contract(contract,manifest)
registry=load_agent_value_trust_registry(root)
measurement=emit_measurements([],manifest,contract)
policy=contract["evidence_authority_policy"]
print(json.dumps({
 "contract_report":report,
 "policy":{"status":policy["status"],"backend":policy["backend"],"authority_count":len(policy["authorities"])},
 "registry":{"status":registry["status"],"authority_count":len(registry["authorities"]),"enabled_authority_count":sum(1 for x in registry["authorities"].values() if isinstance(x,dict) and x.get("enabled") is True)},
 "empty_measurement":{"measurement_status":measurement["measurement_status"],"reason":measurement["reason"],"asset_measurement_count":len(measurement["asset_measurements"])}
},sort_keys=True))
"""
    env = {
        "PYTHONPATH": str(adk / "src"),
        "PATH": os.environ.get("PATH", os.defpath),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }
    done = subprocess.run(
        [sys.executable, "-c", code, str(adk)],
        cwd=adk,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        timeout=45,
    )
    if done.returncode:
        raise ValueError("pinned ADK Agent Value projection failed")
    value = json.loads(done.stdout)
    if not isinstance(value, dict):
        raise ValueError("pinned ADK Agent Value projection is invalid")
    return value


def _canonical_effect_comparison(adk: Path, trial_input: Path) -> dict[str, Any]:
    code = r"""
import json,sys
from pathlib import Path
from agent_dev_kit.effect_trials import compare_effect_trial_file
from agent_dev_kit.model import Manifest
root=Path(sys.argv[1]).resolve()
value=compare_effect_trial_file(Path(sys.argv[2]).resolve(),Manifest.load(root))
print(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":")))
"""
    env = {
        "PYTHONPATH": str(adk / "src"),
        "PATH": os.environ.get("PATH", os.defpath),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }
    done = subprocess.run(
        [sys.executable, "-c", code, str(adk), str(trial_input)],
        cwd=adk,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        timeout=180,
    )
    if done.returncode:
        raise ValueError("pinned ADK effect comparison regeneration failed")
    if len(done.stdout.encode("utf-8")) > MAX_JSON_BYTES:
        raise ValueError("regenerated effect comparison exceeds byte budget")
    value = json.loads(done.stdout)
    if not isinstance(value, dict):
        raise ValueError("regenerated effect comparison is invalid")
    return value


def _canonical_measurement(
    adk: Path,
    measurement_path: Path,
    receipt_paths: list[Path],
) -> dict[str, Any]:
    code = r"""
import json,sys
from datetime import datetime
from pathlib import Path
from agent_dev_kit.agent_value import emit_measurements
from agent_dev_kit.agent_value_contracts import load_contract
from agent_dev_kit.agent_value_trust import build_managed_agent_value_evidence_verifier
from agent_dev_kit.model import Manifest
root=Path(sys.argv[1]).resolve()
measurement=json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
manifest=Manifest.load(root)
contract=load_contract(root/"manifests/agent_value_contracts.json")
verifier=build_managed_agent_value_evidence_verifier(manifest,contract)
receipts=[json.loads(Path(p).read_text(encoding="utf-8")) for p in sys.argv[3:]]
parse=lambda x: datetime.fromisoformat(x.replace("Z","+00:00"))
value=emit_measurements(
 receipts,manifest,contract,evidence_verifier=verifier,
 aggregation_window={
  "from":parse(measurement["aggregation_window"]["from"]),
  "through":parse(measurement["aggregation_window"]["through"]),
 },
 as_of=parse(measurement["as_of"]),
)
print(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":")))
"""
    env = {
        "PYTHONPATH": str(adk / "src"),
        "PATH": os.environ.get("PATH", os.defpath),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }
    for key in ("HOME", "XDG_CACHE_HOME", "SSL_CERT_FILE", "SSL_CERT_DIR"):
        value = os.environ.get(key)
        if value:
            env[key] = value
    args = [
        sys.executable,
        "-c",
        code,
        str(adk),
        str(measurement_path),
        *(str(path) for path in receipt_paths),
    ]
    done = subprocess.run(
        args,
        cwd=adk,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        timeout=180,
    )
    if done.returncode:
        raise ValueError("pinned ADK Agent Value measurement regeneration failed")
    if len(done.stdout.encode("utf-8")) > MAX_JSON_BYTES:
        raise ValueError("regenerated Agent Value measurement exceeds byte budget")
    value = json.loads(done.stdout)
    if not isinstance(value, dict):
        raise ValueError("regenerated Agent Value measurement is invalid")
    return value


def _review_pairs(review: Mapping[str, Any]) -> dict[tuple[str, str], Mapping[str, Any]]:
    result: dict[tuple[str, str], Mapping[str, Any]] = {}
    for item in review["lifecycle_reviews"]:
        key = (str(item["asset_kind"]), str(item["asset_id"]))
        if key in result:
            raise ValueError(f"duplicate lifecycle review for {key[0]}:{key[1]}")
        result[key] = item
    return result


def _validate_campaign(
    root: Path,
    adk: Path,
    evidence_root: Path,
    record: Mapping[str, Any],
    *,
    authority_enabled: bool,
) -> dict[str, Any]:
    campaign_id = str(record["campaign_id"])
    trial_path, trial_sha = _resolve_evidence_ref(
        root, evidence_root, record["trial_input"], f"{campaign_id}.trial_input"
    )
    comparison_path, comparison_sha = _resolve_evidence_ref(
        root, evidence_root, record["comparison"], f"{campaign_id}.comparison"
    )
    measurement_path, measurement_sha = _resolve_evidence_ref(
        root, evidence_root, record["measurement"], f"{campaign_id}.measurement"
    )
    review_path, review_sha = _resolve_evidence_ref(
        root, evidence_root, record["owner_review"], f"{campaign_id}.owner_review"
    )
    receipts: list[Path] = []
    receipt_shas: list[str] = []
    if not isinstance(record["receipts"], list) or not 1 <= len(record["receipts"]) <= MAX_RECEIPTS_PER_CAMPAIGN:
        raise ValueError(f"{campaign_id}.receipts has invalid cardinality")
    for index, ref in enumerate(record["receipts"]):
        path, digest = _resolve_evidence_ref(
            root, evidence_root, ref, f"{campaign_id}.receipts[{index}]"
        )
        receipts.append(path)
        receipt_shas.append(digest)

    trial = _load_object(trial_path, f"{campaign_id} trial input")
    comparison = _load_object(comparison_path, f"{campaign_id} comparison")
    measurement = _load_object(measurement_path, f"{campaign_id} measurement")
    review = _load_object(review_path, f"{campaign_id} owner review", limit=1024 * 1024)

    _validate_schema(trial, adk / "schemas/effect-trials-v1.schema.json", f"{campaign_id} trial input")
    _validate_schema(
        comparison,
        adk / "schemas/effect-trial-comparison-v1.schema.json",
        f"{campaign_id} comparison",
    )
    _validate_schema(
        measurement,
        adk / "schemas/asset-value-measurement-v1.schema.json",
        f"{campaign_id} measurement",
    )
    _validate_schema(
        review,
        root / "schemas/effect-owner-review-v1.schema.json",
        f"{campaign_id} owner review",
    )
    for index, path in enumerate(receipts):
        receipt = _load_object(path, f"{campaign_id} receipt[{index}]")
        _validate_schema(
            receipt,
            adk / "schemas/asset-invocation-receipt-v1.schema.json",
            f"{campaign_id} receipt[{index}]",
        )

    if trial["plan"]["campaign_id"] != campaign_id or comparison.get("campaign_id") != campaign_id:
        raise ValueError(f"{campaign_id} campaign identity mismatch")
    generated = _canonical_effect_comparison(adk, trial_path)
    if generated != comparison:
        raise ValueError(f"{campaign_id} comparison differs from pinned ADK regeneration")
    if comparison["input_ref"] != _ref(trial):
        raise ValueError(f"{campaign_id} comparison input_ref mismatch")
    if comparison["plan_ref"] != _ref(trial["plan"]):
        raise ValueError(f"{campaign_id} comparison plan_ref mismatch")
    if comparison["controls_ref"] != _ref(trial["plan"]["controls"]):
        raise ValueError(f"{campaign_id} comparison controls_ref mismatch")

    candidate_bundle = trial["plan"]["bundles"]["candidate"]
    decisive = comparison["verdict"] in _DECISIVE_VERDICTS
    measurement_real = measurement.get("evidence_scope") in _REAL_MEASUREMENT_SCOPES
    measurement_verified = False
    measurement_error: str | None = None
    if authority_enabled:
        try:
            regenerated = _canonical_measurement(adk, measurement_path, receipts)
            measurement_verified = regenerated == measurement
            if not measurement_verified:
                measurement_error = "measurement differs from pinned ADK regeneration"
        except ValueError as exc:
            measurement_error = str(exc)
    else:
        measurement_error = "managed Agent Value authority is not enabled"

    measured_assets: set[tuple[str, str]] = set()
    asset_kinds: set[str] = set()
    signal_coverage = {name: False for name in _REQUIRED_SIGNAL_KEYS}
    retirement_signal = False
    if measurement.get("measurement_status") == "measured":
        for item in measurement["asset_measurements"]:
            key = (str(item["asset_kind"]), str(item["asset_id"]))
            if key in measured_assets:
                raise ValueError(f"{campaign_id} duplicate measured asset {key}")
            measured_assets.add(key)
            asset_kinds.add(key[0])
            if candidate_bundle not in item["asset_bundle_sha256s"]:
                raise ValueError(f"{campaign_id} measured asset is not bound to candidate bundle")
            if item["source_verification"] != "managed-authority-verified":
                raise ValueError(f"{campaign_id} measurement source is not managed-authority verified")
            if not item["authority_ids"]:
                raise ValueError(f"{campaign_id} measurement has no authority identity")
            for metric_name in signal_coverage:
                metric = item["metrics"][metric_name]
                signal_coverage[metric_name] |= metric["status"] == "measured"
            retirement_signal |= any(
                signal != "insufficient-evidence" for signal in item["retirement_signals"]
            )

    evidence = review["evidence"]
    if review["campaign_id"] != campaign_id:
        raise ValueError(f"{campaign_id} owner review campaign mismatch")
    if evidence["trial_input_sha256"] != trial_sha:
        raise ValueError(f"{campaign_id} owner review trial digest mismatch")
    if evidence["comparison_sha256"] != comparison_sha:
        raise ValueError(f"{campaign_id} owner review comparison digest mismatch")
    if evidence["measurement_sha256"] != measurement_sha:
        raise ValueError(f"{campaign_id} owner review measurement digest mismatch")
    if evidence["candidate_bundle_sha256"] != candidate_bundle:
        raise ValueError(f"{campaign_id} owner review candidate bundle mismatch")

    reviews = _review_pairs(review)
    if set(reviews) != measured_assets:
        raise ValueError(f"{campaign_id} owner review does not cover exactly the measured assets")
    for key, item in reviews.items():
        decision = str(item["decision"])
        if decision == "observe":
            continue
        measurement_item = next(
            value
            for value in measurement["asset_measurements"]
            if (str(value["asset_kind"]), str(value["asset_id"])) == key
        )
        if decision not in set(measurement_item["retirement_signals"]):
            raise ValueError(f"{campaign_id} lifecycle decision is not supported by measurement signal")

    trial_as_of = _parse_time(trial["plan"]["window"]["as_of"], f"{campaign_id} trial as_of")
    measurement_as_of = _parse_time(measurement["as_of"], f"{campaign_id} measurement as_of")
    reviewed_at = _parse_time(review["reviewed_at"], f"{campaign_id} reviewed_at")
    if reviewed_at < max(trial_as_of, measurement_as_of):
        raise ValueError(f"{campaign_id} owner review predates the evidence")

    accepted = (
        review["decision"] == "accept-evidence"
        and decisive
        and measurement_real
        and measurement_verified
        and bool(measured_assets)
        and all(signal_coverage.values())
        and retirement_signal
    )
    return {
        "id": record["id"],
        "campaign_id": campaign_id,
        "accepted": accepted,
        "review_decision": review["decision"],
        "comparison_verdict": comparison["verdict"],
        "comparison_decisive": decisive,
        "measurement_scope": measurement.get("evidence_scope"),
        "measurement_verified": measurement_verified,
        "measurement_error": measurement_error,
        "receipt_count": len(receipts),
        "receipt_sha256s": sorted(receipt_shas),
        "asset_kinds": sorted(asset_kinds),
        "measured_asset_count": len(measured_assets),
        "signal_coverage": signal_coverage,
        "retirement_signal_observed": retirement_signal,
        "candidate_bundle_sha256": candidate_bundle,
        "owner_review_sha256": review_sha,
    }


def _project_evidence(
    root: Path,
    adk: Path,
    *,
    authority_enabled: bool,
) -> dict[str, Any]:
    index_path = root / "manifests/effect_value_evidence_index.json"
    index = _load_object(index_path, "effect evidence index", limit=1024 * 1024)
    _validate_schema(
        index,
        root / "schemas/effect-value-evidence-index-v1.schema.json",
        "effect evidence index",
    )
    if index.get("schema") != _INDEX_SCHEMA or index.get("status") != "active":
        raise ValueError("unsupported effect evidence index identity")
    campaigns = index["campaigns"]
    if len(campaigns) > MAX_CAMPAIGNS:
        raise ValueError("effect evidence index exceeds campaign budget")
    ids = [item["id"] for item in campaigns]
    campaign_ids = [item["campaign_id"] for item in campaigns]
    if len(ids) != len(set(ids)) or len(campaign_ids) != len(set(campaign_ids)):
        raise ValueError("effect evidence index campaign identities must be unique")

    evidence_root = (root / index["policy"]["evidence_root"]).resolve()
    if not evidence_root.is_relative_to(root):
        raise ValueError("effect evidence root escapes repository")
    projections = [
        _validate_campaign(
            root,
            adk,
            evidence_root,
            item,
            authority_enabled=authority_enabled,
        )
        for item in campaigns
    ]
    accepted = [item for item in projections if item["accepted"]]
    kinds = sorted({kind for item in accepted for kind in item["asset_kinds"]})
    signal_coverage = {
        name: any(item["signal_coverage"][name] for item in accepted)
        for name in _REQUIRED_SIGNAL_KEYS
    }
    retirement_signal = any(item["retirement_signal_observed"] for item in accepted)
    policy = index["policy"]
    required_kinds = set(policy["required_asset_kinds"])
    ready = (
        len(accepted) >= policy["minimum_accepted_campaigns"]
        and required_kinds <= set(kinds)
        and all(signal_coverage.values())
        and retirement_signal
    )
    return {
        "schema": index["schema"],
        "campaign_count": len(projections),
        "accepted_campaign_count": len(accepted),
        "accepted_campaign_ids": [item["campaign_id"] for item in accepted],
        "asset_kinds_covered": kinds,
        "required_asset_kinds": sorted(required_kinds),
        "signal_coverage": signal_coverage,
        "retirement_signal_observed": retirement_signal,
        "ready": ready,
        "campaigns": projections,
        "policy": policy,
    }


def project(root: Path) -> dict[str, Any]:
    root = root.resolve()
    interface = validate_adk_interface(root, require_worktree=True)
    if interface["status"] != "pass":
        return {
            "schema": SCHEMA,
            "status": "fail",
            "terminal_status": "invalid-source",
            "software_ready": False,
            "effect_evidence_ready": False,
            "failures": list(interface.get("failures", [])),
            "blockers": [],
            "release_authorized": False,
        }

    adk = (root / "agent-dev-kit").resolve()
    registry = _load_object(adk / "manifests/contract_registry.json", "ADK contract registry")
    entries = {
        item.get("id"): item
        for item in registry.get("contracts", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    missing_contracts = sorted(_REQUIRED_CONTRACT_IDS - set(entries))
    schema_failures: list[str] = []
    for contract_id in sorted(_REQUIRED_CONTRACT_IDS & set(entries)):
        schema_path = entries[contract_id].get("schema_path")
        if not isinstance(schema_path, str) or not (adk / schema_path).is_file():
            schema_failures.append(contract_id)

    required_files = (
        "src/agent_dev_kit/effect_trials.py",
        "src/agent_dev_kit/agent_value.py",
        "src/agent_dev_kit/agent_value_contracts.py",
        "src/agent_dev_kit/agent_value_receipts.py",
        "src/agent_dev_kit/agent_value_trust.py",
        "manifests/agent_value_contracts.json",
        "manifests/agent_value_trust_registry.json",
        "docs/runbooks/effect-trials.md",
        "docs/runbooks/agent-value-lifecycle.md",
    )
    missing_files = [item for item in required_files if not (adk / item).is_file()]
    value = _canonical_agent_value_projection(adk)

    policy = value["policy"]
    trust_registry = value["registry"]
    empty_measurement = value["empty_measurement"]
    software_ready = (
        not missing_contracts
        and not schema_failures
        and not missing_files
        and empty_measurement["measurement_status"] == "not-measured"
        and empty_measurement["reason"] == "no-valid-receipts"
    )
    authority_enabled = (
        policy["status"] == "enabled"
        and policy["authority_count"] > 0
        and trust_registry["enabled_authority_count"] > 0
    )
    evidence = _project_evidence(root, adk, authority_enabled=authority_enabled)
    effect_evidence_ready = software_ready and authority_enabled and evidence["ready"]

    blockers: list[str] = []
    if not software_ready:
        blockers.append("effect-software-foundation-incomplete")
    if policy["status"] != "enabled":
        blockers.append("external-evidence-required:owner-reviewed-agent-value-authority")
    if trust_registry["enabled_authority_count"] == 0:
        blockers.append("external-evidence-required:enabled-agent-value-trust-registry-authority")
    if evidence["campaign_count"] == 0:
        blockers.append("external-evidence-required:effect-evidence-index-campaign")
    if evidence["accepted_campaign_count"] < evidence["policy"]["minimum_accepted_campaigns"]:
        blockers.append("external-evidence-required:accepted-effect-campaign")
    missing_kinds = sorted(
        set(evidence["required_asset_kinds"]) - set(evidence["asset_kinds_covered"])
    )
    if missing_kinds:
        blockers.append("external-evidence-required:asset-kind-coverage:" + ",".join(missing_kinds))
    for name, covered in evidence["signal_coverage"].items():
        if not covered:
            blockers.append("external-evidence-required:signal:" + name)
    if not evidence["retirement_signal_observed"]:
        blockers.append("external-evidence-required:retirement-signal")
    if not effect_evidence_ready:
        blockers.append("external-evidence-required:owner-review-complete-evidence-chain")

    terminal_status = (
        "blocked-software"
        if not software_ready
        else "blocked-external-evidence"
        if not effect_evidence_ready
        else "ready"
    )
    return {
        "schema": SCHEMA,
        "status": "pass",
        "terminal_status": terminal_status,
        "software_ready": software_ready,
        "software": {
            "required_contract_ids": sorted(_REQUIRED_CONTRACT_IDS),
            "missing_contract_ids": missing_contracts,
            "schema_failures": schema_failures,
            "missing_files": missing_files,
            "agent_value_contract": value["contract_report"],
        },
        "authority": {
            "contract_policy_status": policy["status"],
            "contract_backend": policy["backend"],
            "contract_authority_count": policy["authority_count"],
            "registry_status": trust_registry["status"],
            "registry_authority_count": trust_registry["authority_count"],
            "registry_enabled_authority_count": trust_registry["enabled_authority_count"],
            "enabled_for_real_measurement": authority_enabled,
        },
        "measurement_baseline": empty_measurement,
        "evidence_index": evidence,
        "effect_evidence_ready": effect_evidence_ready,
        "blockers": blockers,
        "authority_boundary": {
            "synthetic_trials_are_real_effect_evidence": False,
            "test_receipts_are_runtime_or_field_evidence": False,
            "software_ready_is_effectiveness_proof": False,
            "retirement_signal_is_lifecycle_authority": False,
            "owner_review_auto_applies_lifecycle_change": False,
        },
        "adk_identity": interface["identity"],
        "release_authorized": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Project Agent/Skill/Profile effect/value readiness")
    parser.add_argument("--root", default=".")
    parser.add_argument("--require-evidence", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = project(Path(args.root))
    except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError) as exc:
        result = {
            "schema": SCHEMA,
            "status": "fail",
            "terminal_status": "invalid-source",
            "software_ready": False,
            "effect_evidence_ready": False,
            "failures": [str(exc)],
            "blockers": [],
            "release_authorized": False,
        }
    print(
        json.dumps(result, ensure_ascii=False, sort_keys=True)
        if args.summary_json
        else json.dumps(result, ensure_ascii=False, indent=2)
    )
    if result["status"] != "pass":
        return 1
    if args.require_evidence and result["terminal_status"] != "ready":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
