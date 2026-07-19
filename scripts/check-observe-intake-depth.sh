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
  decision = trim($9)
  status = trim($10)
  evidence = trim($12)
  row = $0

  if (decision == "observe" && status == "done") {
    checked++

    has_agent = index(evidence, "agent-dev-kit/agents/") > 0
    has_skill = index(evidence, "agent-dev-kit/skills/") > 0 || index(evidence, "agent-dev-kit/optional-skills/") > 0
    has_workflow = index(evidence, "agent-dev-kit/workflows/") > 0 || index(evidence, "agent-dev-kit/docs/runbooks/") > 0 || index(evidence, "agent-dev-kit/docs/workflows.md") > 0 || index(evidence, "agent-dev-kit/docs/agent-skill-catalog.md") > 0
    has_report = index(evidence, "reports/") > 0
    has_pack_report = index(evidence, "reports/observe-secondary-intake-packages") > 0 || index(evidence, "reports/post-freeze-kickoff-") > 0

    if (!has_agent || !has_skill || !has_workflow) {
      miss = ""
      if (!has_agent) miss = miss "A"
      if (!has_skill) miss = miss "S"
      if (!has_workflow) miss = miss "W"
      printf("[FAIL] observe row missing required layers (%s):\n%s\n", miss, row) > "/dev/stderr"
      failed = 1
    }

    if (!has_report) {
      printf("[FAIL] observe row missing regression/report evidence:\n%s\n", row) > "/dev/stderr"
      failed = 1
    }

    if (!has_pack_report) {
      printf("[FAIL] observe row missing intake package report evidence:\n%s\n", row) > "/dev/stderr"
      failed = 1
    }
  }
}

END {
  if (checked == 0) {
    print "[PASS] no observe+done rows found (observe backlog cleared)"
    exit 0
  }

  if (failed) {
    exit 3
  }

  printf("[PASS] observe intake depth checks passed (%d rows)\n", checked)
}
' "${MATRIX}"
