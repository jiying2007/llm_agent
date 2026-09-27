from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

PACKAGE_SCHEMA = "llm-agent-effect-preregistration-package/v2"
BUNDLE_SCHEMA = "llm-agent-effect-bundle-manifest/v1"
_CONTROL_BINDINGS = {
    "environment": "environment_ref",
    "tool_policy": "tool_policy_ref",
    "grader": "grader_ref",
    "dataset": "dataset_ref",
    "parameters": "parameters_ref",
    "provider": "provider_ref",
}


def _canonical(value: Any) -> bytes:
    from agent_dev_kit.model import canonical_json_bytes

    return canonical_json_bytes(value)


def _ref(value: Any) -> str:
    return "ref:" + hashlib.sha256(_canonical(value)).hexdigest()


def _expected_assets(manifest: Any) -> set[tuple[str, str]]:
    result: set[tuple[str, str]] = set()
    data = manifest.data
    for key, kind in (("agents", "agent"), ("skills", "skill"), ("optional_skills", "skill")):
        for item in data.get(key, []):
            if isinstance(item, dict) and isinstance(item.get("name"), str):
                result.add((kind, item["name"]))
    profiles = data.get("profiles", {})
    if isinstance(profiles, dict):
        result.update(("profile", str(name)) for name in profiles)
    return result


def validate_package(adk: Path, package_path: Path) -> tuple[bytes, dict[str, Any]]:
    from agent_dev_kit.model import Manifest
    from agent_dev_kit.privacy_ref import validate_no_secrets

    if package_path.is_symlink() or not package_path.is_file():
        raise ValueError("preregistration package is missing or unsafe")
    if package_path.stat().st_size > 1024 * 1024:
        raise ValueError("preregistration package exceeds byte budget")
    package = json.loads(package_path.read_text(encoding="utf-8"))
    if not isinstance(package, dict):
        raise ValueError("preregistration package must be an object")
    required = {
        "schema",
        "status",
        "plan",
        "controls",
        "bundles",
        "raw_content_stored",
        "provider_execution_performed",
        "release_authorized",
    }
    if set(package) != required:
        raise ValueError("preregistration package fields are invalid")
    if package["schema"] != PACKAGE_SCHEMA or package["status"] != "frozen":
        raise ValueError("preregistration package schema/status is invalid")
    if (
        package["raw_content_stored"] is not False
        or package["provider_execution_performed"] is not False
        or package["release_authorized"] is not False
    ):
        raise ValueError("preregistration package authority/privacy boundary is invalid")
    validate_no_secrets(package, "effect preregistration package")

    plan = package["plan"]
    controls = package["controls"]
    bundles = package["bundles"]
    if not isinstance(plan, dict) or not isinstance(controls, dict) or not isinstance(bundles, dict):
        raise ValueError("preregistration package plan/controls/bundles are invalid")
    if set(controls) != set(_CONTROL_BINDINGS):
        raise ValueError("preregistration package controls are incomplete")
    if set(bundles) != {"baseline", "candidate"}:
        raise ValueError("preregistration package bundles are invalid")

    plan_controls = plan.get("controls")
    plan_bundles = plan.get("bundles")
    if not isinstance(plan_controls, dict) or not isinstance(plan_bundles, dict):
        raise ValueError("preregistration plan controls/bundles are invalid")
    for name, field in _CONTROL_BINDINGS.items():
        value = controls[name]
        if not isinstance(value, dict):
            raise ValueError(f"preregistration control artifact must be an object: {name}")
        if plan_controls.get(field) != _ref(value):
            raise ValueError(f"preregistration control ref mismatch: {field}")

    manifest = Manifest.load(adk)
    known_assets = _expected_assets(manifest)
    runtime_target = plan_controls.get("runtime_target")
    if not isinstance(runtime_target, str) or not runtime_target:
        raise ValueError("preregistration runtime_target is invalid")

    bundle_digests: dict[str, str] = {}
    for side in ("baseline", "candidate"):
        value = bundles[side]
        if not isinstance(value, dict):
            raise ValueError(f"preregistration bundle manifest must be an object: {side}")
        required_bundle = {
            "schema",
            "condition",
            "runtime_target",
            "assets",
            "metadata",
            "raw_content_stored",
            "release_authorized",
        }
        if set(value) != required_bundle:
            raise ValueError(f"preregistration bundle manifest fields are invalid: {side}")
        if (
            value["schema"] != BUNDLE_SCHEMA
            or value["condition"] != side
            or value["runtime_target"] != runtime_target
            or value["raw_content_stored"] is not False
            or value["release_authorized"] is not False
            or not isinstance(value["metadata"], dict)
        ):
            raise ValueError(f"preregistration bundle manifest semantics are invalid: {side}")
        assets = value["assets"]
        if not isinstance(assets, list) or len(assets) > 5000:
            raise ValueError(f"preregistration bundle assets are invalid: {side}")
        seen: set[tuple[str, str]] = set()
        for item in assets:
            if not isinstance(item, dict) or set(item) != {"asset_kind", "asset_id", "content_ref"}:
                raise ValueError(f"preregistration bundle asset record is invalid: {side}")
            pair = (item.get("asset_kind"), item.get("asset_id"))
            content_ref = item.get("content_ref")
            if (
                pair not in known_assets
                or pair in seen
                or not isinstance(content_ref, str)
                or len(content_ref) != 68
                or not content_ref.startswith("ref:")
                or any(ch not in "0123456789abcdef" for ch in content_ref[4:])
            ):
                raise ValueError(f"preregistration bundle asset identity is invalid: {side}")
            seen.add(pair)
        digest = hashlib.sha256(_canonical(value)).hexdigest()
        bundle_digests[side] = digest
        if plan_bundles.get(side) != digest:
            raise ValueError(f"preregistration plan bundle digest mismatch: {side}")
    if bundle_digests["baseline"] == bundle_digests["candidate"]:
        raise ValueError("preregistration bundle manifests must be distinct")

    canonical = _canonical(package)
    return canonical, {
        "schema": PACKAGE_SCHEMA,
        "status": "pass",
        "package_sha256": hashlib.sha256(canonical).hexdigest(),
        "plan_sha256": hashlib.sha256(_canonical(plan)).hexdigest(),
        "control_refs": {field: plan_controls[field] for field in _CONTROL_BINDINGS.values()},
        "bundle_sha256": bundle_digests,
        "runtime_target": runtime_target,
        "provider_execution_performed": False,
        "release_authorized": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate/canonicalize a frozen G22 preregistration package")
    parser.add_argument("--adk", default="agent-dev-kit")
    parser.add_argument("--package", required=True)
    parser.add_argument("--canonical-out")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        canonical, summary = validate_package(Path(args.adk).resolve(), Path(args.package).resolve())
        if args.canonical_out:
            Path(args.canonical_out).write_bytes(canonical)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        result = {"schema": PACKAGE_SCHEMA, "status": "fail", "error": str(exc)}
        print(json.dumps(result, sort_keys=True))
        return 1
    print(json.dumps(summary, sort_keys=True) if args.summary_json else json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
