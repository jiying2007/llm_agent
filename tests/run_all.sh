#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERBOSE=0
FAIL_FAST=0
TIMING_JSON=""
MAX_FAILURE_LINES="${LLM_AGENT_TEST_FAILURE_LINES:-80}"
SLOW_THRESHOLD_SEC="${LLM_AGENT_TEST_SLOW_THRESHOLD_SEC:-30}"

usage() {
  cat <<USAGE
Usage:
  tests/run_all.sh [--verbose] [--fail-fast] [--max-failure-lines <n>] [--timing-json <path>] [--slow-threshold-sec <n>]

Runs every root tests/test_*.sh regression exactly once.

Default output is compact and expands only bounded failure logs.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=1
      shift
      ;;
    --fail-fast)
      FAIL_FAST=1
      shift
      ;;
    --max-failure-lines)
      MAX_FAILURE_LINES="${2:-}"
      shift 2
      ;;
    --timing-json)
      TIMING_JSON="${2:-}"
      shift 2
      ;;
    --slow-threshold-sec)
      SLOW_THRESHOLD_SEC="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

[[ "$MAX_FAILURE_LINES" =~ ^[0-9]+$ ]] || {
  echo "[FAIL] --max-failure-lines must be numeric" >&2
  exit 1
}
[[ "$SLOW_THRESHOLD_SEC" =~ ^[0-9]+$ ]] || {
  echo "[FAIL] --slow-threshold-sec must be numeric" >&2
  exit 1
}

TESTS=("${SCRIPT_DIR}"/test_*.sh)
if [[ ! -e "${TESTS[0]}" ]]; then
  echo "[FAIL] no root tests/test_*.sh regressions found" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0
RUN_START_NS="$(date +%s%N)"
declare -a RESULT_NAMES=()
declare -a RESULT_STATUS=()
declare -a RESULT_MS=()

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "$value"
}

write_timing_json() {
  [[ -n "$TIMING_JSON" ]] || return 0
  local run_end_ns elapsed_ms first i
  run_end_ns="$(date +%s%N)"
  elapsed_ms=$(( (run_end_ns - RUN_START_NS) / 1000000 ))
  mkdir -p "$(dirname "$TIMING_JSON")"
  {
    printf '{\n'
    printf '  "schema_version": 1,\n'
    printf '  "suite": "llm-agent-root-regression",\n'
    printf '  "status": %s,\n' "$([[ "$FAIL_COUNT" -gt 0 ]] && json_string fail || json_string pass)"
    printf '  "total": %s,\n' "$TOTAL"
    printf '  "pass": %s,\n' "$PASS_COUNT"
    printf '  "fail": %s,\n' "$FAIL_COUNT"
    printf '  "elapsed_ms": %s,\n' "$elapsed_ms"
    printf '  "slow_threshold_sec": %s,\n' "$SLOW_THRESHOLD_SEC"
    printf '  "tests": [\n'
    first=1
    for i in "${!RESULT_NAMES[@]}"; do
      [[ "$first" -eq 1 ]] || printf ',\n'
      first=0
      printf '    {"name": %s, "status": %s, "elapsed_ms": %s}' \
        "$(json_string "${RESULT_NAMES[$i]}")" \
        "$(json_string "${RESULT_STATUS[$i]}")" \
        "${RESULT_MS[$i]}"
    done
    printf '\n  ],\n'
    printf '  "slow_tests": [\n'
    first=1
    for i in "${!RESULT_NAMES[@]}"; do
      if [[ "${RESULT_MS[$i]}" -ge $((SLOW_THRESHOLD_SEC * 1000)) ]]; then
        [[ "$first" -eq 1 ]] || printf ',\n'
        first=0
        printf '    {"name": %s, "elapsed_ms": %s}' \
          "$(json_string "${RESULT_NAMES[$i]}")" \
          "${RESULT_MS[$i]}"
      fi
    done
    printf '\n  ]\n'
    printf '}\n'
  } >"$TIMING_JSON"
}

print_bounded_log() {
  local label="$1"
  local file="$2"
  if [[ -s "$file" ]]; then
    echo "  ${label} (last ${MAX_FAILURE_LINES} lines):"
    tail -n "$MAX_FAILURE_LINES" "$file" | sed 's/^/    /'
  fi
}

run_test() {
  local path="$1"
  local script name stdout_file stderr_file start_ns end_ns elapsed_ms
  script="$(basename "$path")"
  name="${script%.sh}"
  stdout_file="$TMP_DIR/${name}.stdout"
  stderr_file="$TMP_DIR/${name}.stderr"

  TOTAL=$((TOTAL + 1))
  start_ns="$(date +%s%N)"

  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "=== RUN ${name} ==="
    if bash "$path"; then
      end_ns="$(date +%s%N)"
      elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
      echo "[PASS] ${name}"
      PASS_COUNT=$((PASS_COUNT + 1))
      RESULT_NAMES+=("$name")
      RESULT_STATUS+=("pass")
      RESULT_MS+=("$elapsed_ms")
      return 0
    fi
  else
    if bash "$path" >"$stdout_file" 2>"$stderr_file"; then
      end_ns="$(date +%s%N)"
      elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
      echo "[PASS] ${name}"
      PASS_COUNT=$((PASS_COUNT + 1))
      RESULT_NAMES+=("$name")
      RESULT_STATUS+=("pass")
      RESULT_MS+=("$elapsed_ms")
      return 0
    fi
  fi

  end_ns="$(date +%s%N)"
  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  echo "[FAIL] ${name}" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
  RESULT_NAMES+=("$name")
  RESULT_STATUS+=("fail")
  RESULT_MS+=("$elapsed_ms")
  if [[ "$VERBOSE" -eq 0 ]]; then
    print_bounded_log "stderr" "$stderr_file" >&2
    print_bounded_log "stdout" "$stdout_file" >&2
  fi

  if [[ "$FAIL_FAST" -eq 1 ]]; then
    write_timing_json
    exit 1
  fi
}

for test_path in "${TESTS[@]}"; do
  run_test "$test_path"
done

echo "[SUMMARY] tests=${TOTAL} pass=${PASS_COUNT} fail=${FAIL_COUNT}"
write_timing_json

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

echo "All root tests passed"
