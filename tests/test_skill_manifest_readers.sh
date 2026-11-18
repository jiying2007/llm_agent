#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/agent-dev-kit/skills/adk-a" "$TMP/agent-dev-kit/optional-skills/adk-b"
cat >"$TMP/agent-dev-kit/manifest.json" <<'JSON'
{
  "skills": [{"name":"adk-a","path":"skills/adk-a/SKILL.md","quality_tier":"core"}],
  "optional_skills": [{"name":"adk-b","path":"optional-skills/adk-b/SKILL.md","quality_tier":"optional"}]
}
JSON
cat >"$TMP/agent-dev-kit/skills/adk-a/SKILL.md" <<'EOF'
---
name: adk-a
version: 1.0.0
last_updated: 2026-11-18
triggers:
  - alpha task
---
EOF
cat >"$TMP/agent-dev-kit/optional-skills/adk-b/SKILL.md" <<'EOF'
---
name: adk-b
version: 1.0.0
last_updated: 2026-11-18
triggers:
  - beta task
---
EOF

for checker in check-skill-metadata.sh check-skill-routing-conflicts.sh; do
  bash "$ROOT/scripts/$checker" "$TMP" >"$TMP/$checker.pass" 2>&1 || {
    cat "$TMP/$checker.pass" >&2
    echo "[FAIL] valid manifest rejected by $checker" >&2
    exit 1
  }
done

# A valid first JSON document followed by malformed input used to output
# rows and then fail in jq; process substitution hid that failure.
printf 'broken trailing JSON\n' >>"$TMP/agent-dev-kit/manifest.json"
for checker in check-skill-metadata.sh check-skill-routing-conflicts.sh; do
  if bash "$ROOT/scripts/$checker" "$TMP" >"$TMP/$checker.bad" 2>&1; then
    echo "[FAIL] $checker accepted truncated manifest input" >&2
    exit 1
  fi
  grep -Eq 'invalid.*skill manifest|manifest must contain' "$TMP/$checker.bad"
done

sed -i '/broken trailing JSON/d' "$TMP/agent-dev-kit/manifest.json"
mv "$TMP/agent-dev-kit/optional-skills/adk-b/SKILL.md" "$TMP/missing-skill.md"
if bash "$ROOT/scripts/check-skill-routing-conflicts.sh" "$TMP" >"$TMP/missing.out" 2>&1; then
  echo "[FAIL] routing accepted manifest pointing to missing Skill" >&2
  exit 1
fi
grep -q 'missing or unsafe skill file' "$TMP/missing.out"
mv "$TMP/missing-skill.md" "$TMP/agent-dev-kit/optional-skills/adk-b/SKILL.md"

sed -i 's/beta task/alpha task/' "$TMP/agent-dev-kit/optional-skills/adk-b/SKILL.md"
if bash "$ROOT/scripts/check-skill-routing-conflicts.sh" "$TMP" >"$TMP/duplicate.out" 2>&1; then
  echo "[FAIL] routing accepted duplicate triggers" >&2
  exit 1
fi
grep -q '\[CONFLICT\]' "$TMP/duplicate.out"

echo "[PASS] skill manifest readers fail closed on invalid streams and missing files"
