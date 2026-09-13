from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
_ID_RE = re.compile(r"^[A-Za-z0-9._-]+$")


def _tracked_gitlinks(root: Path) -> set[str]:
    completed = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-s", "-z"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or "git ls-files failed")
    result: set[str] = set()
    for record in completed.stdout.split("\0"):
        if not record:
            continue
        header, path = record.split("\t", 1)
        mode = header.split(" ", 1)[0]
        if mode == "160000":
            result.add(path)
    return result


def _submodule_paths(root: Path) -> set[str]:
    config = root / ".gitmodules"
    if not config.exists():
        return set()
    completed = subprocess.run(
        ["git", "config", "-f", str(config), "--get-regexp", r"^submodule\..*\.path$"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode not in (0, 1):
        raise RuntimeError(completed.stderr.strip() or "unable to read .gitmodules")
    return {line.split(None, 1)[1].strip() for line in completed.stdout.splitlines() if line.strip()}


def _load(root: Path) -> dict[str, Any]:
    path = root / "manifests" / "reference_pins.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "llm-agent-reference-pins/v2":
        raise RuntimeError("unsupported reference pin schema")
    policy = data.get("policy")
    if not isinstance(policy, dict):
        raise RuntimeError("reference pin policy must be an object")
    required_policy = {
        "tracked_gitlink_forbidden": True,
        "submodule_entry_forbidden": True,
        "runtime_enablement": False,
        "pin_is_evidence_not_source": True,
        "materialization_root": "user-cache-only",
        "materialization_requires_explicit_id": True,
    }
    for key, value in required_policy.items():
        if policy.get(key) != value:
            raise RuntimeError(f"reference pin policy {key} must be {value!r}")
    pins = data.get("pins")
    if not isinstance(pins, list):
        raise RuntimeError("reference pins must be a list")
    return data


def _index(root: Path) -> dict[str, dict[str, Any]]:
    data = _load(root)
    tracked_gitlinks = _tracked_gitlinks(root)
    submodules = _submodule_paths(root)
    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    indexed: dict[str, dict[str, Any]] = {}

    for pin in data["pins"]:
        if not isinstance(pin, dict):
            raise RuntimeError("reference pin entries must be objects")
        pin_id = pin.get("id")
        commit = pin.get("commit")
        kind = pin.get("kind")
        if not isinstance(pin_id, str) or not pin_id or not _ID_RE.fullmatch(pin_id):
            raise RuntimeError("reference pin requires a safe non-empty id")
        if pin_id in seen_ids:
            raise RuntimeError(f"duplicate reference pin id: {pin_id}")
        seen_ids.add(pin_id)
        if not isinstance(kind, str) or not kind:
            raise RuntimeError(f"reference pin {pin_id} requires kind")
        if not isinstance(commit, str) or not _COMMIT_RE.fullmatch(commit):
            raise RuntimeError(f"reference pin {pin_id} requires exact 40-char lowercase commit")

        if kind == "reference-repo":
            path = pin.get("path")
            url = pin.get("url")
            if not isinstance(path, str) or not path or path.startswith("/") or ".." in Path(path).parts:
                raise RuntimeError(f"reference repo {pin_id} requires safe relative path")
            if path in seen_paths:
                raise RuntimeError(f"duplicate reference repo path: {path}")
            seen_paths.add(path)
            if not isinstance(url, str) or not url.startswith("https://"):
                raise RuntimeError(f"reference repo {pin_id} requires https URL")
            if path in tracked_gitlinks:
                raise RuntimeError(f"reference repo {pin_id} must not be tracked as gitlink: {path}")
            if path in submodules:
                raise RuntimeError(f"reference repo {pin_id} must not be present in .gitmodules: {path}")
        elif pin_id in tracked_gitlinks or pin_id in submodules:
            raise RuntimeError(f"opaque reference pin {pin_id} must not become a source checkout")

        indexed[pin_id] = pin

    return indexed


def check(root: Path) -> dict[str, Any]:
    indexed = _index(root)
    reference_repos = sorted(pin_id for pin_id, pin in indexed.items() if pin.get("kind") == "reference-repo")
    return {
        "schema": "llm-agent-reference-pin-check/v2",
        "status": "pass",
        "count": len(indexed),
        "reference_repo_count": len(reference_repos),
        "reference_repos": reference_repos,
        "pins": sorted(indexed),
    }


def _cache_root(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    xdg = os.environ.get("XDG_CACHE_HOME")
    base = Path(xdg).expanduser() if xdg else Path.home() / ".cache"
    return (base / "llm-agent" / "reference-repos").resolve()


def plan(root: Path, pin_id: str, cache_root: str | None = None) -> dict[str, Any]:
    indexed = _index(root)
    pin = indexed.get(pin_id)
    if pin is None:
        raise RuntimeError(f"unknown reference pin id: {pin_id}")
    if pin.get("kind") != "reference-repo":
        raise RuntimeError(f"reference pin {pin_id} is not a materializable reference-repo")
    target = _cache_root(cache_root) / pin_id / pin["commit"]
    return {
        "schema": "llm-agent-reference-materialization-plan/v1",
        "status": "pass",
        "id": pin_id,
        "path": pin["path"],
        "url": pin["url"],
        "commit": pin["commit"],
        "target": str(target),
        "runtime_enablement": False,
    }


def _git(cwd: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout.strip()


def materialize(root: Path, pin_id: str, cache_root: str | None = None) -> dict[str, Any]:
    receipt = plan(root, pin_id, cache_root)
    target = Path(receipt["target"])
    commit = receipt["commit"]
    if target.exists():
        if not (target / ".git").exists():
            raise RuntimeError(f"materialization target exists but is not a git checkout: {target}")
        actual = _git(target, "rev-parse", "HEAD")
        if actual != commit:
            raise RuntimeError(f"cached reference drift for {pin_id}: {actual} != {commit}")
        receipt.update({"schema": "llm-agent-reference-materialization-receipt/v1", "materialized": True, "reused": True})
        return receipt

    target.parent.mkdir(parents=True, exist_ok=True)
    temp = Path(tempfile.mkdtemp(prefix=f".{pin_id}-", dir=str(target.parent)))
    try:
        _git(temp, "init", "-q")
        _git(temp, "remote", "add", "origin", receipt["url"])
        _git(temp, "fetch", "--depth=1", "origin", commit)
        _git(temp, "checkout", "--detach", "-q", "FETCH_HEAD")
        actual = _git(temp, "rev-parse", "HEAD")
        if actual != commit:
            raise RuntimeError(f"materialized reference mismatch for {pin_id}: {actual} != {commit}")
        os.replace(temp, target)
    except Exception:
        shutil.rmtree(temp, ignore_errors=True)
        raise
    receipt.update({"schema": "llm-agent-reference-materialization-receipt/v1", "materialized": True, "reused": False})
    return receipt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and explicitly materialize non-source reference repository identities")
    parser.add_argument("--root", default=".")
    parser.add_argument("--plan", metavar="ID")
    parser.add_argument("--materialize", metavar="ID")
    parser.add_argument("--cache-root")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    if args.plan and args.materialize:
        parser.error("--plan and --materialize are mutually exclusive")
    root = Path(args.root).resolve()
    try:
        if args.plan:
            result = plan(root, args.plan, args.cache_root)
        elif args.materialize:
            result = materialize(root, args.materialize, args.cache_root)
        else:
            result = check(root)
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        if args.summary_json:
            print(json.dumps({"schema": "llm-agent-reference-pin-result/v2", "status": "fail", "error": str(exc)}, ensure_ascii=False))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    elif args.plan:
        print(f"[PASS] reference plan {result['id']} -> {result['target']}")
    elif args.materialize:
        print(f"[PASS] materialized {result['id']} -> {result['target']}")
    else:
        print(f"[PASS] non-source reference pins valid (count={result['count']}, repos={result['reference_repo_count']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
