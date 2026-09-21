#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${1:-$SCRIPT_ROOT}"
SUMMARY_JSON=0
WORKTREE_INTEGRATION=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  shift
fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    --worktree-integration)
      WORKTREE_INTEGRATION=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
usage: scripts/check-current-status-consistency.sh [root] [--summary-json] [--worktree-integration]

Validates the canonical current-source projection, exact ADK identity, Product M5
scope, separate long-term-asset qualification state, and current architecture
report selection. Historical product qualification is never promoted to the
current source by this checker.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

export PYTHONPATH="$SCRIPT_ROOT${PYTHONPATH:+:$PYTHONPATH}"

python3 - "$ROOT" "$SUMMARY_JSON" "$WORKTREE_INTEGRATION" <<'PY'
from __future__ import annotations

import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

from tools.control_plane.status_projection import project

root = Path(sys.argv[1]).resolve()
summary_json = sys.argv[2] == "1"
worktree_integration = sys.argv[3] == "1"
failures: list[str] = []


def read_json(relative: str) -> dict:
    path = root / relative
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        failures.append(f"invalid JSON {relative}: {exc}")
        return {}
    if not isinstance(value, dict):
        failures.append(f"JSON root must be an object: {relative}")
        return {}
    return value


def read_lock() -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        lines = (root / "adk.lock").read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        failures.append(f"cannot read adk.lock: {exc}")
        return values
    for line in lines:
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def git(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(cwd or root), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


try:
    projection = project(root, dt.date.today())
except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
    projection = {"status": "fail", "error": str(exc)}
    failures.append(f"current source projection failed: {exc}")

if projection.get("status") != "pass":
    failures.append("current source projection is not pass")
if (projection.get("source") or {}).get("pin_consistent") is not True:
    failures.append("current ADK gitlink/lock identity is inconsistent")
if (projection.get("current_projection") or {}).get("consistent") is not True:
    failures.append("generated current-status projection is inconsistent")

lock = read_lock()
scorecard = read_json("manifests/product_maturity_scorecard.json")
lta = read_json("manifests/long_term_asset_qualification.json")
registry = read_json("manifests/report_registry.json")

overall = scorecard.get("overall")
software_m5 = scorecard.get("software_m5")
if not isinstance(overall, dict):
    failures.append("product maturity overall contract is missing")
else:
    expected = {
        "level": "M5",
        "status": "production-qualified",
        "terminal_mature": True,
        "terminal_scope": "product_maturity_v5",
        "field_status": "production_qualified",
        "long_term_asset_status": "qualification_pending",
        "long_term_asset_contract": "manifests/long_term_asset_qualification.json",
    }
    for key, value in expected.items():
        if overall.get(key) != value:
            failures.append(f"product maturity overall.{key} must be {value!r}")

if not isinstance(software_m5, dict) or software_m5.get("certified") is not True:
    failures.append("Product M5 software certification must remain pass")

rules = lta.get("rules")
terminal = lta.get("terminal")
lifecycle = lta.get("lifecycle")
if not isinstance(rules, dict) or rules.get("product_maturity_does_not_imply_long_term_terminal") is not True:
    failures.append("LTA contract must separate Product M5 from long-term terminal qualification")
if not isinstance(terminal, dict):
    failures.append("LTA terminal contract is missing")
else:
    if terminal.get("qualified") is not False or terminal.get("status") != "qualification_pending":
        failures.append("LTA terminal state must remain qualification_pending")
    if set(terminal.get("pending_requirements") or []) != {"LTA-04"}:
        failures.append("LTA pending requirements must contain only LTA-04; R2 is delegated observation")

agent_lifecycle = lifecycle.get("agent_dev_kit") if isinstance(lifecycle, dict) else None
if not isinstance(agent_lifecycle, dict):
    failures.append("LTA agent_dev_kit lifecycle is missing")
else:
    if agent_lifecycle.get("model") != "versioned-component":
        failures.append("LTA agent_dev_kit lifecycle must remain versioned-component")
    if agent_lifecycle.get("component_release_required") is not True:
        failures.append("LTA agent_dev_kit lifecycle must require component releases")
    if "current_release" in agent_lifecycle:
        failures.append("LTA agent_dev_kit lifecycle must not duplicate the current ADK release identity")

reports = registry.get("reports")
current_reports = [
    item for item in reports
    if isinstance(item, dict) and item.get("status") == "current"
] if isinstance(reports, list) else []
current_report = ""
if len(current_reports) != 1:
    failures.append("report registry must select exactly one current architecture report")
else:
    current_report = str(current_reports[0].get("path") or "")
    relative = Path(current_report)
    if (
        not current_report
        or relative.is_absolute()
        or ".." in relative.parts
        or relative.parts[:2] != ("reports", "architecture")
        or not (root / relative).is_file()
    ):
        failures.append("report registry current architecture report is invalid or missing")

worktree = root / "agent-dev-kit"
worktree_checked = (worktree / "manifest.json").is_file()
if worktree_checked:
    head = git("rev-parse", "HEAD", cwd=worktree).stdout.strip()
    locked = lock.get("agent-dev-kit.commit", "")
    if not locked or not head:
        failures.append("ADK worktree identity is unavailable")
    elif worktree_integration:
        if git("merge-base", "--is-ancestor", locked, head, cwd=worktree).returncode != 0:
            failures.append("working-tree ADK must descend from the locked current source")
    elif head != locked:
        failures.append("release-clean ADK worktree must exactly match adk.lock")

result = {
    "schema": "llm-agent-current-status-consistency/v2",
    "status": "pass" if not failures else "fail",
    "gate_mode": "working-tree" if worktree_integration else "release-clean",
    "current_evidence_state": projection.get("current_evidence_state"),
    "release_authorized": projection.get("release_authorized"),
    "current_adk_version": lock.get("agent-dev-kit.version"),
    "current_adk_commit": lock.get("agent-dev-kit.commit"),
    "product_maturity": overall.get("level") if isinstance(overall, dict) else None,
    "product_terminal_scope": overall.get("terminal_scope") if isinstance(overall, dict) else None,
    "long_term_asset_status": terminal.get("status") if isinstance(terminal, dict) else None,
    "pending_requirements": terminal.get("pending_requirements") if isinstance(terminal, dict) else [],
    "current_report": current_report or None,
    "worktree_checked": worktree_checked,
    "failures": failures,
}
if summary_json:
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
elif failures:
    for failure in failures:
        print(f"[FAIL] {failure}", file=sys.stderr)
else:
    print("[PASS] current source, Product M5, LTA, and report registry are consistent")

raise SystemExit(0 if not failures else 1)
PY
