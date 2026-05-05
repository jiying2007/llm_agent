#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────┐
# │ DEPRECATED: Use check-codex-pilot.sh <root> coverage instead.   │
# │ This script will be removed in a future release.                 │
# └──────────────────────────────────────────────────────────────────┘
echo "[WARN] DEPRECATED: use check-codex-pilot.sh <root> coverage" >&2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/check-codex-pilot.sh" "$@" coverage

# ── Original logic below (unreachable) ──────────────────────────────
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPORT="${ROOT}/reports/codex-pilot-report.md"

if [[ ! -f "${REPORT}" ]]; then
  echo "[FAIL] codex pilot report missing: ${REPORT}" >&2
  exit 1
fi

field_value() {
  local key="$1"
  awk -v key="${key}" '
    $0 ~ "^- " key ":" {
      value=$0
      sub("^- " key ":[ ]*", "", value)
      print value
      exit
    }
  ' "${REPORT}"
}

require_field() {
  local key="$1"
  local value
  value="$(field_value "${key}")"
  if [[ -z "${value}" ]]; then
    echo "[FAIL] pilot coverage field missing: ${key}" >&2
    exit 1
  fi
}

section_contains() {
  local header="$1"
  local pattern="$2"
  awk -v header="${header}" -v pattern="${pattern}" '
    $0 == header {in_section=1; next}
    in_section && ($0 ~ "^## 试跑场景" || $0 ~ "^## 下一步") {exit}
    in_section && index($0, pattern) > 0 {found=1; exit}
    END {exit found ? 0 : 1}
  ' "${REPORT}"
}

require_section_contains() {
  local header="$1"
  local pattern="$2"
  if ! section_contains "${header}" "${pattern}"; then
    echo "[FAIL] pilot section missing required evidence: header=${header} pattern=${pattern}" >&2
    exit 1
  fi
}

require_pilot_section() {
  local key="$1"
  local title="$2"
  local header="## ${title}（已完成）"

  rg -q --fixed-strings -- "${header}" "${REPORT}" || {
    echo "[FAIL] pilot full coverage section missing: ${header}" >&2
    exit 1
  }

  require_section_contains "${header}" "scenario_key: ${key}"
  require_section_contains "${header}" "[artifact:ImplementationPlan]"
  require_section_contains "${header}" "[artifact:ReviewReport]"
  require_section_contains "${header}" "[artifact:TestReport]"
  require_section_contains "${header}" "## Evidence Index（命令级）"
  require_section_contains "${header}" "| Command | Exit Code | Result Summary | Evidence Path | Layer | Related Artifact |"
  require_section_contains "${header}" "| 0 |"
}

for key in \
  pilot_full_coverage_ready \
  pilot_feature_delivery_done \
  pilot_bugfix_delivery_done \
  pilot_refactor_hardening_done \
  pilot_release_hardening_done \
  pilot_team_handoff_done \
  pilot_upstream_intake_done; do
  require_field "${key}"
done

if [[ "$(field_value pilot_full_coverage_ready)" == "yes" ]]; then
  while IFS='|' read -r key title; do
    if [[ "$(field_value "${key}")" != "yes" ]]; then
      echo "[FAIL] pilot full coverage requires ${key}=yes" >&2
      exit 1
    fi
    require_pilot_section "${key}" "${title}"
  done <<'PILOTS'
pilot_feature_delivery_done|试跑场景 C：新功能交付
pilot_bugfix_delivery_done|试跑场景 D：缺陷修复
pilot_refactor_hardening_done|试跑场景 E：重构压实
pilot_release_hardening_done|试跑场景 F：发布收口
pilot_team_handoff_done|试跑场景 G：团队交接
pilot_upstream_intake_done|试跑场景 H：上游吸收
PILOTS
  echo "[PASS] codex pilot full coverage ready"
else
  echo "[PASS] codex pilot coverage fields ready (full coverage not enforced)"
fi
