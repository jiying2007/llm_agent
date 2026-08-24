#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_JSON=0
MAX_GOVERNANCE_JSON_BYTES=3500
MAX_ROOT_DOC_LINES=520
MAX_ROOT_AGENTS_BYTES=4000
MAX_ADK_AGENTS_BYTES=3500
MAX_GLOBAL_AGENTS_BYTES=4500
MAX_CUMULATIVE_AGENTS_BYTES=12000
SOFT_ROOT_AGENTS_BYTES=3400
SOFT_ADK_AGENTS_BYTES=2975
SOFT_GLOBAL_AGENTS_BYTES=3825
SOFT_CUMULATIVE_AGENTS_BYTES=10200
GLOBAL_AGENTS=""

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
    --global-agents)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "[FAIL] --global-agents requires PATH" >&2
        exit 1
      fi
      GLOBAL_AGENTS="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-token-budget.sh [root] [--summary-json] [--global-agents PATH]

Checks workspace-level token budget:
  - adk token-budget gate passes.
  - governance-health JSON remains compact.
  - active root docs/reports stay below hard line budgets.
  - root, ADK and optional global AGENTS stay within per-layer and cumulative byte budgets.
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
warnings=()
summary_scripts=0
record_failure() {
  failures+=("$1")
}

record_warning() {
  warnings+=("$1")
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

if [[ -z "$GLOBAL_AGENTS" && -f "$HOME/codex/src/codex-home/AGENTS.md" ]]; then
  GLOBAL_AGENTS="$HOME/codex/src/codex-home/AGENTS.md"
fi
root_agents_bytes="$(wc -c <"${ROOT}/AGENTS.md" | tr -d ' ')"
adk_agents_bytes="$(wc -c <"${ROOT}/agent-dev-kit/AGENTS.md" | tr -d ' ')"
global_agents_bytes=0
global_agents_status="not-found"
if [[ -n "$GLOBAL_AGENTS" && -f "$GLOBAL_AGENTS" ]]; then
  global_agents_bytes="$(wc -c <"$GLOBAL_AGENTS" | tr -d ' ')"
  global_agents_status="checked"
elif [[ -n "$GLOBAL_AGENTS" ]]; then
  record_failure "global AGENTS not found: $GLOBAL_AGENTS"
fi
cumulative_agents_bytes=$((root_agents_bytes + adk_agents_bytes + global_agents_bytes))
[[ "$root_agents_bytes" -le "$MAX_ROOT_AGENTS_BYTES" ]] || record_failure "root AGENTS too large: bytes=${root_agents_bytes} limit=${MAX_ROOT_AGENTS_BYTES}"
[[ "$adk_agents_bytes" -le "$MAX_ADK_AGENTS_BYTES" ]] || record_failure "ADK AGENTS too large: bytes=${adk_agents_bytes} limit=${MAX_ADK_AGENTS_BYTES}"
[[ "$global_agents_bytes" -le "$MAX_GLOBAL_AGENTS_BYTES" ]] || record_failure "global AGENTS too large: bytes=${global_agents_bytes} limit=${MAX_GLOBAL_AGENTS_BYTES}"
[[ "$cumulative_agents_bytes" -le "$MAX_CUMULATIVE_AGENTS_BYTES" ]] || record_failure "cumulative AGENTS too large: bytes=${cumulative_agents_bytes} limit=${MAX_CUMULATIVE_AGENTS_BYTES}"
[[ "$root_agents_bytes" -le "$SOFT_ROOT_AGENTS_BYTES" ]] || record_warning "root AGENTS above 85% soft budget: bytes=${root_agents_bytes} soft=${SOFT_ROOT_AGENTS_BYTES}"
[[ "$adk_agents_bytes" -le "$SOFT_ADK_AGENTS_BYTES" ]] || record_warning "ADK AGENTS above 85% soft budget: bytes=${adk_agents_bytes} soft=${SOFT_ADK_AGENTS_BYTES}"
[[ "$global_agents_bytes" -le "$SOFT_GLOBAL_AGENTS_BYTES" ]] || record_warning "global AGENTS above 85% soft budget: bytes=${global_agents_bytes} soft=${SOFT_GLOBAL_AGENTS_BYTES}"
[[ "$cumulative_agents_bytes" -le "$SOFT_CUMULATIVE_AGENTS_BYTES" ]] || record_warning "cumulative AGENTS above 85% soft budget: bytes=${cumulative_agents_bytes} soft=${SOFT_CUMULATIVE_AGENTS_BYTES}"

root_agents_estimated_tokens=$(((root_agents_bytes + 3) / 4))
adk_agents_estimated_tokens=$(((adk_agents_bytes + 3) / 4))
global_agents_estimated_tokens=$(((global_agents_bytes + 3) / 4))
cumulative_agents_estimated_tokens=$(((cumulative_agents_bytes + 3) / 4))

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
  "${ROOT}/scripts/check-runtime-live-footprint.sh"; do
  summary_scripts=$((summary_scripts + 1))
  if ! rg -q -- '--summary-json|--format json' "$script"; then
    record_failure "compact summary missing: ${script#$ROOT/}"
  fi
done

status="pass"
if [[ "${#failures[@]}" -gt 0 ]]; then
  status="fail"
fi
budget_status="within-soft-limit"
[[ "${#warnings[@]}" -eq 0 ]] || budget_status="warning"
[[ "${#failures[@]}" -eq 0 ]] || budget_status="hard-limit-failed"

if [[ "$SUMMARY_JSON" -eq 1 ]]; then
  printf '{"status":"%s","budget_status":"%s","estimate_method":"utf8-bytes-ceil-div-4","governance_json_bytes":%s,"governance_json_limit":%s,"root_agents_bytes":%s,"root_agents_soft_limit":%s,"root_agents_estimated_tokens":%s,"adk_agents_bytes":%s,"adk_agents_soft_limit":%s,"adk_agents_estimated_tokens":%s,"global_agents_bytes":%s,"global_agents_soft_limit":%s,"global_agents_estimated_tokens":%s,"global_agents_status":"%s","cumulative_agents_bytes":%s,"cumulative_agents_soft_limit":%s,"cumulative_agents_limit":%s,"cumulative_agents_estimated_tokens":%s,"max_root_lines":%s,"max_root_file":"%s","summary_scripts":%s,"warnings":%s,"failures":%s}\n' \
    "$status" \
    "$budget_status" \
    "$governance_json_bytes" \
    "$MAX_GOVERNANCE_JSON_BYTES" \
    "$root_agents_bytes" \
    "$SOFT_ROOT_AGENTS_BYTES" \
    "$root_agents_estimated_tokens" \
    "$adk_agents_bytes" \
    "$SOFT_ADK_AGENTS_BYTES" \
    "$adk_agents_estimated_tokens" \
    "$global_agents_bytes" \
    "$SOFT_GLOBAL_AGENTS_BYTES" \
    "$global_agents_estimated_tokens" \
    "$global_agents_status" \
    "$cumulative_agents_bytes" \
    "$SOFT_CUMULATIVE_AGENTS_BYTES" \
    "$MAX_CUMULATIVE_AGENTS_BYTES" \
    "$cumulative_agents_estimated_tokens" \
    "$max_root_lines" \
    "$max_root_file" \
    "$summary_scripts" \
    "${#warnings[@]}" \
    "${#failures[@]}"
else
  echo "[INFO] governance_json_bytes=${governance_json_bytes} limit=${MAX_GOVERNANCE_JSON_BYTES}"
  echo "[INFO] agents_bytes root=${root_agents_bytes}/${SOFT_ROOT_AGENTS_BYTES}/${MAX_ROOT_AGENTS_BYTES} adk=${adk_agents_bytes}/${SOFT_ADK_AGENTS_BYTES}/${MAX_ADK_AGENTS_BYTES} global=${global_agents_bytes}/${SOFT_GLOBAL_AGENTS_BYTES}/${MAX_GLOBAL_AGENTS_BYTES} cumulative=${cumulative_agents_bytes}/${SOFT_CUMULATIVE_AGENTS_BYTES}/${MAX_CUMULATIVE_AGENTS_BYTES} budget_status=${budget_status}"
  if [[ "${#warnings[@]}" -gt 0 ]]; then
    printf '[WARN] %s\n' "${warnings[@]}" >&2
  fi
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
