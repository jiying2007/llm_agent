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
  "docs/README.md"
  "docs/llm-agent-maintenance-guide.md"
  "docs/runbooks/external-practice-intake.md"
  "docs/runbooks/reference-repository-lifecycle.md"
  "docs/runbooks/wechat-metadata-intake.md"
  "scripts/README.md"
  "manifests"
  "fixtures"
  "tests"
  "reports/codex-pilot-report.md"
  "agent-dev-kit/README.md"
  "agent-dev-kit/CONTEXT.md"
  "agent-dev-kit/docs"
  "agent-dev-kit/scripts"
)

if ! command -v rg >/dev/null 2>&1; then
  echo '[FAIL] ripgrep (rg) is required for stale reference verification' >&2
  exit 2
fi

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
    # Change records retain prior snapshots and negative command examples;
    # they are provenance rather than active installation guidance.
    scan_status=0
    rg -n --pcre2 \
      -g '!reports/archive/**' \
      -g '!agent-dev-kit/reports/archive/**' \
      -g '!**/docs/archive/**' \
      -g '!**/docs/changes/**' \
      -- "${pattern}" "${path}" \
      >>"${tmpfile}" || scan_status=$?
    if [[ "$scan_status" -gt 1 ]]; then
      echo "[FAIL] stale reference scan failed: ${rel} (exit=${scan_status})" >&2
      exit "$scan_status"
    fi
  done
done

if [[ -s "${tmpfile}" ]]; then
  echo "[FAIL] stale active references found" >&2
  sed 's/^/  - /' "${tmpfile}" >&2
  exit 1
fi

echo "[PASS] no stale active references"
