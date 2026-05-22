#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

case "${2:-}" in
  "" )
    ;;
  -h|--help)
    cat <<USAGE
usage: scripts/check-stale-references.sh [root]

Checks active llm_agent / agent-dev-kit governance files for stale version,
path, direct-runtime-install and retired script references. Historical archives
are intentionally excluded.
USAGE
    exit 0
    ;;
  *)
    echo "[FAIL] unknown arg: $2" >&2
    exit 1
    ;;
esac

declare -a SCAN_PATHS=(
  "AGENTS.md"
  "scripts/README.md"
  "reports/codex-pilot-report.md"
  "agent-dev-kit/README.md"
  "agent-dev-kit/CONTEXT.md"
  "agent-dev-kit/docs"
  "agent-dev-kit/scripts"
)

declare -a PATTERNS=(
  'adk v2\.0\.0 当前状态'
  'v2\.0\.0 发布后'
  '97/100'
  '97/97'
  '97 测试'
  '/home/aiot03'
  'scripts/(install_assets|skill_match|validate_assets)\.sh'
  'sync_codex_assets\.sh'
  '--lock-version 0\.3\.0'
  'devkit\.sh install[^\n]*(--tool[ =]codex|--target[ =][^\n]*~/.codex)'
)

tmpfile="$(mktemp)"
trap 'rm -f "${tmpfile}"' EXIT

for rel in "${SCAN_PATHS[@]}"; do
  path="${ROOT}/${rel}"
  [[ -e "${path}" ]] || continue
  for pattern in "${PATTERNS[@]}"; do
    rg -n --pcre2 \
      -g '!reports/archive/**' \
      -g '!agent-dev-kit/reports/archive/**' \
      -- "${pattern}" "${path}" \
      >>"${tmpfile}" || true
  done
done

if [[ -s "${tmpfile}" ]]; then
  echo "[FAIL] stale active references found" >&2
  sed 's/^/  - /' "${tmpfile}" >&2
  exit 1
fi

echo "[PASS] no stale active references"
