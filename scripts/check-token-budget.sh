#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_JSON=0
MAX_GOVERNANCE_JSON_BYTES=3500
MAX_ROOT_DOC_LINES=520

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-token-budget.sh [root] [--summary-json]

Checks workspace-level token budget:
  - adk token-budget gate passes.
  - governance-health JSON remains compact.
  - active root docs/reports stay below hard line budgets.
  - high-signal root scripts expose compact JSON summaries.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

failures=()
summary_scripts=0
record_failure() {
  failures+=("$1")
}

run_capture() {
  local name="$1"
  shift
  local rc=0
  set +e
  "$@" >"${TMP_DIR}/${name}.out" 2>&1
  rc=$?
  set -e
  printf '%s' "$rc" >"${TMP_DIR}/${name}.rc"
  return 0
}

run_capture adk_token_budget "${ROOT}/agent-dev-kit/scripts/check-token-budget.sh" --summary-json
if [[ "$(cat "${TMP_DIR}/adk_token_budget.rc")" -ne 0 ]]; then
  record_failure "agent-dev-kit token budget failed"
fi

run_capture governance_health "${ROOT}/scripts/governance-health.sh" "${ROOT}" --format json --max-summary-chars 160
if [[ "$(cat "${TMP_DIR}/governance_health.rc")" -ne 0 ]]; then
  record_failure "governance-health failed"
fi
governance_json_bytes="$(wc -c <"${TMP_DIR}/governance_health.out" | tr -d ' ')"
if [[ "${governance_json_bytes}" -gt "${MAX_GOVERNANCE_JSON_BYTES}" ]]; then
  record_failure "governance-health json too large: bytes=${governance_json_bytes} limit=${MAX_GOVERNANCE_JSON_BYTES}"
fi

max_root_lines=0
max_root_file="-"
for rel in AGENTS.md scripts/README.md reports/codex-pilot-report.md reports/weekly-change-report.md; do
  file="${ROOT}/${rel}"
  [[ -f "$file" ]] || continue
  lines="$(wc -l <"$file" | tr -d ' ')"
  if [[ "$lines" -gt "$max_root_lines" ]]; then
    max_root_lines="$lines"
    max_root_file="$rel"
  fi
  if [[ "$lines" -gt "$MAX_ROOT_DOC_LINES" ]]; then
    record_failure "root active doc too large: ${rel} lines=${lines} limit=${MAX_ROOT_DOC_LINES}"
  fi
done

for script in \
  "${ROOT}/scripts/governance-health.sh" \
  "${ROOT}/scripts/governance-review.sh" \
  "${ROOT}/scripts/evidence-bundle.sh" \
  "${ROOT}/scripts/check-token-budget.sh" \
  "${ROOT}/scripts/check-runtime-health.sh" \
  "${ROOT}/scripts/check-runtime-live-footprint.sh" \
  "${ROOT}/scripts/session-coach.sh"; do
  summary_scripts=$((summary_scripts + 1))
  if ! rg -q -- '--summary-json|--format json' "$script"; then
    record_failure "compact summary missing: ${script#$ROOT/}"
  fi
done

status="pass"
if [[ "${#failures[@]}" -gt 0 ]]; then
  status="fail"
fi

if [[ "$SUMMARY_JSON" -eq 1 ]]; then
  printf '{"status":"%s","governance_json_bytes":%s,"governance_json_limit":%s,"max_root_lines":%s,"max_root_file":"%s","summary_scripts":%s,"failures":%s}\n' \
    "$status" \
    "$governance_json_bytes" \
    "$MAX_GOVERNANCE_JSON_BYTES" \
    "$max_root_lines" \
    "$max_root_file" \
    "$summary_scripts" \
    "${#failures[@]}"
else
  echo "[INFO] governance_json_bytes=${governance_json_bytes} limit=${MAX_GOVERNANCE_JSON_BYTES}"
  echo "[INFO] max_root_lines=${max_root_lines} max_root_file=${max_root_file} limit=${MAX_ROOT_DOC_LINES}"
  echo "[INFO] summary_scripts=${summary_scripts}"
  if [[ "${#failures[@]}" -gt 0 ]]; then
    echo "[FAIL] token budget check failed" >&2
    printf '  - %s\n' "${failures[@]}" >&2
    exit 1
  fi
  echo "[PASS] workspace token budget checks passed"
fi

if [[ "${#failures[@]}" -gt 0 ]]; then
  exit 1
fi
