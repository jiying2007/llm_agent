from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from .adk_interface import validate as validate_adk_interface

SCHEMA = "llm-agent-native-target-readiness/v1"
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _load_object(path: Path, label: str) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def _software_surfaces(adk: Path) -> dict[str, bool]:
    return {
        "source_layout_probe": (adk / "src/agent_dev_kit/target_source_probe.py").is_file(),
        "managed_trust": (
            (adk / "src/agent_dev_kit/native_trust.py").is_file()
            and (adk / "manifests/native_conformance_trust_registry.json").is_file()
        ),
        "native_campaign": all(
            (adk / relative).is_file()
            for relative in (
                "src/agent_dev_kit/native_campaign.py",
                "src/agent_dev_kit/native_campaign_contract.py",
                "src/agent_dev_kit/native_campaign_execution.py",
                "schemas/native-target-campaign-plan-v2.schema.json",
                "schemas/native-target-campaign-evidence-v2.schema.json",
                "schemas/native-target-conformance-receipt-v2.schema.json",
            )
        ),
    }


def _production_loader_accepts(adk: Path, target: str) -> bool:
    code = (
        "import sys;"
        "from pathlib import Path;"
        "from agent_dev_kit.model import Manifest;"
        "from agent_dev_kit.target_contracts import load_target_contract;"
        "root=Path(sys.argv[1]).resolve();"
        "contract=load_target_contract(Manifest.load(root),sys.argv[2]);"
        "assert contract.adapter['conformance']['level']=='runtime'"
    )
    env = {
        "PATH": os.environ.get("PATH", os.defpath),
        "PYTHONPATH": str(adk / "src"),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }
    for key in ("HOME", "XDG_CACHE_HOME", "SSL_CERT_FILE", "SSL_CERT_DIR"):
        value = os.environ.get(key)
        if value:
            env[key] = value
    try:
        completed = subprocess.run(
            [sys.executable, "-c", code, str(adk), target],
            cwd=adk,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=45,
        )
    except subprocess.TimeoutExpired:
        return False
    return completed.returncode == 0


def _target_projection(
    root: Path,
    adk: Path,
    target: str,
    record: dict[str, Any],
    registry: dict[str, Any],
) -> dict[str, Any]:
    contract_rel = record.get("contract")
    if not isinstance(contract_rel, str) or not contract_rel:
        raise ValueError(f"direct target {target} has no contract path")
    contract_path = (adk / contract_rel).resolve()
    if not contract_path.is_relative_to(adk.resolve()) or not contract_path.is_file():
        raise ValueError(f"direct target {target} contract is missing or escapes ADK root")
    contract = _load_object(contract_path, f"target contract {target}")
    if contract.get("target") != target:
        raise ValueError(f"target contract identity mismatch: {target}")
    adapter = contract.get("adapter")
    if not isinstance(adapter, dict):
        raise ValueError(f"target contract adapter missing: {target}")
    conformance = adapter.get("conformance")
    trust = adapter.get("conformance_trust_policy")
    if not isinstance(conformance, dict) or not isinstance(trust, dict):
        raise ValueError(f"target conformance/trust policy missing: {target}")

    level = conformance.get("level")
    certification = conformance.get("certification")
    smoke = conformance.get("native_runtime_smoke")
    runtime_version = conformance.get("runtime_version")
    runtime_pin = conformance.get("runtime_version_pin")
    runtime_digest = conformance.get("runtime_binary_sha256")
    evidence = conformance.get("evidence")
    trusted_authorities = trust.get("trusted_authorities")
    trust_enabled = trust.get("enabled") is True

    registry_authorities = registry.get("authorities")
    if not isinstance(registry_authorities, dict):
        raise ValueError("native trust registry authorities must be an object")
    bound_authorities = []
    if isinstance(trusted_authorities, list):
        for authority_id in trusted_authorities:
            authority = registry_authorities.get(authority_id)
            if (
                isinstance(authority_id, str)
                and isinstance(authority, dict)
                and authority.get("enabled") is True
                and target in authority.get("allowed_targets", [])
            ):
                bound_authorities.append(authority_id)

    evidence_paths_valid = True
    evidence_count = 0
    if isinstance(evidence, list):
        evidence_count = len(evidence)
        for item in evidence:
            if not isinstance(item, dict):
                evidence_paths_valid = False
                continue
            path_value = item.get("path")
            if not isinstance(path_value, str) or not path_value:
                evidence_paths_valid = False
                continue
            path = (adk / path_value).resolve()
            if not path.is_relative_to(adk.resolve()) or not path.is_file():
                evidence_paths_valid = False
    else:
        evidence_paths_valid = False

    runtime_identity_pinned = (
        isinstance(runtime_version, str)
        and bool(runtime_version)
        and runtime_version == runtime_pin
        and isinstance(runtime_digest, str)
        and _SHA256_RE.fullmatch(runtime_digest) is not None
    )
    production_loader_verified = (
        _production_loader_accepts(adk, target) if level == "runtime" else False
    )
    native_verified = (
        level == "runtime"
        and certification == "conformance-certified"
        and smoke == "pass"
        and runtime_identity_pinned
        and evidence_count > 0
        and evidence_paths_valid
        and trust_enabled
        and bool(bound_authorities)
        and production_loader_verified
    )

    return {
        "contract": contract_rel,
        "contract_status": contract.get("status"),
        "conformance_level": level,
        "certification": certification,
        "native_runtime_smoke": smoke,
        "runtime_identity_pinned": runtime_identity_pinned,
        "evidence_count": evidence_count,
        "evidence_paths_valid": evidence_paths_valid,
        "trust_enabled": trust_enabled,
        "bound_registry_authorities": sorted(bound_authorities),
        "production_loader_verified": production_loader_verified,
        "native_verified": native_verified,
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
            "native_verified": False,
            "failures": list(interface.get("failures", [])),
            "blockers": [],
            "release_authorized": False,
        }

    adk = (root / "agent-dev-kit").resolve()
    manifest = _load_object(adk / "manifest.json", "ADK manifest")
    registry = _load_object(
        adk / "manifests/native_conformance_trust_registry.json",
        "native trust registry",
    )
    if registry.get("schema") != "adk-native-conformance-trust-registry/v1":
        raise ValueError("unsupported native trust registry schema")
    tool_targets = manifest.get("tool_targets")
    if not isinstance(tool_targets, dict) or not tool_targets:
        raise ValueError("ADK manifest has no direct tool targets")

    surfaces = _software_surfaces(adk)
    software_ready = all(surfaces.values())
    targets = {
        name: _target_projection(root, adk, name, record, registry)
        for name, record in sorted(tool_targets.items())
        if isinstance(record, dict)
    }
    if set(targets) != set(tool_targets):
        raise ValueError("one or more direct target records are invalid")

    native_verified_targets = sorted(
        name for name, value in targets.items() if value["native_verified"]
    )
    blockers: list[str] = []
    for name, present in surfaces.items():
        if not present:
            blockers.append(f"software-surface-missing:{name}")
    if software_ready and not native_verified_targets:
        blockers.append(
            "external-evidence-required:version-pinned-authenticated-native-campaign"
        )
        blockers.append(
            "external-evidence-required:signed-receipt-managed-registry-production-loader"
        )

    terminal_status = (
        "ready"
        if software_ready and bool(native_verified_targets)
        else "blocked-external-evidence"
        if software_ready
        else "blocked-software"
    )
    return {
        "schema": SCHEMA,
        "status": "pass",
        "terminal_status": terminal_status,
        "software_ready": software_ready,
        "software_surfaces": surfaces,
        "native_verified": bool(native_verified_targets),
        "native_verified_targets": native_verified_targets,
        "targets": targets,
        "blockers": blockers,
        "adk_identity": interface["identity"],
        "authority_boundary": {
            "source_layout_is_native_evidence": False,
            "synthetic_campaign_is_native_evidence": False,
            "exit_zero_without_semantic_assertion_is_native_evidence": False,
            "managed_trust_without_receipt_is_native_evidence": False,
            "requires_real_version_pinned_native_pass": True,
            "requires_semantic_assertion_v2": True,
        },
        "release_authorized": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Project direct-target native conformance software/readiness state"
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--require-native", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = project(Path(args.root))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        result = {
            "schema": SCHEMA,
            "status": "fail",
            "terminal_status": "invalid-source",
            "software_ready": False,
            "native_verified": False,
            "failures": [str(exc)],
            "blockers": [],
            "release_authorized": False,
        }

    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))

    if result["status"] != "pass":
        return 1
    if args.require_native and result["terminal_status"] != "ready":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
