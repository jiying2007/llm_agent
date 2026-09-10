from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")


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


def check(root: Path) -> dict[str, Any]:
    path = root / "manifests" / "reference_pins.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "llm-agent-reference-pins/v1":
        raise RuntimeError("unsupported reference pin schema")
    pins = data.get("pins")
    if not isinstance(pins, list):
        raise RuntimeError("reference pins must be a list")

    tracked_gitlinks = _tracked_gitlinks(root)
    submodules = _submodule_paths(root)
    seen: set[str] = set()
    for pin in pins:
        if not isinstance(pin, dict):
            raise RuntimeError("reference pin entries must be objects")
        pin_id = pin.get("id")
        commit = pin.get("commit")
        kind = pin.get("kind")
        if not isinstance(pin_id, str) or not pin_id:
            raise RuntimeError("reference pin requires non-empty id")
        if pin_id in seen:
            raise RuntimeError(f"duplicate reference pin id: {pin_id}")
        seen.add(pin_id)
        if not isinstance(kind, str) or not kind:
            raise RuntimeError(f"reference pin {pin_id} requires kind")
        if not isinstance(commit, str) or not _COMMIT_RE.fullmatch(commit):
            raise RuntimeError(f"reference pin {pin_id} requires exact 40-char lowercase commit")
        if pin_id in tracked_gitlinks:
            raise RuntimeError(f"reference pin {pin_id} must not be tracked as gitlink")
        if pin_id in submodules:
            raise RuntimeError(f"reference pin {pin_id} must not be present in .gitmodules")

    return {
        "schema": "llm-agent-reference-pin-check/v1",
        "status": "pass",
        "count": len(pins),
        "pins": sorted(seen),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate non-submodule reference identities")
    parser.add_argument("--root", default=".")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = check(Path(args.root).resolve())
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        if args.summary_json:
            print(json.dumps({"schema": "llm-agent-reference-pin-check/v1", "status": "fail", "error": str(exc)}, ensure_ascii=False))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(f"[PASS] non-submodule reference pins valid (count={result['count']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
