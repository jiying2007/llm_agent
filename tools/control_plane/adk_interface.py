from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping

INTERFACE_SCHEMA = "llm-agent-adk-interface-lock/v1"
LOCK_SCHEMA = "llm-agent-adk-lock/v2"

_SURFACES = {
    "manifest": "manifest.json",
    "maturity_test": "tests/test_product_maturity.sh",
    "target_contract_schema": "manifests/target-contract.schema.json",
    "evidence_graph_schema": "schemas/evidence-graph-v1.schema.json",
    "runtime_control_schema": "schemas/runtime-control-decision-v2.schema.json",
}
_DEPRECATED = [
    "manifest.yaml",
    "tests/test_product_maturity_v4.sh",
    "tests/test_product_maturity_v5.sh",
    "tests/test_runtime_control.sh",
    "tests/test_runtime_control.py",
    "src/agent_dev_kit/runtime_control",
]


def _read_lock(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        values[key] = value
    if values.get("schema") != LOCK_SCHEMA:
        raise ValueError("unsupported adk.lock schema")
    return values


def _gitlink(root: Path) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-s", "agent-dev-kit"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise ValueError(completed.stderr.strip() or "unable to resolve ADK gitlink")
    fields = completed.stdout.split()
    if len(fields) < 2 or fields[0] != "160000":
        raise ValueError("agent-dev-kit is not a tracked gitlink")
    return fields[1]


def interface_payload(identity: Mapping[str, str], updated_at: str) -> dict[str, Any]:
    required = ("version", "commit", "tree", "manifest_blob")
    missing = [key for key in required if not identity.get(key)]
    if missing:
        raise ValueError("missing ADK interface identity fields: " + ", ".join(missing))
    return {
        "schema": INTERFACE_SCHEMA,
        "version": identity["version"],
        "commit": identity["commit"],
        "tree": identity["tree"],
        "manifest_blob": identity["manifest_blob"],
        "manifest_mode": "json-only",
        "maturity_contract": "v5",
        "surfaces": dict(_SURFACES),
        "deprecated_surfaces": list(_DEPRECATED),
        "updated_at": updated_at,
    }


def render_interface_lock(identity: Mapping[str, str], updated_at: str) -> str:
    return json.dumps(interface_payload(identity, updated_at), ensure_ascii=False, indent=2) + "\n"


def _validate_pinned_worktree(root: Path, expected: Mapping[str, str | None]) -> list[str]:
    worktree = root / "agent-dev-kit"
    failures: list[str] = []
    if not (worktree / "manifest.json").is_file():
        return ["pinned ADK worktree is not initialized"]

    completed = subprocess.run(
        ["git", "-C", str(worktree), "rev-parse", "HEAD"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        return [completed.stderr.strip() or "unable to resolve pinned ADK worktree HEAD"]
    head = completed.stdout.strip()
    if expected.get("commit") and head != expected["commit"]:
        failures.append("pinned ADK worktree HEAD does not match interface/lock commit")

    for label, relative in _SURFACES.items():
        if not (worktree / relative).is_file():
            failures.append(f"pinned ADK worktree missing supported surface {label}: {relative}")
    for relative in _DEPRECATED:
        if (worktree / relative).exists():
            failures.append(f"pinned ADK worktree contains retired surface: {relative}")
    return failures


def validate(root: Path, *, require_worktree: bool = False) -> dict[str, Any]:
    root = root.resolve()
    lock = _read_lock(root / "adk.lock")
    interface = json.loads((root / "manifests" / "adk_interface.lock.json").read_text(encoding="utf-8"))
    failures: list[str] = []

    if interface.get("schema") != INTERFACE_SCHEMA:
        failures.append("unsupported interface lock schema")

    expected = {
        "version": lock.get("agent-dev-kit.version"),
        "commit": lock.get("agent-dev-kit.commit"),
        "tree": lock.get("agent-dev-kit.tree"),
        "manifest_blob": lock.get("agent-dev-kit.manifest_blob"),
    }
    for key, value in expected.items():
        if not value:
            failures.append(f"adk.lock missing {key}")
        elif interface.get(key) != value:
            failures.append(f"interface {key} does not match adk.lock")

    if expected.get("commit") and _gitlink(root) != expected["commit"]:
        failures.append("ADK gitlink does not match interface/lock commit")
    if interface.get("manifest_mode") != "json-only":
        failures.append("ADK interface must declare json-only manifest mode")
    if interface.get("maturity_contract") != "v5":
        failures.append("ADK interface must declare v5 maturity contract")
    if interface.get("surfaces") != _SURFACES:
        failures.append("ADK interface surfaces drifted from the supported v5 contract")
    if interface.get("deprecated_surfaces") != _DEPRECATED:
        failures.append("ADK deprecated-surface contract drifted")
    if require_worktree:
        failures.extend(_validate_pinned_worktree(root, expected))

    return {
        "schema": INTERFACE_SCHEMA,
        "status": "pass" if not failures else "fail",
        "identity": expected,
        "gitlink": _gitlink(root),
        "surfaces": dict(_SURFACES),
        "deprecated_surfaces": list(_DEPRECATED),
        "worktree_checked": require_worktree,
        "failures": failures,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate the pinned ADK cross-repository interface lock")
    parser.add_argument("--root", default=".")
    parser.add_argument("--require-worktree", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = validate(Path(args.root), require_worktree=args.require_worktree)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        result = {"schema": INTERFACE_SCHEMA, "status": "fail", "failures": [str(exc)]}
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        if result["status"] == "pass":
            print("[PASS] ADK interface lock matches gitlink, adk.lock and required source surfaces")
        else:
            for failure in result.get("failures", []):
                print(f"[FAIL] {failure}", file=sys.stderr)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
