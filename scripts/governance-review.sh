#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FORMAT="markdown"
OUT=""
MAX_SUMMARY_CHARS=360

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

usage() {
  cat <<USAGE
usage: scripts/governance-review.sh [root] [--format markdown|json] [--out <path>] [--max-summary-chars <n>]

Generates a report-only governance review for llm_agent and agent-dev-kit.
It calls existing gates and never syncs subrepos, edits phase-gate.env, applies
to ~/.codex, commits, pushes, or deletes files. The command only writes when
--out is provided.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="${2:-}"
      shift 2
      ;;
    --out)
      OUT="${2:-}"
      shift 2
      ;;
    --max-summary-chars)
      MAX_SUMMARY_CHARS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "${FORMAT}" in
  markdown|json)
    ;;
  *)
    echo "[FAIL] unsupported format: ${FORMAT}" >&2
    exit 1
    ;;
esac

[[ "${MAX_SUMMARY_CHARS}" =~ ^[0-9]+$ ]] || {
  echo "[FAIL] --max-summary-chars must be numeric" >&2
  exit 1
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

run_capture() {
  local name="$1"
  shift
  local rc=0
  set +e
  "$@" >"${TMP_DIR}/${name}.out" 2>&1
  rc=$?
  set -e
  printf '%s' "${rc}" >"${TMP_DIR}/${name}.rc"
}

compact_file() {
  local file="$1"
  local summary
  summary="$(tr '\n' ' ' <"${file}" | sed 's/[[:space:]][[:space:]]*/ /g' | cut -c "1-${MAX_SUMMARY_CHARS}")"
  if [[ "$(wc -c <"${file}" | tr -d ' ')" -gt "${MAX_SUMMARY_CHARS}" ]]; then
    summary="${summary}..."
  fi
  printf '%s' "${summary}"
}

value_for() {
  local key="$1"
  awk -F '=' -v key="${key}" '$1 == key {print $2; exit}' "${ROOT}/subrepos/phase-gate.env"
}

run_capture adk_lock "${ROOT}/scripts/check-adk-lock.sh" "${ROOT}"
run_capture phase_gate "${ROOT}/scripts/check-phase-gate.sh" "${ROOT}" --summary-json
run_capture subrepo_state "${ROOT}/scripts/check-subrepo-state.sh" "${ROOT}" --summary-json
run_capture governance_health "${ROOT}/scripts/governance-health.sh" "${ROOT}" --format json --max-summary-chars 180
run_capture evidence_bundle "${ROOT}/scripts/evidence-bundle.sh" "${ROOT}" --format json --max-summary-chars 240
run_capture runtime_live "${ROOT}/scripts/check-runtime-live-footprint.sh" "${ROOT}" --summary-json --strict

generated_at="$(date -Iseconds)"
root_head="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || printf '-')"
adk_head="$(git -C "${ROOT}/agent-dev-kit" rev-parse --short HEAD 2>/dev/null || printf '-')"
phase="$(value_for phase || true)"
allow_upstream_sync="$(value_for allow_upstream_sync || true)"
last_live_refresh="$(value_for last_live_refresh || true)"
next_review_by="$(value_for next_review_by || true)"

status="pass"
reasons=()
for name in adk_lock phase_gate subrepo_state governance_health evidence_bundle runtime_live; do
  if [[ "$(cat "${TMP_DIR}/${name}.rc")" -ne 0 ]]; then
    status="needs-fix"
    reasons+=("${name} failed")
  fi
done

if rg -q '"unexpected_dirty":[1-9]' "${TMP_DIR}/subrepo_state.out"; then
  status="needs-fix"
  reasons+=("unexpected dirty subrepo detected")
fi
if rg -q '"stale_baseline":[1-9]' "${TMP_DIR}/subrepo_state.out"; then
  status="needs-fix"
  reasons+=("dirty baseline is stale")
fi
if rg -q '"missing_required":[1-9]' "${TMP_DIR}/runtime_live.out"; then
  status="needs-fix"
  reasons+=("required runtime live ADK asset missing")
fi
if rg -q '"status":"needs-fix"|"status": "needs-fix"|"status":"fail"|"status": "fail"' "${TMP_DIR}/evidence_bundle.out"; then
  status="needs-fix"
  reasons+=("evidence bundle is not pass")
fi
if [[ "$(cat "${TMP_DIR}/phase_gate.rc")" -eq 0 && -n "${next_review_by}" ]]; then
  today="$(date +%F)"
  if [[ "${next_review_by}" < "${today}" ]]; then
    status="needs-fix"
    reasons+=("phase gate review date expired")
  fi
fi
if [[ "${#reasons[@]}" -eq 0 ]]; then
  reasons+=("all report-only governance checks passed")
fi

last_live_refresh_decision="not-recommended"
if [[ "$(cat "${TMP_DIR}/runtime_live.rc")" -eq 0 ]] && rg -q '"missing_required":0' "${TMP_DIR}/runtime_live.out"; then
  last_live_refresh_decision="manual-review-required"
fi
next_review_decision="recommended"
if [[ "${status}" != "pass" ]]; then
  next_review_decision="not-recommended-until-needs-fix-cleared"
fi

write_json() {
  printf '{\n'
  printf '  "generated_at": %s,\n' "$(json_string "${generated_at}")"
  printf '  "status": %s,\n' "$(json_string "${status}")"
  printf '  "root_head": %s,\n' "$(json_string "${root_head}")"
  printf '  "agent_dev_kit_head": %s,\n' "$(json_string "${adk_head}")"
  printf '  "phase": %s,\n' "$(json_string "${phase}")"
  printf '  "allow_upstream_sync": %s,\n' "$(json_string "${allow_upstream_sync}")"
  printf '  "last_live_refresh": %s,\n' "$(json_string "${last_live_refresh}")"
  printf '  "next_review_by": %s,\n' "$(json_string "${next_review_by}")"
  printf '  "decisions": {"last_live_refresh_update": %s, "next_review_by_update": %s},\n' \
    "$(json_string "${last_live_refresh_decision}")" \
    "$(json_string "${next_review_decision}")"
  printf '  "reasons": [\n'
  local first=1
  local reason
  for reason in "${reasons[@]}"; do
    [[ "${first}" -eq 1 ]] || printf ',\n'
    first=0
    printf '    %s' "$(json_string "${reason}")"
  done
  printf '\n  ],\n'
  printf '  "checks": [\n'
  first=1
  local name
  for name in adk_lock phase_gate subrepo_state governance_health evidence_bundle runtime_live; do
    [[ "${first}" -eq 1 ]] || printf ',\n'
    first=0
    printf '    {"name": %s, "exit_code": %s, "summary": %s}' \
      "$(json_string "${name}")" \
      "$(cat "${TMP_DIR}/${name}.rc")" \
      "$(json_string "$(compact_file "${TMP_DIR}/${name}.out")")"
  done
  printf '\n  ]\n'
  printf '}\n'
}

write_markdown() {
  cat <<MD
# llm_agent Governance Review

## Summary

- generated_at: ${generated_at}
- status: ${status}
- root_head: ${root_head}
- agent_dev_kit_head: ${adk_head}
- mode: report-only

## Baseline

| Field | Value |
|---|---|
| phase | ${phase:-} |
| allow_upstream_sync | ${allow_upstream_sync:-} |
| last_live_refresh | ${last_live_refresh:-} |
| next_review_by | ${next_review_by:-} |

## Evidence Index

| Check | Exit Code | Summary |
|---|---:|---|
| adk_lock | $(cat "${TMP_DIR}/adk_lock.rc") | $(compact_file "${TMP_DIR}/adk_lock.out") |
| phase_gate | $(cat "${TMP_DIR}/phase_gate.rc") | $(compact_file "${TMP_DIR}/phase_gate.out") |
| subrepo_state | $(cat "${TMP_DIR}/subrepo_state.rc") | $(compact_file "${TMP_DIR}/subrepo_state.out") |
| governance_health | $(cat "${TMP_DIR}/governance_health.rc") | $(compact_file "${TMP_DIR}/governance_health.out") |
| evidence_bundle | $(cat "${TMP_DIR}/evidence_bundle.rc") | $(compact_file "${TMP_DIR}/evidence_bundle.out") |
| runtime_live | $(cat "${TMP_DIR}/runtime_live.rc") | $(compact_file "${TMP_DIR}/runtime_live.out") |

## Decisions

- last_live_refresh_update: ${last_live_refresh_decision}
- next_review_by_update: ${next_review_decision}

## Residual Risk

MD
  local reason
  for reason in "${reasons[@]}"; do
    echo "- ${reason}"
  done
  cat <<MD
- Production-field readiness still requires real flashing/readback, HIL, OTA rollback, boot logs, and field package evidence before any production-ready claim.
- This report does not sync reference subrepos, update phase-gate.env, apply to ~/.codex, commit, push, or delete files.
MD
}

if [[ -n "${OUT}" ]]; then
  mkdir -p "$(dirname "${OUT}")"
  if [[ "${FORMAT}" == "json" ]]; then
    write_json >"${OUT}"
  else
    write_markdown >"${OUT}"
  fi
  echo "[PASS] governance review written: ${OUT}"
else
  if [[ "${FORMAT}" == "json" ]]; then
    write_json
  else
    write_markdown
  fi
fi
