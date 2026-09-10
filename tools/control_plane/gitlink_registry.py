from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


def _run(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or "git command failed")
    return completed.stdout


def _tracked_gitlinks(root: Path) -> dict[str, str]:
    raw = _run(root, "ls-files", "-s", "-z")
    result: dict[str, str] = {}
    for record in raw.split("\0"):
        if not record:
            continue
        header, path = record.split("\t", 1)
        mode, sha, _stage = header.split(" ", 2)
        if mode == "160000":
            result[path] = sha
    return result


def _submodules(root: Path) -> dict[str, str]:
    config = root / ".gitmodules"
    if not config.exists():
        return {}
    completed = subprocess.run(
        ["git", "config", "-f", str(config), "--get-regexp", r"^submodule\..*\.path$"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode not in (0, 1):
        raise RuntimeError(completed.stderr.strip() or "unable to read .gitmodules")
    result: dict[str, str] = {}
    for line in completed.stdout.splitlines():
        if not line.strip():
            continue
        key, path = line.split(None, 1)
        name = key[len("submodule.") : -len(".path")]
        url_run = subprocess.run(
            ["git", "config", "-f", str(config), "--get", f"submodule.{name}.url"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if url_run.returncode != 0:
            raise RuntimeError(f"submodule {name!r} is missing url")
        result[path.strip()] = url_run.stdout.strip()
    return result


def check(root: Path) -> dict[str, Any]:
    registry_path = root / "manifests" / "gitlinks.json"
    if not registry_path.exists():
        raise RuntimeError(f"missing gitlink registry: {registry_path}")
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    if registry.get("schema") != "llm-agent-gitlinks/v1":
        raise RuntimeError("unsupported gitlink registry schema")

    entries = registry.get("gitlinks")
    if not isinstance(entries, list) or not entries:
        raise RuntimeError("gitlink registry must contain non-empty gitlinks")

    by_path: dict[str, dict[str, Any]] = {}
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            raise RuntimeError("each gitlink registry entry requires path")
        path = entry["path"]
        if path in by_path:
            raise RuntimeError(f"duplicate gitlink registry path: {path}")
        by_path[path] = entry

    tracked = _tracked_gitlinks(root)
    submodules = _submodules(root)
    registry_paths = set(by_path)
    tracked_paths = set(tracked)
    submodule_paths = set(submodules)

    unknown_gitlinks = sorted(tracked_paths - registry_paths)
    missing_gitlinks = sorted(registry_paths - tracked_paths)
    unknown_submodules = sorted(submodule_paths - registry_paths)
    if unknown_gitlinks:
        raise RuntimeError(f"unregistered gitlinks: {', '.join(unknown_gitlinks)}")
    if missing_gitlinks:
        raise RuntimeError(f"registry paths not tracked as gitlinks: {', '.join(missing_gitlinks)}")
    if unknown_submodules:
        raise RuntimeError(f".gitmodules paths missing from registry: {', '.join(unknown_submodules)}")

    for path, entry in by_path.items():
        expects_submodule = bool(entry.get("submodule"))
        if expects_submodule and path not in submodules:
            raise RuntimeError(f"registered submodule path missing from .gitmodules: {path}")
        if not expects_submodule and path in submodules:
            raise RuntimeError(f"opaque gitlink must not be traversed as submodule: {path}")
        if expects_submodule:
            expected_url = entry.get("url")
            if expected_url and submodules[path] != expected_url:
                raise RuntimeError(
                    f"submodule URL drift for {path}: {submodules[path]} != {expected_url}"
                )
        if entry.get("kind") == "managed-dependency":
            lock_name = entry.get("lock")
            if not isinstance(lock_name, str) or not (root / lock_name).is_file():
                raise RuntimeError(f"managed dependency {path} requires an existing lock file")

    return {
        "schema": "llm-agent-gitlink-check/v1",
        "status": "pass",
        "tracked_count": len(tracked),
        "submodule_count": len(submodules),
        "opaque_count": sum(1 for entry in entries if not entry.get("submodule")),
        "gitlinks": [
            {
                "path": path,
                "sha": tracked[path],
                "kind": by_path[path].get("kind"),
                "submodule": bool(by_path[path].get("submodule")),
            }
            for path in sorted(tracked)
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate tracked gitlinks against the explicit registry")
    parser.add_argument("--root", default=".")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = check(Path(args.root).resolve())
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        if args.summary_json:
            print(json.dumps({"schema": "llm-agent-gitlink-check/v1", "status": "fail", "error": str(exc)}, ensure_ascii=False))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(
            "[PASS] gitlink registry matches tracked pins "
            f"(gitlinks={result['tracked_count']}, submodules={result['submodule_count']}, opaque={result['opaque_count']})"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
