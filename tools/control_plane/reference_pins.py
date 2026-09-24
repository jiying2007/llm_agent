from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

from .process_budget import ProcessBudgetError, run_bounded

_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
_ID_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]*$")


@dataclass(frozen=True)
class ReferenceSource:
    """Read-only identity resolved from an approved pin, never a Root fallback."""

    reference_id: str
    repository: Path
    url: str
    commit: str
    tree: str


def git_environment() -> dict[str, str]:
    env = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    env.update({
        "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_CONFIG_SYSTEM": os.devnull, "GIT_TERMINAL_PROMPT": "0",
        "GIT_NO_REPLACE_OBJECTS": "1", "GIT_OPTIONAL_LOCKS": "0",
        "GIT_LFS_SKIP_SMUDGE": "1",
    })
    return env


def git_command(repository: Path, *args: str) -> list[str]:
    return [
        "git", "-c", "core.hooksPath=" + os.devnull, "-c", "core.fsmonitor=false",
        "-c", "submodule.recurse=false", "-c", "protocol.ext.allow=never",
        "-C", str(repository), *args,
    ]


def _git(cwd: Path, *args: str, allowed_codes: tuple[int, ...] = (0,)) -> str:
    result = run_bounded(git_command(cwd, *args), timeout=120, env=git_environment())
    if result.returncode not in allowed_codes:
        raise RuntimeError("git {} failed: {}".format(args[0], result.stderr.decode(errors="replace")[-500:]))
    return result.stdout.decode("utf-8").strip()


def _tracked_gitlinks(root: Path) -> set[str]:
    result: set[str] = set()
    for record in _git(root, "ls-files", "-s", "-z").split("\0"):
        if record:
            header, path = record.split("\t", 1)
            if header.split(" ", 1)[0] == "160000":
                result.add(path)
    return result


def _submodule_paths(root: Path) -> set[str]:
    config = root / ".gitmodules"
    if not config.exists():
        return set()
    output = _git(root, "config", "-f", str(config), "--get-regexp", r"^submodule\..*\.path$", allowed_codes=(0, 1))
    return {line.split(None, 1)[1].strip() for line in output.splitlines() if line.strip()}


def _load(root: Path) -> dict[str, Any]:
    path = root / "manifests" / "reference_pins.json"
    if path.stat().st_size > 1024 * 1024:
        raise RuntimeError("reference pin manifest exceeds byte budget")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or data.get("schema") != "llm-agent-reference-pins/v2":
        raise RuntimeError("unsupported reference pin schema")
    policy = data.get("policy")
    if not isinstance(policy, dict):
        raise RuntimeError("reference pin policy must be an object")
    for key, value in {
        "tracked_gitlink_forbidden": True, "submodule_entry_forbidden": True,
        "runtime_enablement": False, "pin_is_evidence_not_source": True,
        "materialization_root": "user-cache-only", "materialization_requires_explicit_id": True,
    }.items():
        if policy.get(key) != value:
            raise RuntimeError(f"reference pin policy {key} must be {value!r}")
    if not isinstance(data.get("pins"), list):
        raise RuntimeError("reference pins must be a list")
    return data


def _index(root: Path) -> dict[str, dict[str, Any]]:
    data = _load(root)
    tracked_gitlinks, submodules = _tracked_gitlinks(root), _submodule_paths(root)
    seen_paths: set[str] = set()
    indexed: dict[str, dict[str, Any]] = {}
    for pin in data["pins"]:
        if not isinstance(pin, dict):
            raise RuntimeError("reference pin entries must be objects")
        pin_id, commit, kind = pin.get("id"), pin.get("commit"), pin.get("kind")
        if not isinstance(pin_id, str) or not _ID_RE.fullmatch(pin_id):
            raise RuntimeError("reference pin requires a safe non-empty id")
        if pin_id in indexed:
            raise RuntimeError(f"duplicate reference pin id: {pin_id}")
        if not isinstance(kind, str) or not kind:
            raise RuntimeError(f"reference pin {pin_id} requires kind")
        if not isinstance(commit, str) or not _COMMIT_RE.fullmatch(commit):
            raise RuntimeError(f"reference pin {pin_id} requires exact 40-char lowercase commit")
        if kind == "reference-repo":
            path, url = pin.get("path"), pin.get("url")
            if (not isinstance(path, str) or not path or path in (".", "..")
                    or Path(path).is_absolute() or ".." in Path(path).parts or "\\" in path):
                raise RuntimeError(f"reference repo {pin_id} requires safe relative path")
            if path in seen_paths:
                raise RuntimeError(f"duplicate reference repo path: {path}")
            seen_paths.add(path)
            if not isinstance(url, str):
                raise RuntimeError(f"reference repo {pin_id} requires https URL")
            parsed = urlsplit(url)
            if (parsed.scheme != "https" or not parsed.hostname or parsed.username is not None
                    or parsed.password is not None or parsed.query or parsed.fragment
                    or any(c in url for c in ("\0", "\n", "\r"))):
                raise RuntimeError(f"reference repo {pin_id} requires credential-free https URL")
            if path in tracked_gitlinks or path in submodules:
                raise RuntimeError(f"reference repo {pin_id} must not be a gitlink or submodule: {path}")
        elif pin_id in tracked_gitlinks or pin_id in submodules:
            raise RuntimeError(f"opaque reference pin {pin_id} must not become a source checkout")
        indexed[pin_id] = pin
    return indexed


def check(root: Path) -> dict[str, Any]:
    indexed = _index(root)
    repos = sorted(name for name, pin in indexed.items() if pin.get("kind") == "reference-repo")
    return {
        "schema": "llm-agent-reference-pin-check/v2", "status": "pass", "count": len(indexed),
        "reference_repo_count": len(repos), "reference_repos": repos, "pins": sorted(indexed),
    }


def protected_roots(root: Path) -> tuple[Path, ...]:
    """Source/live roots are read from the existing target registry, not copied."""
    home = Path.home()
    paths = [home / ".ssh", home / ".codex", home / ".claude", home / ".config" / "opencode"]
    registry = root / "manifests" / "runtime_targets.json"
    if registry.exists():
        data = json.loads(registry.read_text(encoding="utf-8"))
        if not isinstance(data, dict) or not isinstance(data.get("targets"), list):
            raise RuntimeError("runtime target registry is invalid")
        for target in data["targets"]:
            if not isinstance(target, dict):
                raise RuntimeError("runtime target must be an object")
            for key in ("source_repo", "live_root"):
                value = target.get(key)
                if value:
                    if not isinstance(value, str):
                        raise RuntimeError("runtime source/live root must be a path string")
                    path = Path(value).expanduser()
                    paths.append(path if path.is_absolute() else root / path)
    return tuple(path.resolve() for path in paths)


def paths_overlap(left: Path, right: Path) -> bool:
    return left == right or left in right.parents or right in left.parents


def _cache_root(explicit: str | None) -> Path:
    base = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))).expanduser()
    return (Path(explicit).expanduser() if explicit else base / "llm-agent" / "reference-repos").resolve()


def plan(root: Path, pin_id: str, cache_root: str | None = None) -> dict[str, Any]:
    pin = _index(root).get(pin_id)
    if pin is None:
        raise RuntimeError(f"unknown reference pin id: {pin_id}")
    if pin.get("kind") != "reference-repo":
        raise RuntimeError(f"reference pin {pin_id} is not a materializable reference-repo")
    base = _cache_root(cache_root)
    if base == Path.home().resolve() or any(paths_overlap(base, denied) for denied in (root.resolve(), *protected_roots(root))):
        raise RuntimeError("reference cache overlaps workspace or protected source/live root")
    target = base / pin_id / pin["commit"]
    if target.resolve() != target:
        raise RuntimeError("reference cache target must not traverse symlinks")
    return {
        "schema": "llm-agent-reference-materialization-plan/v1", "status": "pass", "id": pin_id,
        "path": pin["path"], "url": pin["url"], "commit": pin["commit"], "target": str(target),
        "runtime_enablement": False,
    }


def resolve_source(root: Path, pin_id: str, cache_root: str | None = None) -> ReferenceSource:
    receipt = plan(root, pin_id, cache_root)
    target = Path(receipt["target"])
    if not (target / ".git").is_dir() or (target / ".git").is_symlink():
        raise RuntimeError("reference is not materialized; explicitly materialize its approved pin first")
    if _git(target, "rev-parse", "--show-toplevel") != str(target):
        raise RuntimeError("reference cache is not an independent repository")
    if _git(target, "rev-parse", "HEAD") != receipt["commit"]:
        raise RuntimeError(f"cached reference drift for {pin_id}")
    if _git(target, "config", "--get", "remote.origin.url") != receipt["url"]:
        raise RuntimeError(f"cached reference origin differs from approved pin for {pin_id}")
    tree = _git(target, "rev-parse", receipt["commit"] + "^{tree}")
    if not _COMMIT_RE.fullmatch(tree):
        raise RuntimeError("reference tree identity is invalid")
    return ReferenceSource(pin_id, target, receipt["url"], receipt["commit"], tree)


def materialize(root: Path, pin_id: str, cache_root: str | None = None) -> dict[str, Any]:
    receipt = plan(root, pin_id, cache_root)
    target, commit = Path(receipt["target"]), receipt["commit"]
    if target.exists():
        source = resolve_source(root, pin_id, cache_root)
        receipt.update({"schema": "llm-agent-reference-materialization-receipt/v1", "materialized": True,
                        "reused": True, "tree": source.tree})
        return receipt
    target.parent.mkdir(parents=True, exist_ok=True)
    temp = Path(tempfile.mkdtemp(prefix=f".{pin_id}-", dir=target.parent))
    try:
        _git(temp, "init", "--template=", "-q")
        _git(temp, "remote", "add", "origin", receipt["url"])
        _git(temp, "fetch", "--depth=1", "origin", commit)
        _git(temp, "checkout", "--detach", "-q", "FETCH_HEAD")
        if _git(temp, "rev-parse", "HEAD") != commit:
            raise RuntimeError(f"materialized reference mismatch for {pin_id}")
        # Never replace an existing cache populated by another process.
        if target.exists() or target.resolve() != target:
            raise RuntimeError("reference cache target appeared or drifted during materialization")
        temp.rename(target)
    except Exception:
        shutil.rmtree(temp, ignore_errors=True)
        raise
    source = resolve_source(root, pin_id, cache_root)
    receipt.update({"schema": "llm-agent-reference-materialization-receipt/v1", "materialized": True,
                    "reused": False, "tree": source.tree})
    return receipt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate and explicitly materialize non-source reference identities")
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
    except (OSError, ValueError, RuntimeError) as exc:
        result = {"schema": "llm-agent-reference-pin-result/v2", "status": "fail", "error": str(exc),
                  "reason": "budget-exceeded" if isinstance(exc, ProcessBudgetError) else "invalid-source"}
        if args.summary_json:
            print(json.dumps(result, ensure_ascii=False))
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
