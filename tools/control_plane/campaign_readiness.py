"""Read-only projection of remaining optimization campaign readiness.

This module creates no new authority. It composes existing Root source/product
status with capabilities and native-conformance state from the exact ADK
worktree when available.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

from .status_projection import project as project_status

SCHEMA = "llm-agent-campaign-readiness/v1"
GATES = ("software",)
MAX_JSON_BYTES = 4 * 1024 * 1024

_EFFECT_REQUIRED = (
    "schemas/effect-trials-v1.schema.json",
    "schemas/effect-trial-comparison-v1.schema.json",
    "src/agent_dev_kit/effect_trials.py",
    "docs/runbooks/effect-trials.md",
)
_NATIVE_REQUIRED = (
    "manifests/native_conformance_trust_registry.json",
    "schemas/native-target-conformance-receipt-v1.schema.json",
    "src/agent_dev_kit/native_trust.py",
    "docs/runbooks/native-conformance-trust.md",
)


class ReadinessError(RuntimeError):
    pass


def _kv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if path.is_symlink() or not path.is_file():
        raise ReadinessError(f"missing or unsafe key/value source: {path.name}")
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ReadinessError(f"invalid key/value line in {path.name}")
        key, value = line.split("=", 1)
        if key in values:
            raise ReadinessError(f"duplicate key in {path.name}: {key}")
        values[key] = value
    return values


def _json(path: Path, label: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise ReadinessError(f"{label} is missing or unsafe")
    if path.stat().st_size > MAX_JSON_BYTES:
        raise ReadinessError(f"{label} exceeds byte budget")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReadinessError(f"{label} is invalid JSON") from exc
    if not isinstance(value, dict):
        raise ReadinessError(f"{label} must be an object")
    return value


def _git_state(repository: Path) -> tuple[str, int]:
    head = subprocess.run(
        ["git", "-C", str(repository), "rev-parse", "HEAD"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
    )
    if head.returncode:
        raise ReadinessError("unable to resolve ADK worktree HEAD")
    status = subprocess.run(
        [
            "git", "-C", str(repository), "status", "--porcelain=v1", "-z",
            "--untracked-files=all", "--no-renames",
        ],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        check=False,
        timeout=10,
    )
    if status.returncode:
        raise ReadinessError("unable to inspect ADK worktree status")
    dirty_count = sum(bool(item) for item in status.stdout.split("\0"))
    return head.stdout.strip(), dirty_count


def _within(root: Path, raw: str, label: str) -> Path:
    candidate = (root / raw).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError as exc:
        raise ReadinessError(f"{label} escapes ADK worktree") from exc
    return candidate


def _required_files(root: Path, names: tuple[str, ...]) -> dict[str, Any]:
    missing = [name for name in names if not (root / name).is_file()]
    return {
        "status": "ready" if not missing else "blocked",
        "required": list(names),
        "missing": missing,
    }


def _adk_projection(root: Path, lock: dict[str, str], require_worktree: bool) -> dict[str, Any]:
    adk = root / "agent-dev-kit"
    if adk.is_symlink():
        raise ReadinessError("ADK worktree must not be a symlink")
    manifest_path = adk / "manifest.json"
    if not manifest_path.is_file():
        if require_worktree:
            raise ReadinessError("ADK worktree is required but not initialized")
        return {
            "worktree_status": "unavailable",
            "identity_status": "not-checked",
            "effect_software": {"status": "unknown", "required": list(_EFFECT_REQUIRED), "missing": []},
            "native_software": {"status": "unknown", "required": list(_NATIVE_REQUIRED), "missing": []},
            "native_registry": {"status": "unknown", "authority_count": None, "enabled_authority_count": None},
            "targets": {},
        }

    manifest = _json(manifest_path, "ADK manifest")
    head, dirty_count = _git_state(adk)
    expected_version = lock.get("agent-dev-kit.version")
    expected_commit = lock.get("agent-dev-kit.commit")
    version = manifest.get("version")
    identity_ready = version == expected_version and head == expected_commit and dirty_count == 0
    effect = _required_files(adk, _EFFECT_REQUIRED)
    native = _required_files(adk, _NATIVE_REQUIRED)

    registry: dict[str, Any] = {
        "status": "blocked",
        "authority_count": 0,
        "enabled_authority_count": 0,
    }
    registry_path = adk / "manifests" / "native_conformance_trust_registry.json"
    if registry_path.is_file():
        value = _json(registry_path, "native trust registry")
        if value.get("schema") != "adk-native-conformance-trust-registry/v1":
            raise ReadinessError("native trust registry schema mismatch")
        authorities = value.get("authorities")
        if not isinstance(authorities, dict):
            raise ReadinessError("native trust registry authorities must be an object")
        enabled = sum(
            item.get("enabled") is True for item in authorities.values() if isinstance(item, dict)
        )
        registry = {
            "status": "ready" if enabled else "no-enabled-authority",
            "authority_count": len(authorities),
            "enabled_authority_count": enabled,
        }

    targets: dict[str, Any] = {}
    raw_targets = manifest.get("tool_targets")
    if not isinstance(raw_targets, dict):
        raise ReadinessError("ADK manifest tool_targets is invalid")
    for target, config in sorted(raw_targets.items()):
        if not isinstance(config, dict) or not isinstance(config.get("contract"), str):
            raise ReadinessError(f"ADK target contract reference is invalid: {target}")
        contract_path = _within(adk, config["contract"], f"target contract {target}")
        contract = _json(contract_path, f"target contract {target}")
        adapter = contract.get("adapter")
        if not isinstance(adapter, dict):
            raise ReadinessError(f"target adapter is invalid: {target}")
        conformance = adapter.get("conformance")
        trust = adapter.get("conformance_trust_policy")
        if not isinstance(conformance, dict) or not isinstance(trust, dict):
            raise ReadinessError(f"target conformance/trust policy is invalid: {target}")
        targets[target] = {
            "contract_status": contract.get("status"),
            "conformance_level": conformance.get("level"),
            "certification": conformance.get("certification"),
            "native_runtime_smoke": conformance.get("native_runtime_smoke"),
            "trust_enabled": trust.get("enabled") is True,
            "verification_backend": trust.get("verification_backend"),
        }

    return {
        "worktree_status": "available",
        "identity_status": "ready" if identity_ready else "blocked",
        "version": version,
        "commit": head,
        "dirty_count": dirty_count,
        "effect_software": effect,
        "native_software": native,
        "native_registry": registry,
        "targets": targets,
    }


def project_campaign_readiness(root: Path, *, require_adk_worktree: bool = False) -> dict[str, Any]:
    root = root.resolve()
    lock = _kv(root / "adk.lock")
    adk = _adk_projection(root, lock, require_adk_worktree)
    status = project_status(root, dt.date.today())
    if status.get("status") != "pass":
        raise ReadinessError("current status projection is not valid")

    identity_ready = adk["identity_status"] == "ready"
    effect_software_ready = identity_ready and adk["effect_software"]["status"] == "ready"
    native_software_ready = identity_ready and adk["native_software"]["status"] == "ready"

    runtime_targets = [
        name
        for name, item in adk["targets"].items()
        if item["conformance_level"] == "runtime"
        and item["certification"] == "conformance-certified"
        and item["native_runtime_smoke"] == "pass"
    ]
    enabled_authorities = adk["native_registry"]["enabled_authority_count"]
    native_external_blockers: list[str] = []
    if enabled_authorities is None:
        native_external_blockers.append("native-authority-state-unknown")
    elif enabled_authorities == 0:
        native_external_blockers.append("no-enabled-native-authority")
    if not runtime_targets:
        native_external_blockers.append("no-native-certified-target")

    effect = {
        "backlog_item": "G22",
        "software_status": "ready" if effect_software_ready else "blocked",
        "evidence_status": "external-input-required",
        "campaign_status": "ready-for-real-execution" if effect_software_ready else "blocked",
        "blockers": [] if effect_software_ready else ["effect-trial-software-unavailable"],
        "external_evidence_required": [
            "real-task-trial-campaign",
            "fixed-runtime-model-controls",
            "complete-success-and-failure-results",
            "owner-review",
        ],
        "next_command": (
            "agent-dev-kit/scripts/devkit.sh eval compare-trials "
            "--input <campaign.json> --output <comparison.json> --summary-json"
        ),
        "lifecycle_authority": "none-evidence-only",
    }
    native_lane = {
        "backlog_item": "G21",
        "software_status": "ready" if native_software_ready else "blocked",
        "evidence_status": "external-input-required" if not runtime_targets else "repository-evidence-present",
        "promotion_status": "blocked" if native_external_blockers else "evidence-present-owner-review-required",
        "blockers": (
            ([] if native_software_ready else ["native-trust-software-unavailable"])
            + native_external_blockers
        ),
        "runtime_certified_targets": runtime_targets,
        "enabled_authorities": enabled_authorities,
        "external_evidence_required": [
            "version-pinned-native-runtime",
            "independent-discovery-load-trigger",
            "signed-native-receipt",
            "owner-reviewed-authority-binding",
        ],
        "lifecycle_authority": "none-evidence-only",
    }

    software_ready = effect_software_ready and native_software_ready
    evidence_ready = (
        effect["evidence_status"] != "external-input-required"
        and native_lane["evidence_status"] != "external-input-required"
    )
    return {
        "schema": SCHEMA,
        "status": "pass",
        "projection_semantics": "read-only-composition-not-a-new-authority",
        "source": {
            "adk_version": lock.get("agent-dev-kit.version"),
            "adk_commit": lock.get("agent-dev-kit.commit"),
            "adk_worktree": adk,
        },
        "software_status": "ready" if software_ready else "blocked",
        "evidence_closure_status": "ready" if evidence_ready else "external-input-required",
        "campaigns": {
            "effect": effect,
            "native": native_lane,
        },
        "product_authority": {
            "current_evidence_state": status["current_evidence_state"],
            "release_authorized": status["release_authorized"],
            "relation": "independent-from-campaign-software-readiness",
        },
        "boundaries": {
            "writes": False,
            "network": False,
            "credentials_read": False,
            "raw_runtime_content_read": False,
            "software_ready_is_not_effectiveness_proof": True,
            "campaign_evidence_does_not_auto_authorize_release": True,
        },
    }


def _gate_ok(result: dict[str, Any], gate: str) -> bool:
    if gate == "software":
        return result["software_status"] == "ready"
    raise ReadinessError(f"unknown gate: {gate}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Project effect/native campaign readiness without changing authority")
    parser.add_argument("--root", default=".")
    parser.add_argument("--require-adk-worktree", action="store_true")
    parser.add_argument("--gate", choices=GATES)
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = project_campaign_readiness(
            Path(args.root),
            require_adk_worktree=args.require_adk_worktree,
        )
    except (OSError, ValueError, ReadinessError) as exc:
        result = {"schema": SCHEMA, "status": "fail", "error": str(exc)}
        if args.summary_json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    gate_ok = True if args.gate is None else _gate_ok(result, args.gate)
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if gate_ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
