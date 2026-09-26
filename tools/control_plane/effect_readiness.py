from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .adk_interface import validate as validate_adk_interface

SCHEMA = "llm-agent-effect-readiness/v1"
INDEX_SCHEMA = "llm-agent-effect-value-evidence-index/v2"
OWNER_REVIEW_SCHEMA = "llm-agent-effect-owner-review/v2"
DEFAULT_INDEX = Path("reports/runtime-evidence/effect-value/evidence-index.json")
_REQUIRED_CONTRACT_IDS = {"agent-value", "effect-trials", "effect-trial-comparison"}
_DECISIVE_VERDICTS = {"improved", "non-inferior", "regressed"}
_DECISIONS = {"retain", "consolidate-candidate", "retire-candidate", "reject-change"}
_MAX_JSON_BYTES = 16 * 1024 * 1024


def _load_object(path: Path, label: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"{label} is missing or unsafe: {path}")
    if path.stat().st_size > _MAX_JSON_BYTES:
        raise ValueError(f"{label} exceeds byte budget: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _safe_path(root: Path, base: Path, value: Any, label: str) -> Path:
    if (
        not isinstance(value, str)
        or not value
        or Path(value).is_absolute()
        or ".." in Path(value).parts
        or "\\" in value
        or "\x00" in value
        or "\n" in value
        or "\r" in value
    ):
        raise ValueError(f"{label} must be a safe relative path")
    path = (root / value).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"{label} escapes root")
    if not path.is_relative_to(base.resolve()):
        raise ValueError(f"{label} must stay under {base.relative_to(root)}")
    return path


def _parse_time(value: Any, label: str) -> datetime:
    if not isinstance(value, str):
        raise ValueError(f"{label} must be a timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"{label} is invalid") from exc
    if parsed.tzinfo is None:
        raise ValueError(f"{label} must include a timezone")
    return parsed.astimezone(timezone.utc)


def _schema_validate(adk: Path, schema_relative: str, document: Path, label: str) -> None:
    schema = (adk / schema_relative).resolve()
    if not schema.is_relative_to(adk.resolve()) or not schema.is_file():
        raise ValueError(f"{label} schema is missing")
    code = r'''
import json,sys
from jsonschema import Draft202012Validator,FormatChecker
schema=json.load(open(sys.argv[1],encoding="utf-8"))
document=json.load(open(sys.argv[2],encoding="utf-8"))
validator=Draft202012Validator(schema,format_checker=FormatChecker())
errors=sorted(validator.iter_errors(document),key=lambda e:list(e.absolute_path))
if errors:
    first=errors[0]
    location="/".join(map(str,first.absolute_path)) or "<root>"
    raise SystemExit("schema-failure:"+location+":"+first.message)
'''
    env = {
        "PYTHONPATH": str(adk / "src"),
        "PATH": os.environ.get("PATH", os.defpath),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }
    done = subprocess.run(
        [sys.executable, "-c", code, str(schema), str(document)],
        cwd=adk,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        timeout=45,
    )
    if done.returncode:
        reason = (done.stderr or done.stdout).strip()[-1000:]
        raise ValueError(f"{label} violates pinned ADK schema: {reason}")


def _recompute_effect_comparison(adk: Path, campaign: Path) -> dict[str, Any]:
    code = r'''
import json,sys
from pathlib import Path
from agent_dev_kit.effect_trials import compare_effect_trial_file
from agent_dev_kit.model import Manifest
root=Path(sys.argv[1]).resolve()
campaign=Path(sys.argv[2]).resolve()
value=compare_effect_trial_file(campaign, Manifest.load(root))
print(json.dumps(value,ensure_ascii=False,sort_keys=True))
'''
    env = {
        "PYTHONPATH": str(adk / "src"),
        "PATH": os.environ.get("PATH", os.defpath),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }
    done = subprocess.run(
        [sys.executable, "-c", code, str(adk), str(campaign)],
        cwd=adk,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        timeout=45,
    )
    if done.returncode:
        reason = (done.stderr or done.stdout).strip()[-1000:]
        raise ValueError(f"effect trial campaign recomputation failed: {reason}")
    value = json.loads(done.stdout)
    if not isinstance(value, dict):
        raise ValueError("effect trial campaign recomputation is invalid")
    return value


def _campaign_bindings(campaign: dict[str, Any]) -> tuple[set[str], set[str], str]:
    plan = campaign.get("plan")
    trials = campaign.get("trials")
    if not isinstance(plan, dict) or not isinstance(trials, list):
        raise ValueError("effect trial campaign plan/trials are invalid")
    bundles = plan.get("bundles")
    controls = plan.get("controls")
    if not isinstance(bundles, dict) or set(bundles) != {"baseline", "candidate"}:
        raise ValueError("effect trial campaign bundles are invalid")
    campaign_bundles = {str(bundles["baseline"]), str(bundles["candidate"])}
    if len(campaign_bundles) != 2:
        raise ValueError("effect trial campaign must compare distinct bundles")
    if not isinstance(controls, dict):
        raise ValueError("effect trial campaign controls are invalid")
    runtime_target = controls.get("runtime_target")
    if not isinstance(runtime_target, str) or not runtime_target:
        raise ValueError("effect trial campaign runtime target is invalid")

    trace_refs: set[str] = set()
    for trial in trials:
        if not isinstance(trial, dict):
            raise ValueError("effect trial campaign contains invalid trial")
        for side in ("baseline", "candidate"):
            bindings = trial.get(side)
            if not isinstance(bindings, list):
                raise ValueError("effect trial campaign condition bindings are invalid")
            for binding in bindings:
                if not isinstance(binding, dict):
                    raise ValueError("effect trial campaign binding is invalid")
                run = binding.get("run")
                trace_ref = run.get("trace_ref") if isinstance(run, dict) else None
                if (
                    not isinstance(trace_ref, str)
                    or not trace_ref.startswith("ref:")
                    or len(trace_ref) != 68
                    or any(ch not in "0123456789abcdef" for ch in trace_ref[4:])
                ):
                    raise ValueError("effect trial campaign run lacks a valid trace_ref")
                trace_refs.add(trace_ref)
    if not trace_refs:
        raise ValueError("effect trial campaign contains no trace refs")
    return trace_refs, campaign_bundles, runtime_target


def _canonical_agent_value_projection(adk: Path) -> dict[str, Any]:
    code = r'''
import json,sys
from pathlib import Path
from agent_dev_kit.agent_value import emit_measurements
from agent_dev_kit.agent_value_contracts import load_contract,validate_contract
from agent_dev_kit.agent_value_trust import load_agent_value_trust_registry
from agent_dev_kit.model import Manifest
from agent_dev_kit.privacy_ref import opaque_ref_for_sha256
root=Path(sys.argv[1]).resolve()
manifest=Manifest.load(root)
contract=load_contract(root/"manifests/agent_value_contracts.json")
report=validate_contract(contract,manifest)
registry=load_agent_value_trust_registry(root)
measurement=emit_measurements([],manifest,contract)
policy=contract["evidence_authority_policy"]
print(json.dumps({
 "contract_report":report,
 "manifest_ref":opaque_ref_for_sha256(manifest.digest),
 "policy":{"status":policy["status"],"backend":policy["backend"],"authority_count":len(policy["authorities"])},
 "registry":{"status":registry["status"],"authority_count":len(registry["authorities"]),"enabled_authority_count":sum(1 for x in registry["authorities"].values() if isinstance(x,dict) and x.get("enabled") is True)},
 "empty_measurement":{"measurement_status":measurement["measurement_status"],"reason":measurement["reason"],"asset_measurement_count":len(measurement["asset_measurements"])}
},sort_keys=True))
'''
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


def _expected_assets(adk: Path) -> set[tuple[str, str]]:
    manifest = _load_object(adk / "manifest.json", "ADK manifest")
    result: set[tuple[str, str]] = set()
    for key, kind in (("agents", "agent"), ("skills", "skill"), ("optional_skills", "skill")):
        values = manifest.get(key, [])
        if not isinstance(values, list):
            raise ValueError(f"ADK manifest {key} must be a list")
        for item in values:
            if not isinstance(item, dict) or not isinstance(item.get("name"), str):
                raise ValueError(f"ADK manifest {key} contains invalid asset")
            result.add((kind, item["name"]))
    profiles = manifest.get("profiles")
    if not isinstance(profiles, dict):
        raise ValueError("ADK manifest profiles must be an object")
    for name in profiles:
        if not isinstance(name, str) or not name:
            raise ValueError("ADK manifest profile id is invalid")
        result.add(("profile", name))
    return result


def _validate_owner_review(
    review: dict[str, Any],
    *,
    campaign_id: str,
    campaign_sha256: str,
    comparison_sha256: str,
    measurement_sha256: str,
    measurement_assets: set[tuple[str, str]],
) -> dict[tuple[str, str], str]:
    required = {
        "schema",
        "status",
        "campaign_id",
        "campaign_sha256",
        "comparison_sha256",
        "measurement_sha256",
        "reviewed_at",
        "reviewed_by",
        "reviewer_role",
        "automation_generated",
        "observed_cases",
        "asset_decisions",
        "raw_content_stored",
        "release_authorized",
        "lifecycle_authority",
    }
    if set(review) != required:
        raise ValueError("owner review fields are invalid")
    if review["schema"] != OWNER_REVIEW_SCHEMA or review["status"] != "approved":
        raise ValueError("owner review schema/status is invalid")
    if review["campaign_id"] != campaign_id:
        raise ValueError("owner review campaign differs from comparison")
    if review["campaign_sha256"] != campaign_sha256:
        raise ValueError("owner review campaign digest mismatch")
    if review["comparison_sha256"] != comparison_sha256:
        raise ValueError("owner review comparison digest mismatch")
    if review["measurement_sha256"] != measurement_sha256:
        raise ValueError("owner review measurement digest mismatch")
    reviewed_at = _parse_time(review["reviewed_at"], "owner review timestamp")
    if reviewed_at > datetime.now(timezone.utc):
        raise ValueError("owner review timestamp is in the future")
    reviewer = review.get("reviewed_by")
    if not isinstance(reviewer, str) or not reviewer.strip() or len(reviewer) > 128:
        raise ValueError("owner review requires a real reviewed_by identity")
    if review["reviewer_role"] != "owner":
        raise ValueError("owner review must use reviewer_role=owner")
    if review["automation_generated"] is not False:
        raise ValueError("owner review must not be automation generated")
    observed = review["observed_cases"]
    if (
        not isinstance(observed, dict)
        or set(observed) != {"success", "failure", "wrong_route", "abstain"}
        or any(observed[name] is not True for name in observed)
    ):
        raise ValueError("owner review must confirm representative observed cases")
    if review["raw_content_stored"] is not False or review["release_authorized"] is not False:
        raise ValueError("owner review privacy/release boundary is invalid")
    if review["lifecycle_authority"] != "owner-review-recorded-execution-separate":
        raise ValueError("owner review lifecycle boundary is invalid")
    decisions = review["asset_decisions"]
    if not isinstance(decisions, list) or not decisions:
        raise ValueError("owner review requires asset decisions")
    result: dict[tuple[str, str], str] = {}
    for item in decisions:
        if not isinstance(item, dict) or set(item) != {"asset_id", "asset_kind", "decision"}:
            raise ValueError("owner review asset decision is invalid")
        pair = (item["asset_kind"], item["asset_id"])
        if pair in result:
            raise ValueError("owner review has duplicate asset decision")
        if pair not in measurement_assets:
            raise ValueError("owner review references asset absent from measurement")
        if item["decision"] not in _DECISIONS:
            raise ValueError("owner review decision is invalid")
        result[pair] = item["decision"]
    if set(result) != measurement_assets:
        raise ValueError("owner review must cover every measured asset")
    return result


def _validate_evidence_entry(
    root: Path,
    adk: Path,
    evidence_root: Path,
    entry: dict[str, Any],
    manifest_ref: str,
) -> tuple[set[tuple[str, str]], dict[tuple[str, str], str], dict[str, Any]]:
    required = {
        "id",
        "campaign_path",
        "campaign_sha256",
        "comparison_path",
        "comparison_sha256",
        "measurement_path",
        "measurement_sha256",
        "owner_review_path",
        "owner_review_sha256",
    }
    if set(entry) != required:
        raise ValueError("effect evidence entry fields are invalid")
    entry_id = entry["id"]
    if (
        not isinstance(entry_id, str)
        or not entry_id
        or len(entry_id) > 128
        or any(ch not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-" for ch in entry_id)
    ):
        raise ValueError("effect evidence entry id is invalid")

    docs: dict[str, tuple[Path, str]] = {}
    for name in ("campaign", "comparison", "measurement", "owner_review"):
        path = _safe_path(root, evidence_root, entry[f"{name}_path"], f"{name} path")
        expected = entry[f"{name}_sha256"]
        if (
            not isinstance(expected, str)
            or len(expected) != 64
            or any(ch not in "0123456789abcdef" for ch in expected)
        ):
            raise ValueError(f"{name} digest is invalid")
        actual = _sha256_file(path)
        if actual != expected:
            raise ValueError(f"{name} digest mismatch")
        docs[name] = (path, actual)

    campaign_path, campaign_sha = docs["campaign"]
    comparison_path, comparison_sha = docs["comparison"]
    measurement_path, measurement_sha = docs["measurement"]
    review_path, _ = docs["owner_review"]

    _schema_validate(
        adk,
        "schemas/effect-trials-v1.schema.json",
        campaign_path,
        "effect trial campaign",
    )
    _schema_validate(
        adk,
        "schemas/effect-trial-comparison-v1.schema.json",
        comparison_path,
        "effect trial comparison",
    )
    _schema_validate(
        adk,
        "schemas/asset-value-measurement-v1.schema.json",
        measurement_path,
        "Agent Value measurement",
    )
    campaign = _load_object(campaign_path, "effect trial campaign")
    comparison = _load_object(comparison_path, "effect trial comparison")
    measurement = _load_object(measurement_path, "Agent Value measurement")
    review = _load_object(review_path, "effect owner review")

    recomputed = _recompute_effect_comparison(adk, campaign_path)
    if recomputed != comparison:
        raise ValueError("effect comparison differs from pinned ADK campaign recomputation")
    campaign_trace_refs, campaign_bundles, campaign_runtime_target = _campaign_bindings(campaign)

    if comparison.get("verdict") not in _DECISIVE_VERDICTS:
        raise ValueError("effect comparison must have a decisive verdict")
    if (
        comparison.get("evidence_scope") != "test-only"
        or comparison.get("quality_evidence_eligible") is not False
        or comparison.get("owner_review_required") is not True
        or comparison.get("lifecycle_authority") != "none-evidence-only"
        or comparison.get("release_authorized") is not False
    ):
        raise ValueError("effect comparison authority boundary is invalid")
    campaign_id = comparison.get("campaign_id")
    if not isinstance(campaign_id, str) or campaign_id != entry_id:
        raise ValueError("effect comparison campaign id must equal evidence entry id")
    plan = campaign.get("plan")
    if not isinstance(plan, dict) or plan.get("campaign_id") != campaign_id:
        raise ValueError("effect trial campaign id must equal comparison/index id")
    if len(campaign_trace_refs) != comparison.get("run_count"):
        raise ValueError("effect trial campaign trace population differs from comparison run count")

    if measurement.get("measurement_status") != "measured":
        raise ValueError("Agent Value measurement is not measured")
    if measurement.get("manifest_ref") != manifest_ref:
        raise ValueError("Agent Value measurement is stale for current ADK manifest")
    if measurement.get("evidence_scope") not in {"runtime-verified", "field-verified", "mixed"}:
        raise ValueError("Agent Value measurement lacks runtime/field evidence")
    if (
        measurement.get("quality_evidence_eligible") is not False
        or measurement.get("owner_review_required") is not True
        or measurement.get("lifecycle_authority") != "none-evidence-only"
        or not isinstance(measurement.get("source_receipt_count"), int)
        or measurement["source_receipt_count"] < 1
    ):
        raise ValueError("Agent Value measurement authority boundary is invalid")

    assets: set[tuple[str, str]] = set()
    measurement_trace_refs: set[str] = set()
    measurement_bundles: set[str] = set()
    measurement_runtime_targets: set[str] = set()
    for item in measurement.get("asset_measurements", []):
        if not isinstance(item, dict):
            raise ValueError("Agent Value asset measurement is invalid")
        pair = (item.get("asset_kind"), item.get("asset_id"))
        if not all(isinstance(value, str) and value for value in pair):
            raise ValueError("Agent Value asset identity is invalid")
        if pair in assets:
            raise ValueError("Agent Value measurement has duplicate asset")
        assets.add(pair)
        if item.get("evidence_layer") not in {"runtime", "field"}:
            raise ValueError("asset measurement contains test-only evidence")
        if item.get("source_verification") != "managed-authority-verified":
            raise ValueError("asset measurement lacks managed authority verification")
        if not item.get("authority_ids"):
            raise ValueError("asset measurement lacks authority id")
        source_trace_refs = item.get("source_trace_refs")
        bundle_sha256s = item.get("asset_bundle_sha256s")
        runtime_targets = item.get("runtime_targets")
        if (
            not isinstance(source_trace_refs, list)
            or not source_trace_refs
            or not all(isinstance(value, str) for value in source_trace_refs)
        ):
            raise ValueError("asset measurement lacks source trace refs")
        if (
            not isinstance(bundle_sha256s, list)
            or not bundle_sha256s
            or not all(isinstance(value, str) for value in bundle_sha256s)
        ):
            raise ValueError("asset measurement lacks bundle identities")
        if (
            not isinstance(runtime_targets, list)
            or not runtime_targets
            or not all(isinstance(value, str) for value in runtime_targets)
        ):
            raise ValueError("asset measurement lacks runtime targets")
        measurement_trace_refs.update(source_trace_refs)
        measurement_bundles.update(bundle_sha256s)
        measurement_runtime_targets.update(runtime_targets)
        metrics = item.get("metrics")
        if not isinstance(metrics, dict):
            raise ValueError("asset measurement metrics are missing")
        for metric in ("task-success-rate", "wrong-route-rate", "abstain-precision"):
            value = metrics.get(metric)
            if not isinstance(value, dict) or value.get("status") != "measured":
                raise ValueError(f"asset measurement requires measured {metric}")
        signals = item.get("retirement_signals")
        if (
            not isinstance(signals, list)
            or not set(signals)
            & {"retain", "consolidate-candidate", "retire-candidate"}
        ):
            raise ValueError("asset measurement lacks a substantive retirement signal")
    if not assets:
        raise ValueError("Agent Value measurement covers no assets")
    missing_managed_traces = campaign_trace_refs - measurement_trace_refs
    if missing_managed_traces:
        raise ValueError(
            "effect trial campaign contains traces without managed runtime/field measurement evidence"
        )
    if campaign_bundles - measurement_bundles:
        raise ValueError("effect trial campaign bundles are not measurement-backed")
    if campaign_runtime_target not in measurement_runtime_targets:
        raise ValueError("effect trial campaign runtime target is not measurement-backed")

    decisions = _validate_owner_review(
        review,
        campaign_id=campaign_id,
        campaign_sha256=campaign_sha,
        comparison_sha256=comparison_sha,
        measurement_sha256=measurement_sha,
        measurement_assets=assets,
    )
    return assets, decisions, {
        "id": entry_id,
        "comparison_verdict": comparison["verdict"],
        "measurement_evidence_scope": measurement["evidence_scope"],
        "campaign_trace_count": len(campaign_trace_refs),
        "managed_campaign_trace_coverage": True,
        "reviewed_by": review["reviewed_by"],
        "asset_count": len(assets),
        "reviewed_at": review["reviewed_at"],
    }


def _evaluate_evidence_index(
    root: Path,
    adk: Path,
    index_path: Path,
    manifest_ref: str,
) -> dict[str, Any]:
    index = _load_object(index_path, "effect evidence index")
    if set(index) != {"schema", "status", "entries"}:
        raise ValueError("effect evidence index fields are invalid")
    if index["schema"] != INDEX_SCHEMA or index["status"] != "active":
        raise ValueError("effect evidence index schema/status is invalid")
    entries = index["entries"]
    if not isinstance(entries, list):
        raise ValueError("effect evidence index entries must be a list")
    if len(entries) > 100:
        raise ValueError("effect evidence index exceeds entry budget")
    expected = _expected_assets(adk)
    evidence_root = index_path.parent.resolve()
    covered: set[tuple[str, str]] = set()
    decisions: dict[tuple[str, str], str] = {}
    summaries: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("effect evidence index entry must be an object")
        entry_id = entry.get("id")
        if not isinstance(entry_id, str) or not entry_id:
            raise ValueError("effect evidence index entry id is invalid")
        if entry_id in seen_ids:
            raise ValueError("effect evidence index has duplicate campaign id")
        seen_ids.add(entry_id)
        assets, entry_decisions, summary = _validate_evidence_entry(
            root, adk, evidence_root, entry, manifest_ref
        )
        extra = assets - expected
        if extra:
            raise ValueError(f"effect evidence references unknown assets: {sorted(extra)}")
        covered.update(assets)
        for pair, decision in entry_decisions.items():
            previous = decisions.get(pair)
            if previous is not None and previous != decision:
                raise ValueError(f"conflicting owner decisions for asset {pair}")
            decisions[pair] = decision
        summaries.append(summary)

    missing = expected - covered
    return {
        "entry_count": len(entries),
        "entries": summaries,
        "expected_asset_count": len(expected),
        "covered_asset_count": len(covered),
        "missing_assets": [
            {"asset_kind": kind, "asset_id": asset_id}
            for kind, asset_id in sorted(missing)
        ],
        "owner_decision_count": len(decisions),
        "full_asset_coverage": bool(entries) and not missing,
        "ready": bool(entries) and not missing and len(decisions) == len(expected),
    }


def project(root: Path, evidence_index: Path = DEFAULT_INDEX) -> dict[str, Any]:
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

    index_path = evidence_index
    if not index_path.is_absolute():
        index_path = root / index_path
    index_path = index_path.resolve()
    if not index_path.is_relative_to(root):
        raise ValueError("effect evidence index escapes Root")
    evidence = _evaluate_evidence_index(
        root, adk, index_path, value["manifest_ref"]
    )

    effect_evidence_ready = software_ready and evidence["ready"]
    blockers: list[str] = []
    if not software_ready:
        blockers.append("effect-software-foundation-incomplete")
    if evidence["entry_count"] == 0:
        blockers.extend(
            [
                "external-evidence-required:governed-effect-evidence-index-entry",
                "external-evidence-required:real-repeated-task-trials",
                "external-evidence-required:sanitized-runtime-or-field-invocation-measurements",
                "external-evidence-required:representative-owner-review",
            ]
        )
    elif not evidence["full_asset_coverage"]:
        blockers.append(
            "external-evidence-required:asset-coverage:"
            f"{evidence['covered_asset_count']}/{evidence['expected_asset_count']}"
        )

    terminal_status = (
        "blocked-software"
        if not software_ready
        else "ready"
        if effect_evidence_ready
        else "blocked-external-evidence"
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
        "safe_defaults": {
            "canonical_contract_policy_status": policy["status"],
            "canonical_contract_backend": policy["backend"],
            "canonical_contract_authority_count": policy["authority_count"],
            "registry_status": trust_registry["status"],
            "registry_authority_count": trust_registry["authority_count"],
            "registry_enabled_authority_count": trust_registry["enabled_authority_count"],
            "note": "safe defaults are not terminal blockers once governed evidence artifacts exist",
        },
        "measurement_baseline": empty_measurement,
        "evidence_index": {
            "path": index_path.relative_to(root).as_posix(),
            **evidence,
        },
        "effect_evidence_ready": effect_evidence_ready,
        "blockers": blockers,
        "authority_boundary": {
            "synthetic_trials_are_real_effect_evidence": False,
            "test_receipts_are_runtime_or_field_evidence": False,
            "software_ready_is_effectiveness_proof": False,
            "retirement_signal_is_lifecycle_authority": False,
            "owner_review_executes_retirement": False,
            "ready_authorizes_release": False,
        },
        "adk_identity": interface["identity"],
        "release_authorized": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Project Agent/Skill/Profile effect/value readiness"
    )
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--evidence-index",
        default=DEFAULT_INDEX.as_posix(),
        help="Root-relative governed effect/value evidence index",
    )
    parser.add_argument("--require-evidence", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = project(Path(args.root), Path(args.evidence_index))
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
