from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import subprocess
import sys
from collections.abc import Mapping
from datetime import datetime
from pathlib import Path
from typing import Any

from tools.codex_assets.intake_io import IntakeError, read_bytes, read_json

from .evidence_paths import resolve_regular_evidence_path
from .process_budget import run_bounded

INTERFACE_SCHEMA = "llm-agent-adk-interface-lock/v1"
LOCK_SCHEMA = "llm-agent-adk-lock/v2"

_SURFACES = {
    "manifest": "manifest.json",
    "maturity_test": "tests/test_product_maturity.sh",
    "target_contract_schema": "manifests/target-contract.schema.json",
    "evidence_graph_schema": "schemas/evidence-graph-v1.schema.json",
    "runtime_control_schema": "schemas/runtime-control-decision-v2.schema.json",
    "sigstore_blob_verifier": "src/agent_dev_kit/sigstore_blob.py",
    "campaign_model": "src/agent_dev_kit/campaign_model.py",
    "campaign_runtime": "src/agent_dev_kit/campaign.py",
    "evaluation_cli": "src/agent_dev_kit/evaluation_cli.py",
    "effect_campaign_materializer": "src/agent_dev_kit/effect_campaign_materializer.py",
}
_DEPRECATED = [
    "manifest.yaml",
    "tests/test_product_maturity_v4.sh",
    "tests/test_product_maturity_v5.sh",
    "tests/test_runtime_control.sh",
    "tests/test_runtime_control.py",
    "src/agent_dev_kit/runtime_control",
]
_REVIEW_VALIDATOR_SOURCES = (
    "src/agent_dev_kit/review_evidence.py",
    "src/agent_dev_kit/strict_json.py",
    "src/agent_dev_kit/readiness_evidence.py",
)


def _verify_review_authority_pin(authority: Path, paths: list[str]) -> None:
    """Bind policy inputs to the parent Git pin and raw HEAD/index/worktree blobs."""
    def git(directory: Path, *args: str) -> bytes:
        completed = run_bounded(("git", "-C", str(directory), *args), timeout=30,
                                max_stdout=64 * 1024, max_stderr=4096)
        if completed.returncode != 0:
            raise ValueError("cannot inspect pinned ADK review authority Git identity")
        return completed.stdout

    if authority.name != "agent-dev-kit":
        raise ValueError("review authority must be the pinned ADK subrepository")
    head_commit = git(authority, "rev-parse", "--verify", "HEAD").strip()
    pin = git(authority.parent, "ls-files", "--stage", "-z", "--", ":(literal)agent-dev-kit")
    expected_pin = b"160000 " + head_commit + b" 0\tagent-dev-kit\0"
    if pin != expected_pin:
        raise ValueError("ADK review authority HEAD differs from the parent Git pin")
    names = sorted(set(paths))
    pathspecs = [":(literal)" + name for name in names]
    tree = git(authority, "ls-tree", "-r", "-z", "--full-tree", head_commit.decode("ascii"), "--", *pathspecs)
    staged = git(authority, "ls-files", "--stage", "-z", "--", *pathspecs)
    head: dict[str, tuple[bytes, bytes]] = {}
    index: dict[str, tuple[bytes, bytes]] = {}
    for entry in tree.split(b"\0"):
        if not entry:
            continue
        metadata, filename = entry.split(b"\t", 1)
        mode, kind, blob = metadata.split(b" ", 2)
        name = filename.decode("utf-8")
        if kind != b"blob" or mode not in {b"100644", b"100755"} or name in head:
            raise ValueError("pinned ADK review authority is not a unique regular HEAD blob")
        head[name] = (mode, blob)
    for entry in staged.split(b"\0"):
        if not entry:
            continue
        metadata, filename = entry.split(b"\t", 1)
        mode, blob, stage = metadata.split(b" ", 2)
        name = filename.decode("utf-8")
        if stage != b"0" or name in index:
            raise ValueError("pinned ADK review authority index has unresolved or duplicate entries")
        index[name] = (mode, blob)
    if set(head) != set(names) or index != head:
        raise ValueError("ADK review policy, authorization or validator is not committed at the exact pin")
    actual = git(authority, "hash-object", "--no-filters", "--", *names).splitlines()
    if len(actual) != len(names) or any(blob != head[name][1] for name, blob in zip(names, actual, strict=True)):
        raise ValueError("ADK review policy, authorization or validator worktree differs from the exact pin")


def validate_delegated_review(
    root: Path, record_path: Path, *, policy_root: Path,
    expected_subject: str, expected_scope: str, now: datetime | None = None,
) -> dict[str, Any]:
    """Bind the loaded ADK API to the explicit pin, then delegate all semantics.

    A correct worktree lock alone cannot stop an older installed Python package
    from validating its own older receipts. Compare the actual loaded module
    fingerprints with the regular source bytes in the caller's fixed ADK tree.
    This bridge issues no verdict and owns no review policy.
    """
    authority = policy_root.absolute()
    if (".." in authority.parts or not authority.is_dir()
            or any(path.is_symlink() for path in (authority, *authority.parents))):
        raise ValueError("pinned ADK review source root is unsafe or unavailable")
    try:
        review_evidence = importlib.import_module("agent_dev_kit.review_evidence")

        expected = {}
        for relative in _REVIEW_VALIDATOR_SOURCES:
            path = resolve_regular_evidence_path(authority, Path(relative), label="pinned ADK review validator")
            expected[relative] = hashlib.sha256(read_bytes(path, label="pinned ADK review validator",
                                                          max_bytes=16 * 1024 * 1024)).hexdigest()
        if review_evidence.validator_fingerprints() != expected:
            raise ValueError("loaded ADK review validator differs from the pinned source")
        policy_path = resolve_regular_evidence_path(authority, Path(".adk/review-policy.json"), label="pinned ADK review policy")
        policy = read_json(policy_path, label="pinned ADK review policy", max_bytes=16 * 1024)
        authorization = policy.get("authorization") if isinstance(policy, dict) else None
        if not isinstance(authorization, dict) or not isinstance(authorization.get("path"), str):
            raise ValueError("pinned ADK review policy lacks its authorization source")
        authorization_path = resolve_regular_evidence_path(authority, Path(authorization["path"]),
                                                            label="pinned ADK review authorization")
        read_bytes(authorization_path, label="pinned ADK review authorization", max_bytes=16 * 1024)
        authority_paths = [*_REVIEW_VALIDATOR_SOURCES, ".adk/review-policy.json",
                           authorization_path.relative_to(authority).as_posix()]
        _verify_review_authority_pin(authority, authority_paths)
        result: object = review_evidence.validate_review(root, record_path, policy_root=authority,
                                                         expected_subject=expected_subject, expected_scope=expected_scope, now=now)
        if not isinstance(result, dict) or any(not isinstance(key, str) for key in result):
            raise ValueError("pinned ADK review API returned an invalid result object")
        _verify_review_authority_pin(authority, authority_paths)
        return result
    except (ImportError, IntakeError, OSError, RuntimeError) as exc:
        raise ValueError("pinned ADK delegated review validator is unavailable or unsafe") from exc


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
        capture_output=True,
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
        capture_output=True,
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
