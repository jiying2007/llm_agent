#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SUMMARY_JSON=0

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
usage: scripts/check-architecture-reports.sh [root] [--summary-json]

Checks reports/architecture target architecture reports for required sections,
operating model, landing protocol, implementation tasks, evidence, rejection
records, and source-to-live boundary language.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

python3 - "$ROOT" "$SUMMARY_JSON" <<'PY'
import glob
import json
import os
import re
import sys

root, summary_json = sys.argv[1:3]
summary_json = summary_json == "1"
arch_dir = os.path.join(root, "reports", "architecture")
readme = os.path.join(arch_dir, "README.md")
failures = []


def rel(path):
    return os.path.relpath(path, root)


def fail(message):
    failures.append(message)


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def has_heading(content, heading):
    return re.search(rf"^{re.escape(heading)}\s*$", content, re.MULTILINE) is not None


def section(content, heading):
    match = re.search(rf"^{re.escape(heading)}\s*$", content, re.MULTILINE)
    if not match:
        return ""
    start = match.end()
    next_heading = re.search(r"^##\s+", content[start:], re.MULTILINE)
    if next_heading:
        return content[start:start + next_heading.start()]
    return content[start:]


if not os.path.isdir(arch_dir):
    fail("reports/architecture directory missing")
if not os.path.isfile(readme):
    fail("reports/architecture/README.md missing")
else:
    readme_text = read(readme)
    for token in ("必填内容", "Evidence Index", "source-to-live", "~/.codex"):
        if token not in readme_text:
            fail(f"{rel(readme)} missing required token: {token}")

reports = []
if os.path.isdir(arch_dir):
    reports = [
        path for path in sorted(glob.glob(os.path.join(arch_dir, "*.md")))
        if os.path.basename(path) != "README.md"
    ]
if not reports:
    fail("reports/architecture must contain at least one architecture report")

required_headings = [
    "## Summary",
    "## Scope",
    "## Current Architecture Map",
    "## Target Architecture",
    "## Responsibility Boundary",
    "## Architecture Operating Model",
    "## SSOT Matrix",
    "## Issue Map",
    "## Landing Protocol",
    "## Phase Roadmap",
    "## Implementation Tasks",
    "## Verification Gates",
    "## Rejected Options",
    "## Evidence Index",
    "## Goal Closure State",
]

required_goal_fields = [
    "goal_statement:",
    "completion_claim:",
    "required_evidence:",
    "claimant:",
    "verifier:",
    "open_items:",
    "retry_budget:",
    "staleness_threshold:",
    "heartbeat:",
    "stop_condition:",
]

for report in reports:
    content = read(report)
    label = rel(report)
    if not content.startswith("# "):
        fail(f"{label} must start with a level-1 title")
    for heading in required_headings:
        if not has_heading(content, heading):
            fail(f"{label} missing heading: {heading}")

    for token in ("llm_agent", "agent-dev-kit", "source-to-live", "~/.codex"):
        if token not in content:
            fail(f"{label} missing boundary token: {token}")

    for token in ("source-staged", "source-committed", "dry-run-verified", "live-applied", "knowledge-promoted"):
        if token not in content:
            fail(f"{label} missing landing protocol token: {token}")

    for priority in ("P0", "P1", "P2"):
        if priority not in content:
            fail(f"{label} missing implementation priority: {priority}")

    issue_map = section(content, "## Issue Map")
    if "| ID | Severity | Finding | Evidence | Action |" not in issue_map:
        fail(f"{label} Issue Map table header is missing or malformed")

    tasks = section(content, "## Implementation Tasks")
    if "| ID | Priority | Task | Files | Stop Condition | Verification |" not in tasks:
        fail(f"{label} Implementation Tasks table header is missing or malformed")

    rejected = section(content, "## Rejected Options")
    if "| Option | Decision | Reason |" not in rejected:
        fail(f"{label} Rejected Options table header is missing or malformed")
    if "reject" not in rejected.lower():
        fail(f"{label} Rejected Options must include at least one reject decision")

    evidence = section(content, "## Evidence Index")
    if "| Command | Exit Code | Result Summary | Layer |" not in evidence:
        fail(f"{label} Evidence Index table header is missing or malformed")
    if not re.search(r"^\|\s*`rtk\s+", evidence, re.MULTILINE):
        fail(f"{label} Evidence Index must include at least one rtk command")
    if not re.search(r"\|\s*0\s*\|", evidence):
        fail(f"{label} Evidence Index must include at least one passing command exit code")
    if not (re.search(r"\|\s*[1-9][0-9]*\s*\|", evidence) or "before fix" in evidence.lower()):
        fail(f"{label} Evidence Index must include a negative or before-fix evidence row")

    closure = section(content, "## Goal Closure State")
    for field in required_goal_fields:
        if field not in closure:
            fail(f"{label} Goal Closure State missing field: {field}")

status = "pass" if not failures else "fail"
if summary_json:
    print(json.dumps({
        "status": status,
        "reports": len(reports),
        "failures": failures,
    }, ensure_ascii=False, separators=(",", ":")))
else:
    if failures:
        for item in failures:
            print(f"[FAIL] {item}", file=sys.stderr)
    else:
        print(f"[PASS] architecture reports ready: reports={len(reports)}")

if failures:
    sys.exit(1)
PY
