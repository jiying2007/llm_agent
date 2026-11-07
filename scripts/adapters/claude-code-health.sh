#!/usr/bin/env bash
# Read-only Claude Code source-to-live health *preflight*.
# This is NOT a native Claude Code discovery/trigger or certification test.
set -euo pipefail

target="${1:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
profile="${2:-minimal}"
case "$profile" in
  minimal|security|strict) ;;
  *) echo "[FAIL] unsupported profile: $profile" >&2; exit 2 ;;
esac
case "$target" in
  /*) ;;
  *) echo "[FAIL] target must be absolute" >&2; exit 2 ;;
esac
python3 - "$target" "$profile" <<'PY'
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import sys

root, profile = Path(sys.argv[1]), sys.argv[2]

def fail(message: str) -> None:
    raise ValueError(message)

def regular_file(path: Path) -> bool:
    return not path.is_symlink() and path.is_file()

def read_json(path: Path, max_bytes: int = 1024 * 1024):
    if not regular_file(path):
        fail(f"not a regular JSON file: {path.name}")
    if path.stat().st_size > max_bytes:
        fail(f"JSON input exceeds safe size: {path.name}")
    def unique(items):
        result = {}
        for key, value in items:
            if key in result:
                fail("duplicate JSON key")
            result[key] = value
        return result
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique)

def digest(path: Path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

try:
    if root.is_symlink() or not root.is_dir():
        fail("Claude live root missing or is a symlink")
    root = root.resolve()
    for name in ("skills", "agents", "commands"):
        path = root / name
        if path.is_symlink():
            fail(f"whole-directory symlink forbidden: {name}")
    skills = root / "skills"
    if not skills.is_dir():
        fail("native skills directory missing")
    discovered = []
    for child in sorted(skills.iterdir()):
        if child.is_symlink():
            fail(f"Skill directory is symlink: {child.name}")
        if not child.is_dir():
            continue
        skill_file = child / "SKILL.md"
        if skill_file.is_symlink():
            fail(f"Skill file is symlink: {child.name}")
        if skill_file.is_file():
            discovered.append(child.name)
    if not discovered:
        fail("no native SKILL.md assets discovered")

    if profile in ("security", "strict"):
        settings_path = root / "settings.json"
        if settings_path.exists() or settings_path.is_symlink():
            settings = read_json(settings_path)
            if not isinstance(settings, dict):
                fail("settings.json must be an object")
            legacy_tokens = ("superpowers", "using-skills", "session-start.sh")
            def has_legacy_command(value):
                if isinstance(value, dict):
                    for key, val in value.items():
                        if key == "command" and isinstance(val, str) and any(
                            tok in val.lower() for tok in legacy_tokens
                        ):
                            return True
                        if has_legacy_command(val):
                            return True
                elif isinstance(value, list):
                    return any(has_legacy_command(item) for item in value)
                return False
            if has_legacy_command(settings.get("hooks")):
                fail("legacy Superpowers/using-skills hook is still active")
            enabled = settings.get("enabledPlugins", {})
            if isinstance(enabled, dict) and any(
                "superpowers" in str(name).lower() and state is not False
                for name, state in enabled.items()
            ):
                fail("Superpowers remains enabled as a native plugin")
        commands = root / "commands"
        if commands.is_dir():
            for item in commands.iterdir():
                if item.is_symlink() and "superpowers" in os.readlink(item).lower():
                    fail(f"legacy command symlink: {item.name}")

    if profile == "strict":
        receipt_path = root / ".adk-install-receipt.json"
        receipt = read_json(receipt_path)
        if not isinstance(receipt, dict):
            fail("ADK install receipt must be an object")
        if (receipt.get("schema") != "adk-install-receipt/v3"
            or receipt.get("tool") != "claude-code"
            or receipt.get("asset_kind") != "skill"
            or receipt.get("target") != str(root)):
            fail("ADK install receipt scope mismatch")
        expected_receipt = receipt.get("receipt_sha256")
        unsigned = dict(receipt)
        unsigned.pop("receipt_sha256", None)
        canonical = (json.dumps(unsigned, ensure_ascii=False, sort_keys=True,
                                separators=(",", ":")) + "\n").encode("utf-8")
        if (not isinstance(expected_receipt, str)
                or hashlib.sha256(canonical).hexdigest() != expected_receipt):
            fail("ADK install receipt content digest mismatch")
        files = receipt.get("installed")
        if not isinstance(files, list) or not 0 < len(files) <= 5000:
            fail("ADK receipt inventory missing or unbounded")
        observed = set()
        for row in files:
            if not isinstance(row, dict):
                fail("invalid ADK installed entry")
            rel = row.get("destination")
            if not isinstance(rel, str):
                fail("invalid ADK installed path")
            parts = rel.split("/")
            if (len(parts) < 3 or parts[0] != "skills"
                or any(part in ("", ".", "..") for part in parts)
                or rel in observed):
                fail("invalid, escaping or duplicate ADK installed path")
            observed.add(rel)
            path = root.joinpath(*parts)
            current = root
            for part in parts[:-1]:
                current = current / part
                if current.is_symlink():
                    fail("ADK installed path parent is a symlink")
            if not regular_file(path):
                fail("ADK installed file missing or is a symlink")
            if row.get("installed_sha256") != digest(path):
                fail("ADK installed asset digest mismatch")
            declared_mode = row.get("file_mode")
            if (not isinstance(declared_mode, str)
                or len(declared_mode) != 4 or declared_mode[0] != "0"
                or any(digit not in "01234567" for digit in declared_mode)):
                fail("ADK installed asset mode is missing or invalid")
            if os.name != "nt" and stat.S_IMODE(path.stat().st_mode) != int(declared_mode, 8):
                fail("ADK installed asset permissions drifted")

    print(f"[PASS] Claude {profile} source-layout preflight: skills={len(discovered)}; native_certified=false")
except (ValueError, OSError, UnicodeError, json.JSONDecodeError, KeyError) as exc:
    print(f"[FAIL] Claude {profile} preflight: {exc}", file=sys.stderr)
    sys.exit(2)
PY
