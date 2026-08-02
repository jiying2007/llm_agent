"""Build a bounded, read-only provenance bundle across the ADK delivery chain."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile
from typing import Any, Sequence, Union


BUNDLE_SCHEMA_VERSION = 1
MAX_EVIDENCE_FILES = 32
MAX_OUTPUT_BYTES = 32 * 1024


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_output(root: pathlib.Path, *args: str, text: bool = False) -> Union[bytes, str]:
    result = subprocess.run(
        ["rtk", "git", "-C", str(root), *args],
        check=True,
        capture_output=True,
        text=text,
    )
    return result.stdout


def status_entries(status_bytes: bytes, excluded_paths: set[str]) -> list[bytes]:
    rows: list[bytes] = []
    for entry in status_bytes.split(b"\0"):
        if not entry:
            continue
        relative = entry[3:].decode("utf-8", errors="surrogateescape") if len(entry) >= 3 else ""
        if relative in excluded_paths:
            continue
        rows.append(entry)
    return rows


def untracked_paths(entries: list[bytes]) -> list[str]:
    paths: list[str] = []
    for entry in entries:
        if entry.startswith(b"?? "):
            paths.append(entry[3:].decode("utf-8", errors="surrogateescape"))
    return sorted(paths)


def file_identity(path: pathlib.Path) -> str:
    if path.is_symlink():
        return "symlink:" + os.readlink(path)
    if path.is_file():
        return "file:" + sha256_file(path)
    if path.is_dir():
        return "dir"
    return "absent"


def repo_receipt(name: str, root: pathlib.Path, excluded_paths: set[str]) -> dict[str, Any]:
    if not (root / ".git").exists():
        raise ValueError("{} is not a Git worktree: {}".format(name, root))
    head = str(git_output(root, "rev-parse", "HEAD", text=True)).strip()
    raw_status = bytes(git_output(root, "status", "--porcelain=v1", "-z", "--untracked-files=all"))
    entries = status_entries(raw_status, excluded_paths)
    status = b"\0".join(entries)
    diff_args = ["diff", "--binary", "--no-ext-diff", "HEAD", "--", "."]
    diff_args.extend(":(exclude){}".format(path) for path in sorted(excluded_paths))
    tracked_diff = bytes(git_output(root, *diff_args))
    untracked = untracked_paths(entries)
    digest = hashlib.sha256()
    digest.update(head.encode("ascii", errors="replace"))
    digest.update(b"\0status\0")
    digest.update(status)
    digest.update(b"\0tracked-diff-sha256\0")
    digest.update(hashlib.sha256(tracked_diff).hexdigest().encode("ascii"))
    for relative in untracked:
        digest.update(b"\0untracked\0")
        digest.update(relative.encode("utf-8", errors="surrogateescape"))
        digest.update(b"\0")
        digest.update(file_identity(root / relative).encode("utf-8", errors="surrogateescape"))
    return {
        "name": name,
        "root": str(root),
        "head": head,
        "dirty": bool(entries),
        "change_count": len(entries),
        "untracked_count": len(untracked),
        "worktree_fingerprint": digest.hexdigest(),
        "excluded_paths": sorted(excluded_paths),
        "raw_diff_stored": False,
    }


def artifact_receipt(path: pathlib.Path) -> dict[str, Any]:
    resolved = path.expanduser().resolve()
    if not resolved.is_file():
        raise ValueError("artifact does not exist: {}".format(resolved))
    return {
        "path": str(resolved),
        "sha256": sha256_file(resolved),
        "bytes": resolved.stat().st_size,
    }


def plan_receipt(path: pathlib.Path) -> dict[str, Any]:
    receipt = artifact_receipt(path)
    try:
        payload = json.loads(path.expanduser().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError("invalid Codex plan: {}".format(exc)) from exc
    target = payload.get("target_receipt") if isinstance(payload.get("target_receipt"), dict) else {}
    receipt.update(
        {
            "schema_version": payload.get("schema_version"),
            "content_changes": payload.get("content_changes"),
            "content_noop": payload.get("content_noop"),
            "build_tree_sha256": (payload.get("build_receipt") or {}).get("tree_sha256", ""),
            "target_precondition_paths_sha256": target.get("precondition_paths_sha256", ""),
            "target_precondition_paths": target.get("precondition_paths", 0),
        }
    )
    return receipt


def build_bundle(args: argparse.Namespace) -> dict[str, Any]:
    evidence_paths = [pathlib.Path(value) for value in args.evidence]
    if not evidence_paths:
        raise ValueError("at least one --evidence path is required")
    if len(evidence_paths) > MAX_EVIDENCE_FILES:
        raise ValueError("at most {} evidence files are allowed".format(MAX_EVIDENCE_FILES))
    roots = {
        "llm-agent": pathlib.Path(args.workspace_root).expanduser().resolve(),
        "agent-dev-kit": pathlib.Path(args.adk_root).expanduser().resolve(),
        "codex": pathlib.Path(args.codex_root).expanduser().resolve(),
        "knowledge-hub": pathlib.Path(args.hub_root).expanduser().resolve(),
    }
    output_path = pathlib.Path(args.out).expanduser().resolve() if args.out else None
    excluded_by_repo: dict[str, set[str]] = {name: set() for name in roots}
    if output_path is not None:
        for name, root in roots.items():
            try:
                excluded_by_repo[name].add(str(output_path.relative_to(root)))
            except ValueError:
                continue
    payload = {
        "schema_version": BUNDLE_SCHEMA_VERSION,
        "projection": "adk-cross-repo-release-bundle-v1",
        "status": "provenance-only",
        "release_authorized": False,
        "repositories": [
            repo_receipt(name, root, excluded_by_repo[name]) for name, root in roots.items()
        ],
        "codex_plan": plan_receipt(pathlib.Path(args.codex_plan)),
        "hub_candidate": artifact_receipt(pathlib.Path(args.hub_candidate)),
        "evidence": [artifact_receipt(path) for path in evidence_paths],
        "privacy": {
            "raw_diff_stored": False,
            "prompt_stored": False,
            "query_stored": False,
            "log_body_stored": False,
            "credential_stored": False,
        },
        "must_not": ["commit", "push", "merge", "publish", "promote-active"],
    }
    encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(encoded) > MAX_OUTPUT_BYTES:
        raise ValueError("bundle exceeds {} bytes".format(MAX_OUTPUT_BYTES))
    return payload


def parser() -> argparse.ArgumentParser:
    root = pathlib.Path(__file__).resolve().parents[2]
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--workspace-root", default=str(root))
    result.add_argument("--adk-root", default=str(root / "agent-dev-kit"))
    result.add_argument("--codex-root", default=str(pathlib.Path.home() / "codex"))
    result.add_argument("--hub-root", default=str(pathlib.Path.home() / "knowledge-hub"))
    result.add_argument("--codex-plan", required=True)
    result.add_argument("--hub-candidate", required=True)
    result.add_argument("--evidence", action="append", default=[])
    result.add_argument("--out", default="")
    return result


def main(argv: Sequence[str] = ()) -> int:
    args = parser().parse_args(list(argv) if argv else None)
    try:
        payload = build_bundle(args)
    except (subprocess.CalledProcessError, ValueError) as exc:
        raise SystemExit("[FAIL] {}".format(exc))
    output = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        target = pathlib.Path(args.out).expanduser().resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=target.parent, delete=False) as handle:
            handle.write(output)
            temporary = pathlib.Path(handle.name)
        os.replace(str(temporary), str(target))
    print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
