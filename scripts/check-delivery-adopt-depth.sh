#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"

if [[ ! -f "${MATRIX}" ]]; then
  echo "[FAIL] adoption matrix missing: ${MATRIX}" >&2
  exit 1
fi

awk -F'|' '
function trim(s) {
  gsub(/^[ \t]+|[ \t]+$/, "", s)
  return s
}

/^\| [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] \|/ {
  category = trim($4)
  decision = trim($9)
  status = trim($10)
  evidence = trim($12)
  row = $0

  if (category == "delivery" && decision == "adopt" && status == "done") {
    checked++

    has_agent = index(evidence, "global-dev-kit/agents/") > 0
    has_skill = index(evidence, "global-dev-kit/skills/") > 0 || index(evidence, "global-dev-kit/optional-skills/") > 0
    has_workflow = index(evidence, "global-dev-kit/docs/runbooks/") > 0 || index(evidence, "global-dev-kit/docs/workflows.md") > 0
    has_report = index(evidence, "reports/") > 0
    has_intake = index(evidence, "reports/observe-secondary-intake-packages-wave") > 0 || index(evidence, "reports/post-freeze-kickoff-") > 0

    if (!has_agent || !has_skill || !has_workflow) {
      miss = ""
      if (!has_agent) miss = miss "A"
      if (!has_skill) miss = miss "S"
      if (!has_workflow) miss = miss "W"
      printf("[FAIL] delivery adopt row missing required layers (%s):\n%s\n", miss, row) > "/dev/stderr"
      failed = 1
    }

    if (!has_report) {
      printf("[FAIL] delivery adopt row missing report evidence:\n%s\n", row) > "/dev/stderr"
      failed = 1
    }

    if (!has_intake) {
      printf("[FAIL] delivery adopt row missing intake wave report evidence:\n%s\n", row) > "/dev/stderr"
      failed = 1
    }
  }
}

END {
  if (checked == 0) {
    print "[FAIL] no delivery+adopt+done rows checked in adoption-matrix" > "/dev/stderr"
    exit 2
  }

  if (failed) {
    exit 3
  }

  printf("[PASS] delivery adopt depth checks passed (%d rows)\n", checked)
}
' "${MATRIX}"
