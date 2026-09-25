from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from .adk_interface import validate as validate_adk_interface

SCHEMA = "llm-agent-effect-readiness/v1"
_REQUIRED_CONTRACT_IDS = {"agent-value", "effect-trials", "effect-trial-comparison"}


def _load_object(path: Path, label: str) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def _canonical_agent_value_projection(adk: Path) -> dict[str, Any]:
    code = r'''
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

    blockers: list[str] = []
    if not software_ready:
        blockers.append("effect-software-foundation-incomplete")
    if policy["status"] != "enabled":
        blockers.append("external-evidence-required:owner-reviewed-agent-value-authority")
    if trust_registry["enabled_authority_count"] == 0:
        blockers.append("external-evidence-required:enabled-agent-value-trust-registry-authority")
    blockers.extend(
        [
            "external-evidence-required:real-repeated-task-trials",
            "external-evidence-required:sanitized-runtime-or-field-invocation-receipts",
            "external-evidence-required:representative-success-failure-wrong-route-abstain-outcome-retirement-signals",
            "external-evidence-required:owner-review",
        ]
    )

    effect_evidence_ready = False
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
        },
        "measurement_baseline": empty_measurement,
        "effect_evidence_ready": effect_evidence_ready,
        "blockers": blockers,
        "authority_boundary": {
            "synthetic_trials_are_real_effect_evidence": False,
            "test_receipts_are_runtime_or_field_evidence": False,
            "software_ready_is_effectiveness_proof": False,
            "retirement_signal_is_lifecycle_authority": False,
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
