from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

FORBIDDEN_PREFIXES = (
    ".cache/",
    ".state/",
    "__pycache__/",
    ".pytest_cache/",
    ".mypy_cache/",
    ".ruff_cache/",
    "build/",
    "dist/",
)
FORBIDDEN_SUFFIXES = (".pyc", ".pyo", ".lock")
ALLOW_LOCKS = {"adk.lock"}


def tracked_paths(root: Path) -> list[str]:
    completed = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.decode("utf-8", errors="replace").strip())
    return [part.decode("utf-8", errors="strict") for part in completed.stdout.split(b"\0") if part]


def violations(paths: list[str]) -> list[str]:
    bad: list[str] = []
    for path in paths:
        if path in ALLOW_LOCKS:
            continue
        if any(path.startswith(prefix) for prefix in FORBIDDEN_PREFIXES):
            bad.append(path)
            continue
        if any(path.endswith(suffix) for suffix in FORBIDDEN_SUFFIXES):
            bad.append(path)
    return sorted(bad)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Reject ephemeral runtime/session state tracked in source")
    parser.add_argument("--root", default=".")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        paths = tracked_paths(Path(args.root).resolve())
        bad = violations(paths)
    except (OSError, RuntimeError, UnicodeError) as exc:
        if args.summary_json:
            print(json.dumps({"schema": "llm-agent-source-hygiene/v1", "status": "fail", "error": str(exc)}, ensure_ascii=False))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1

    result = {
        "schema": "llm-agent-source-hygiene/v1",
        "status": "fail" if bad else "pass",
        "tracked_files": len(paths),
        "violations": bad,
    }
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    elif bad:
        print("[FAIL] ephemeral/runtime paths are tracked:", file=sys.stderr)
        for path in bad:
            print(f"  {path}", file=sys.stderr)
    else:
        print(f"[PASS] source hygiene (tracked_files={len(paths)})")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
