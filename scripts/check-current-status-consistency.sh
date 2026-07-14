#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${1:-${SCRIPT_ROOT}}"
SUMMARY_JSON=0

if [[ $# -gt 0 && "$1" != --* ]]; then
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
usage: scripts/check-current-status-consistency.sh [root] [--summary-json]

Checks the last verified 3.1 M5-ready baseline against root/adk commits,
release rehearsal, runtime campaign boundary, software M5 certifier,
source-to-live applicability, report registry and current subrepo state.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

export PYTHONPATH="${SCRIPT_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"
python3 - "$ROOT" "$SUMMARY_JSON" <<'PY'
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from tools.codex_assets.software_m5 import check as check_software_m5


root, summary_json = sys.argv[1:3]
root = os.path.abspath(root)
summary_json = summary_json == "1"
failures = []


def path(*parts):
    return os.path.join(root, *parts)


def read_text(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as stream:
            return stream.read()
    except OSError as exc:
        failures.append("cannot read {}: {}".format(os.path.relpath(file_path, root), exc))
        return ""


def read_json(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as stream:
            value = json.load(stream)
    except (OSError, json.JSONDecodeError) as exc:
        failures.append("invalid JSON {}: {}".format(os.path.relpath(file_path, root), exc))
        return {}
    if not isinstance(value, dict):
        failures.append("JSON root must be an object: {}".format(os.path.relpath(file_path, root)))
        return {}
    return value


def field(content, name):
    match = re.search(r"^- {}:\s*(.+)$".format(re.escape(name)), content, re.MULTILINE)
    return match.group(1).strip() if match else ""


def key_values(content):
    result = {}
    for line in content.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def canonical_digest(value):
    return hashlib.sha256(
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def git(*args, cwd=None, check=True):
    completed = subprocess.run(
        ["git", "-C", cwd or root, *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        failures.append("git {} failed: {}".format(" ".join(args), completed.stderr.strip()))
    return completed


required = {
    "status": path("reports", "current-status.md"),
    "scorecard": path("manifests", "product_maturity_scorecard.json"),
    "tasks": path("manifests", "product_maturity_task_pack.json"),
    "registry": path("manifests", "report_registry.json"),
    "audit": path("reports", "architecture", "llm-agent-adk-software-m5-readiness-2026-07-13.md"),
    "release_evidence": path("reports", "adk-v3-1-rc2-release-evidence-2026-07-14.json"),
    "lock": path("adk.lock"),
    "manifest": path("agent-dev-kit", "manifest.json"),
    "rehearsal": path("agent-dev-kit", "docs", "changes", "adk-v3-1-rc2-target-conformance", "release-rehearsal.json"),
    "campaign_plan": path("agent-dev-kit", "docs", "changes", "adk-v3-1-software-m5-ready", "software-m5-campaign-plan.json"),
    "codex_smoke": path("agent-dev-kit", "docs", "changes", "adk-v3-1-software-m5-ready", "codex-runtime-smoke.json"),
    "m5_policy": path("manifests", "software_m5_policy.json"),
    "m5_ledger": path("manifests", "software_m5_pilot_ledger.json"),
    "m5_events": path("reports", "field-evidence", "software-m5-events.jsonl"),
}
for label, file_path in required.items():
    if not os.path.isfile(file_path):
        failures.append("missing required {} file: {}".format(label, os.path.relpath(file_path, root)))

status_text = read_text(required["status"])
lock = key_values(read_text(required["lock"]))
scorecard = read_json(required["scorecard"])
task_pack = read_json(required["tasks"])
registry = read_json(required["registry"])
manifest = read_json(required["manifest"])
release = read_json(required["release_evidence"])
rehearsal = read_json(required["rehearsal"])
campaign_plan = read_json(required["campaign_plan"])
codex_smoke = read_json(required["codex_smoke"])
m5_policy = read_json(required["m5_policy"])
release_policy = m5_policy.get("release", {}) if isinstance(m5_policy, dict) else {}
candidate_version = release_policy.get("candidate_version")

expected_fields = {
    "status_semantics": "last-verified-product-baseline",
    "product_maturity": "M3",
    "software_m5_readiness": "m5-ready",
    "software_m5_certified": "false",
    "terminal_mature": "false",
    "field_status": "self_pilot_active",
    "root_gate_status": "pass",
    "runtime_eval_status": "codex-smoke-pass-claude-blocked",
    "m5_campaign_status": "blocked-claude-unauthenticated",
}
for name, expected in expected_fields.items():
    actual = field(status_text, name)
    if actual != expected:
        failures.append("current-status {} must be {}, got {}".format(name, expected, actual or "<missing>"))

if field(status_text, "adk_version") != candidate_version:
    failures.append("current-status adk_version does not match software M5 candidate_version")
live_refresh_status = field(status_text, "live_refresh_status")
if live_refresh_status not in {"authorized-pending-apply", "applied-declarative-no-op"}:
    failures.append("current-status live_refresh_status is invalid for rc.2 delivery")
knowledge_candidate_status = field(status_text, "knowledge_candidate_status")
if knowledge_candidate_status not in {"required-pending-capture", "captured-reviewing"}:
    failures.append("current-status knowledge_candidate_status is invalid for rc.2 delivery")

last_verified_at = field(status_text, "last_verified_at")
try:
    verified_date = dt.date.fromisoformat(last_verified_at)
except ValueError:
    failures.append("current-status last_verified_at must be an ISO date")
else:
    age_days = (dt.date.today() - verified_date).days
    if age_days < 0:
        failures.append("current-status last_verified_at must not be in the future")
    elif age_days > 7:
        failures.append("current-status verification is stale: age_days={}".format(age_days))

root_product_commit = field(status_text, "root_product_commit")
if not root_product_commit:
    failures.append("current-status missing root_product_commit")
elif git("merge-base", "--is-ancestor", root_product_commit, "HEAD", check=False).returncode != 0:
    failures.append("current-status root_product_commit is not an ancestor of HEAD: {}".format(root_product_commit))

index = git("ls-files", "-s", "agent-dev-kit").stdout.strip().split()
gitlink_commit = index[1] if len(index) >= 2 and index[0] == "160000" else ""
adk_worktree = git("rev-parse", "HEAD", cwd=path("agent-dev-kit"), check=False).stdout.strip()
adk_lock_commit = lock.get("agent-dev-kit.commit", "")
adk_status_commit = field(status_text, "agent_dev_kit_commit")
for label, value in (
    ("gitlink", gitlink_commit),
    ("adk.lock", adk_lock_commit),
    ("ADK worktree", adk_worktree),
    ("current-status", adk_status_commit),
):
    if value != adk_status_commit or not value:
        failures.append("{} ADK commit does not match current-status: {}".format(label, value or "<missing>"))

if (
    not isinstance(candidate_version, str)
    or lock.get("agent-dev-kit.version") != candidate_version
    or manifest.get("version") != candidate_version
):
    failures.append("ADK version is not synchronized across lock and manifest")

overall = scorecard.get("overall", {})
software_m5 = scorecard.get("software_m5", {})
if not isinstance(overall, dict) or overall.get("level") != "M3":
    failures.append("product scorecard overall level must be M3")
if overall.get("terminal_mature") is not False:
    failures.append("product scorecard must keep terminal_mature=false")
if overall.get("field_status") != "self_pilot_active":
    failures.append("product scorecard must keep self_pilot_active")
if not isinstance(software_m5, dict) or software_m5.get("readiness_status") != "m5-ready":
    failures.append("product scorecard software M5 readiness must be m5-ready")
if software_m5.get("certified") is not False or software_m5.get("certification_status") != "blocked":
    failures.append("product scorecard must keep software M5 certification blocked")
if software_m5.get("candidate_version") != candidate_version:
    failures.append("product scorecard software M5 candidate version does not match policy")

task_status = {
    item.get("id"): item.get("status")
    for item in task_pack.get("tasks", [])
    if isinstance(item, dict)
}
for task_id, expected in (
    ("PM-06", "blocked_external"),
    ("PM-07", "implemented"),
    ("PM-08", "implemented"),
    ("PM-09", "in_progress"),
):
    if task_status.get(task_id) != expected:
        failures.append("{} status must be {}".format(task_id, expected))
if task_status.get("PM-10") not in {"ready", "implemented"}:
    failures.append("PM-10 status must be ready or implemented")

current_reports = [
    item for item in registry.get("reports", []) if isinstance(item, dict) and item.get("status") == "current"
]
expected_audit = "reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md"
if len(current_reports) != 1 or current_reports[0].get("path") != expected_audit:
    failures.append("report registry must select the software M5 readiness audit as its only current report")

if codex_smoke.get("suite") != "runtime-routing" or codex_smoke.get("runtime") != "codex":
    failures.append("Codex runtime smoke has an invalid identity")
if codex_smoke.get("status") != "pass" or codex_smoke.get("total") != 1 or codex_smoke.get("passed") != 1:
    failures.append("Codex runtime smoke is not a one-task pass")
if codex_smoke.get("requested_model") != "gpt-5.5":
    failures.append("Codex runtime smoke must request gpt-5.5")
if not all(codex_smoke.get("quality_gate", {}).values()):
    failures.append("Codex runtime smoke quality gates are not all passing")

stored_plan_digest = campaign_plan.get("plan_sha256")
unsigned_plan = dict(campaign_plan)
unsigned_plan.pop("plan_sha256", None)
if stored_plan_digest != canonical_digest(unsigned_plan):
    failures.append("software M5 campaign plan hash does not match content")
if campaign_plan.get("status") != "blocked" or campaign_plan.get("task_count") != 60 or campaign_plan.get("trials") != 3:
    failures.append("software M5 campaign plan must remain the frozen blocked 60-task/3-trial plan")
if campaign_plan.get("maximum_worst_cost_usd") != 144.0:
    failures.append("software M5 campaign worst-case cost must be $144")
runtime_entries = {
    item.get("runtime"): item for item in campaign_plan.get("runtimes", []) if isinstance(item, dict)
}
if runtime_entries.get("codex", {}).get("status") != "planned":
    failures.append("software M5 Codex campaign runtime must be planned")
if runtime_entries.get("codex", {}).get("requested_model") != "gpt-5.5":
    failures.append("software M5 Codex campaign model mismatch")
claude_entry = runtime_entries.get("claude", {})
if claude_entry.get("status") != "not-run" or "not authenticated" not in str(claude_entry.get("reason", "")):
    failures.append("software M5 Claude campaign must remain blocked by authentication")
if claude_entry.get("requested_model") != "claude-sonnet-4-6":
    failures.append("software M5 Claude campaign model mismatch")
if any("executable" in item and item.get("executable") for item in runtime_entries.values()):
    failures.append("software M5 campaign plan must not persist absolute executable paths")

if rehearsal.get("status") != "pass" or rehearsal.get("candidate_version") != candidate_version:
    failures.append("release rehearsal is not a passing current-candidate rehearsal")
if (
    rehearsal.get("rollback", {}).get("status") != "pass"
    or not isinstance(rehearsal.get("restored_assets"), int)
    or rehearsal.get("restored_assets", 0) < 1
):
    failures.append("release rehearsal rollback did not restore managed assets")
if rehearsal.get("schema_version") == 2 and rehearsal.get("migration_mode") == "rollback-before-install":
    fallback = rehearsal.get("fallback_restore", {})
    if (
        rehearsal.get("legacy_rollback", {}).get("status") != "pass"
        or fallback.get("status") != "pass"
        or fallback.get("strategy") != "reinstall-previous-artifact"
        or fallback.get("cleanup_removed") != fallback.get("installed")
    ):
        failures.append("release rehearsal rc.1 fallback restoration is incomplete")

release_adk = release.get("agent_dev_kit", {})
release_artifacts = release.get("artifacts", {})
release_mapping = release.get("source_to_live", {})
release_m5 = release.get("software_m5", {})
if release.get("schema") != "llm-agent-adk-software-m5-ready-release-evidence/v1":
    failures.append("software M5 release evidence schema is invalid")
if release_adk.get("commit") != adk_status_commit or release_adk.get("version") != candidate_version:
    failures.append("software M5 release evidence ADK identity does not match current-status")
if release_artifacts.get("source_sha256") != rehearsal.get("candidate_sha256"):
    failures.append("software M5 release artifact SHA does not match rehearsal")
if release_mapping.get("mapped_content_changed") is not False:
    failures.append("software M5 release evidence must record mapped_content_changed=false")
if release_mapping.get("decision") != live_refresh_status:
    failures.append("software M5 release evidence source-to-live decision does not match current-status")
if release_m5.get("readiness_status") != "m5-ready" or release_m5.get("certified") is not False:
    failures.append("software M5 release evidence has an invalid maturity boundary")
release_full = release.get("validation", {}).get("full", {})
if release_full.get("total") != 51 or release_full.get("pass") != 51 or release_full.get("fail") != 0:
    failures.append("software M5 release evidence does not record the 51/51 ADK full gate")

previous_adk_commit = field(status_text, "adk_previous_commit")
mapping_paths = ["agents", "skills", "optional-skills", "workflows", "templates"]
expected_comparison = "{}..{}".format(previous_adk_commit, adk_status_commit)
if release_mapping.get("comparison") != expected_comparison:
    failures.append("software M5 release evidence comparison does not match current-status commits")
mapping_diff = git(
    "diff",
    "--quiet",
    previous_adk_commit,
    adk_status_commit,
    "--",
    *mapping_paths,
    cwd=path("agent-dev-kit"),
    check=False,
)
if mapping_diff.returncode != 0:
    failures.append("mapped ADK asset paths changed; no-live-write decision is invalid")

try:
    m5_status = check_software_m5(Path(root), dt.datetime.now(dt.timezone.utc))
except Exception as exc:
    m5_status = {}
    failures.append("software M5 certifier failed: {}".format(exc))
expected_blockers = [
    "final_version",
    "independent_repository",
    "operator_count",
    "pilot_duration",
    "real_repository_count",
    "required_field_events",
    "runtime_campaign",
]
if m5_status.get("integrity_status") != "pass" or m5_status.get("declaration_status") != "pass":
    failures.append("software M5 evidence integrity or scorecard declaration is not pass")
if m5_status.get("readiness_status") != "m5-ready" or m5_status.get("software_m5_certified") is not False:
    failures.append("software M5 certifier boundary is not m5-ready/blocked")
if m5_status.get("blocker_ids") != expected_blockers:
    failures.append("software M5 certifier blocker set has drifted")

if re.search(r"active promotion (?:was )?applied", status_text, re.IGNORECASE):
    failures.append("status evidence must not claim active knowledge promotion")

subrepo_checker = path("scripts", "check-subrepo-state.sh")
if not os.path.isfile(subrepo_checker):
    failures.append("missing current subrepo state checker")
    subrepo_state = {}
else:
    completed = subprocess.run(
        [subrepo_checker, root, "--summary-json"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        subrepo_state = json.loads(completed.stdout)
    except json.JSONDecodeError:
        subrepo_state = {}
        failures.append("current subrepo state output is not valid JSON")
    if completed.returncode != 0 or subrepo_state.get("status") != "pass":
        failures.append("current subrepo state is not pass")

root_head = git("rev-parse", "--short=7", "HEAD").stdout.strip()
payload = {
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "root_head": root_head,
    "root_product_commit": root_product_commit,
    "agent_dev_kit_commit": adk_status_commit,
    "adk_version": field(status_text, "adk_version"),
    "product_maturity": field(status_text, "product_maturity"),
    "software_m5_readiness": field(status_text, "software_m5_readiness"),
    "software_m5_certified": field(status_text, "software_m5_certified"),
    "field_status": field(status_text, "field_status"),
    "runtime_eval_status": field(status_text, "runtime_eval_status"),
    "m5_campaign_status": field(status_text, "m5_campaign_status"),
    "live_refresh_status": field(status_text, "live_refresh_status"),
    "knowledge_candidate_status": field(status_text, "knowledge_candidate_status"),
    "software_m5": m5_status,
    "subrepo_state": subrepo_state,
}

if summary_json:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
elif failures:
    for failure in failures:
        print("[FAIL] {}".format(failure), file=sys.stderr)
else:
    print("[PASS] product status consistent: root={} adk={} m5=m5-ready/blocked".format(root_head, adk_status_commit[:7]))

if failures:
    sys.exit(1)
PY
