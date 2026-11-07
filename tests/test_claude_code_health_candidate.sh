#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/adapters/claude-code-health.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HOME_ROOT="$TMP/home"
mkdir -p "$HOME_ROOT/.claude/skills/adk-example" "$HOME_ROOT/.claude/commands"
ROOT_LIVE="$HOME_ROOT/.claude"
printf '%s\n' '---' 'name: adk-example' 'description: example fixture' '---' '# Example' > "$ROOT_LIVE/skills/adk-example/SKILL.md"
printf '%s\n' '{"theme":"light"}' > "$ROOT_LIVE/settings.json"
bash "$CHECK" "$ROOT_LIVE" minimal | grep -q 'native_certified=false'
bash "$CHECK" "$ROOT_LIVE" security | grep -q '\[PASS\]'
if bash "$CHECK" "$ROOT_LIVE" strict >/dev/null 2>&1; then
  echo "[FAIL] strict preflight accepted missing ADK receipt" >&2
  exit 1
fi
python3 - "$ROOT_LIVE" <<'PY'
import hashlib
import json
import pathlib
import sys
root=pathlib.Path(sys.argv[1])
file=root/"skills/adk-example/SKILL.md"
receipt={
    "schema": "adk-install-receipt/v3",
    "tool": "claude-code",
    "asset_kind": "skill",
    "target": str(root.resolve()),
    "installed": [{
        "destination": "skills/adk-example/SKILL.md",
        "installed_sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        "file_mode": "0644",
    }],
}
canonical=json.dumps(receipt,sort_keys=True,separators=(",",":"),ensure_ascii=False)+"\n"
receipt["receipt_sha256"]=hashlib.sha256(canonical.encode()).hexdigest()
(root/".adk-install-receipt.json").write_text(json.dumps(receipt),encoding="utf-8")
PY
bash "$CHECK" "$ROOT_LIVE" strict | grep -q 'native_certified=false'
printf 'modified\n' >> "$ROOT_LIVE/skills/adk-example/SKILL.md"
if bash "$CHECK" "$ROOT_LIVE" strict >/dev/null 2>&1; then
  echo "[FAIL] strict preflight accepted modified installed Skill" >&2
  exit 1
fi
sed -i '$d' "$ROOT_LIVE/skills/adk-example/SKILL.md"
printf '%s\n' '{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"~/claude/control/scripts/session-start.sh"}]}]}}' > "$ROOT_LIVE/settings.json"
if bash "$CHECK" "$ROOT_LIVE" security >/dev/null 2>&1; then
  echo "[FAIL] security preflight accepted legacy global injection" >&2
  exit 1
fi
printf '%s\n' '{"theme":"light"}' > "$ROOT_LIVE/settings.json"
mkdir "$TMP/elsewhere"
mv "$ROOT_LIVE/skills" "$TMP/elsewhere/skills"
ln -s "$TMP/elsewhere/skills" "$ROOT_LIVE/skills"
if bash "$CHECK" "$ROOT_LIVE" minimal >/dev/null 2>&1; then
  echo "[FAIL] preflight accepted whole-directory link" >&2
  exit 1
fi
echo "[PASS] Claude candidate health contract: source layout, receipt digest, tamper and injection"
