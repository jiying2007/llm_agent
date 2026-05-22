#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SUMMARY_JSON=0
DEEP=0
THREAD_LONG=0
CTX_PRESSURE=0

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
    --deep)
      DEEP=1
      shift
      ;;
    --thread-long)
      THREAD_LONG=1
      shift
      ;;
    --ctx-pressure)
      CTX_PRESSURE=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/session-coach.sh [root] [--summary-json] [--deep] [--thread-long] [--ctx-pressure]

Prints a compact next-action reminder for long sessions, token pressure and
asset changes. Use --deep to include token-budget and Codex live checks.
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

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

capture() {
  local name="$1"
  shift
  local rc=0
  set +e
  "$@" >"${TMP_DIR}/${name}.out" 2>&1
  rc=$?
  set -e
  printf "%s" "${rc}" >"${TMP_DIR}/${name}.rc"
}

signals=()
add_signal() {
  signals+=("$1")
}

dirty_count="$(cd "${ROOT}" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
asset_dirty_count="$(cd "${ROOT}" && git status --porcelain 2>/dev/null | rg -c '(^.. AGENTS\.md|/AGENTS\.md$|SKILL\.md$|manifest\.yaml$|^.. scripts/|^.. agent-dev-kit/scripts/|^.. docs/|^.. agent-dev-kit/docs/)' || true)"

[[ "${dirty_count}" -gt 0 ]] && add_signal "DIRTY_WORKTREE"
[[ "${asset_dirty_count}" -gt 0 ]] && add_signal "ASSET_OR_DOC_CHANGE"

case "${CODEX_THREAD_LONG:-}" in
  1|true|yes|HOT|CRITICAL) THREAD_LONG=1 ;;
esac
case "${CODEX_CTX_PRESSURE:-${CODEX_USAGE_STATE:-}}" in
  1|true|yes|HOT|CRITICAL) CTX_PRESSURE=1 ;;
esac

[[ "${THREAD_LONG}" -eq 1 ]] && add_signal "THREAD_LONG"
[[ "${CTX_PRESSURE}" -eq 1 ]] && add_signal "CTX_PRESSURE"

if [[ "${DEEP}" -eq 1 ]]; then
  capture token_budget "${ROOT}/scripts/check-token-budget.sh" "${ROOT}" --summary-json
  capture codex_live "${ROOT}/scripts/check-codex-adk-live.sh" "${ROOT}" --summary-json
  if [[ "$(cat "${TMP_DIR}/token_budget.rc")" -ne 0 ]]; then
    add_signal "TOKEN_BUDGET_FAIL"
  fi
  if rg -q '"missing_required":[1-9]' "${TMP_DIR}/codex_live.out"; then
    add_signal "CODEX_LIVE_GAP"
  fi
fi

phase="steady"
priority="low"
top_action="继续当前任务；收尾前运行定向验证"

if [[ "${THREAD_LONG}" -eq 1 || "${CTX_PRESSURE}" -eq 1 ]]; then
  phase="handoff"
  priority="high"
  top_action="执行 context-preflight -> session-wrap -> archive-note -> memory-curator --dry-run -> 新会话"
elif [[ "${asset_dirty_count}" -gt 0 ]]; then
  phase="closeout"
  priority="medium"
  top_action="先跑 token-budget、workspace-entrypoints 和相关回归，再提交或继续改动"
elif [[ "${dirty_count}" -gt 0 ]]; then
  phase="implementation"
  priority="medium"
  top_action="整理 dirty diff，区分本次改动与既有子仓状态"
fi

status="pass"
if [[ "${priority}" != "low" ]]; then
  status="attention"
fi

if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
  printf '{"status":"%s","phase":"%s","priority":"%s","dirty_count":%s,"asset_dirty_count":%s,"signals":[' \
    "${status}" "${phase}" "${priority}" "${dirty_count}" "${asset_dirty_count}"
  first=1
  for signal in "${signals[@]}"; do
    [[ "${first}" -eq 1 ]] || printf ','
    first=0
    printf '%s' "$(json_string "${signal}")"
  done
  printf '],"top_action":%s}\n' "$(json_string "${top_action}")"
else
  echo "[INFO] phase=${phase} priority=${priority} dirty=${dirty_count} asset_dirty=${asset_dirty_count}"
  if [[ "${#signals[@]}" -gt 0 ]]; then
    printf '[INFO] signals=%s\n' "$(IFS=,; echo "${signals[*]}")"
  fi
  echo "[ACTION] ${top_action}"
fi
