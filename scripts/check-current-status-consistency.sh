#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${1:-${SCRIPT_ROOT}}"
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
      cat <<USAGE
usage: scripts/check-current-status-consistency.sh [root] [--summary-json] [--worktree-integration]

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
python3 - "$ROOT" "$SUMMARY_JSON" "$WORKTREE_INTEGRATION" <<'PY'
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from tools.codex_assets.software_m5 import check as check_software_m5


root, summary_json, worktree_integration = sys.argv[1:4]
root = os.path.abspath(root)
summary_json = summary_json == "1"
worktree_integration = worktree_integration == "1"
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


status_path = path("reports", "current-status.md")
policy_path = path("manifests", "software_m5_policy.json")
status_text = read_text(status_path)
m5_policy = read_json(policy_path)
release_policy = m5_policy.get("release", {}) if isinstance(m5_policy, dict) else {}
campaign_policy = m5_policy.get("runtime_campaign", {}) if isinstance(m5_policy, dict) else {}


def policy_file(name, label):
    value = release_policy.get(name)
    if not isinstance(value, str) or not value:
        failures.append("software M5 policy release.{} is missing".format(name))
        return path("__invalid__", label)
    relative = Path(value)
    if relative.is_absolute() or ".." in relative.parts:
        failures.append("software M5 policy release.{} is not repository-relative".format(name))
        return path("__invalid__", label)
    return path(*relative.parts)


required = {
    "status": status_path,
    "scorecard": path("manifests", "product_maturity_scorecard.json"),
    "tasks": path("manifests", "product_maturity_task_pack.json"),
    "registry": path("manifests", "report_registry.json"),
    "release_evidence": policy_file("evidence_report", "release-evidence"),
    "lock": path("adk.lock"),
    "manifest": path("agent-dev-kit", "manifest.json"),
    "rehearsal": policy_file("rehearsal_report", "release-rehearsal"),
    "codex_smoke": path("agent-dev-kit", "docs", "changes", "adk-v3-1-software-m5-ready", "codex-runtime-smoke.json"),
    "runtime_attestation": policy_file("runtime_attestation", "runtime-attestation"),
    "m5_policy": policy_path,
    "m5_ledger": path("manifests", "software_m5_pilot_ledger.json"),
}
campaign_plan_value = campaign_policy.get("plan") if isinstance(campaign_policy, dict) else None
campaign_plan_relative = Path(campaign_plan_value) if isinstance(campaign_plan_value, str) else Path("__invalid__/campaign-plan")
if campaign_plan_relative.is_absolute() or ".." in campaign_plan_relative.parts:
    failures.append("software M5 runtime_campaign.plan is not repository-relative")
    campaign_plan_relative = Path("__invalid__/campaign-plan")
required["campaign_plan"] = path(*campaign_plan_relative.parts)
ledger_preview = read_json(required["m5_ledger"])
event_log_value = ledger_preview.get("event_log") if isinstance(ledger_preview, dict) else None
event_log_relative = Path(event_log_value) if isinstance(event_log_value, str) else Path("__invalid__/m5-events")
if event_log_relative.is_absolute() or ".." in event_log_relative.parts:
    failures.append("software M5 ledger event_log is not repository-relative")
    event_log_relative = Path("__invalid__/m5-events")
required["m5_events"] = path(*event_log_relative.parts)
for label, file_path in required.items():
    if not os.path.isfile(file_path):
        failures.append("missing required {} file: {}".format(label, os.path.relpath(file_path, root)))

lock = key_values(read_text(required["lock"]))
scorecard = read_json(required["scorecard"])
task_pack = read_json(required["tasks"])
registry = read_json(required["registry"])
manifest = read_json(required["manifest"])
release = read_json(required["release_evidence"])
rehearsal = read_json(required["rehearsal"])
campaign_plan = read_json(required["campaign_plan"])
codex_smoke = read_json(required["codex_smoke"])
runtime_attestation = read_json(required["runtime_attestation"])
candidate_version = release_policy.get("candidate_version")

expected_fields = {
    "status_semantics": "last-verified-product-baseline",
    "product_maturity": "M3",
    "software_m5_readiness": "m5-ready",
    "software_m5_certified": "false",
    "terminal_mature": "false",
    "field_status": "self_pilot_active",
    "root_gate_status": "pass",
    "runtime_eval_status": "codex-smoke-pass-claude-owner-attested",
    "m5_campaign_status": "blocked-full-campaign-and-field-pending",
}
for name, expected in expected_fields.items():
    actual = field(status_text, name)
    if actual != expected:
        failures.append("current-status {} must be {}, got {}".format(name, expected, actual or "<missing>"))

if field(status_text, "adk_version") != candidate_version:
    failures.append("current-status adk_version does not match software M5 candidate_version")
live_refresh_status = field(status_text, "live_refresh_status")
if live_refresh_status not in {
    "required-pending-owner-authorization",
    "authorized-pending-apply",
    "applied-declarative-changed",
    "applied-declarative-no-op",
    "not-required-mapped-no-change",
}:
    failures.append("current-status live_refresh_status is invalid for the current delivery")
knowledge_candidate_status = field(status_text, "knowledge_candidate_status")
if knowledge_candidate_status not in {
    "required-pending-capture",
    "captured-reviewing",
    "not-captured-outside-write-scope",
}:
    failures.append("current-status knowledge_candidate_status is invalid for the current delivery")

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
adk_release_commit = field(status_text, "agent_dev_kit_release_commit") or adk_status_commit
identity_values = [
    ("adk.lock", adk_lock_commit),
    ("ADK worktree", adk_worktree),
    ("current-status", adk_status_commit),
]
if not worktree_integration:
    identity_values.insert(0, ("gitlink", gitlink_commit))
for label, value in identity_values:
    if value != adk_status_commit or not value:
        failures.append("{} ADK commit does not match current-status: {}".format(label, value or "<missing>"))
if worktree_integration and (
    not gitlink_commit
    or git(
        "merge-base",
        "--is-ancestor",
        gitlink_commit,
        adk_status_commit,
        cwd=path("agent-dev-kit"),
        check=False,
    ).returncode
    != 0
):
    failures.append("working-tree ADK commit must descend from the recorded gitlink")
if (
    not adk_release_commit
    or git(
        "merge-base",
        "--is-ancestor",
        adk_release_commit,
        adk_status_commit,
        cwd=path("agent-dev-kit"),
        check=False,
    ).returncode
    != 0
):
    failures.append("current-status ADK release commit must be an ancestor of the current ADK commit")

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
if len(current_reports) != 1:
    failures.append("report registry must select exactly one current architecture report")
else:
    current_report = current_reports[0].get("path")
    if not isinstance(current_report, str) or not current_report:
        failures.append("report registry current report path is missing")
    else:
        current_relative = Path(current_report)
        if current_relative.is_absolute() or ".." in current_relative.parts:
            failures.append("report registry current report path must be repository-relative")
        elif not current_relative.parts or current_relative.parts[:2] != ("reports", "architecture"):
            failures.append("report registry current report must stay under reports/architecture")
        elif not os.path.isfile(path(*current_relative.parts)):
            failures.append("report registry current report is missing: {}".format(current_report))

if codex_smoke.get("suite") != "runtime-routing" or codex_smoke.get("runtime") != "codex":
    failures.append("Codex runtime smoke has an invalid identity")
if codex_smoke.get("status") != "pass" or codex_smoke.get("total") != 1 or codex_smoke.get("passed") != 1:
    failures.append("Codex runtime smoke is not a one-task pass")
if codex_smoke.get("requested_model") != "gpt-5.5":
    failures.append("Codex runtime smoke must request gpt-5.5")
if not all(codex_smoke.get("quality_gate", {}).values()):
    failures.append("Codex runtime smoke quality gates are not all passing")

if (
    runtime_attestation.get("schema") != "llm-agent-runtime-owner-attestation/v1"
    or runtime_attestation.get("runtime") != "claude-code"
    or runtime_attestation.get("decision") != "default-pass"
    or runtime_attestation.get("status") != "pass"
    or runtime_attestation.get("trust_layer") != "owner-attested"
    or runtime_attestation.get("runtime_measured") is not False
):
    failures.append("Claude Code owner attestation is missing or invalid")
does_not_satisfy = runtime_attestation.get("does_not_satisfy", [])
for boundary in ("native runtime conformance receipt", "60-task three-trial dual-runtime campaign", "field certification"):
    if boundary not in does_not_satisfy:
        failures.append("Claude Code owner attestation weakens evidence boundary: {}".format(boundary))

stored_plan_digest = campaign_plan.get("plan_sha256")
unsigned_plan = dict(campaign_plan)
unsigned_plan.pop("plan_sha256", None)
if stored_plan_digest != canonical_digest(unsigned_plan):
    failures.append("software M5 campaign plan hash does not match content")
if campaign_plan.get("status") != "ready" or campaign_plan.get("task_count") != 60 or campaign_plan.get("trials") != 3:
    failures.append("software M5 campaign plan must be the ready frozen 60-task/3-trial plan")
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
if claude_entry.get("status") != "planned" or claude_entry.get("reason") is not None:
    failures.append("software M5 Claude campaign runtime must be planned after owner default acceptance")
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
if release_adk.get("commit") != adk_release_commit or release_adk.get("version") != candidate_version:
    failures.append("software M5 release evidence ADK identity does not match current-status")
if release_artifacts.get("source_sha256") != rehearsal.get("candidate_sha256"):
    failures.append("software M5 release artifact SHA does not match rehearsal")
mapped_content_changed = release_mapping.get("mapped_content_changed")
if not isinstance(mapped_content_changed, bool):
    failures.append("software M5 release evidence mapped_content_changed must be boolean")
elif mapped_content_changed and live_refresh_status not in {
    "required-pending-owner-authorization",
    "authorized-pending-apply",
    "applied-declarative-changed",
}:
    failures.append("mapped ADK assets require an explicit pending or applied live-refresh boundary")
elif not mapped_content_changed and live_refresh_status not in {
    "applied-declarative-no-op",
    "not-required-mapped-no-change",
}:
    failures.append("unchanged mapped ADK assets require a no-op or not-required live-refresh decision")
if release_mapping.get("decision") != live_refresh_status:
    failures.append("software M5 release evidence source-to-live decision does not match current-status")
if release_m5.get("readiness_status") != "m5-ready" or release_m5.get("certified") is not False:
    failures.append("software M5 release evidence has an invalid maturity boundary")
release_full = release.get("validation", {}).get("full", {})
release_full_total = release_full.get("total")
if (
    isinstance(release_full_total, bool)
    or not isinstance(release_full_total, int)
    or release_full_total < 1
    or release_full.get("pass") != release_full_total
    or release_full.get("fail") != 0
):
    failures.append("software M5 release evidence does not record a complete passing ADK full gate")
working_candidate = scorecard.get("working_candidate", {})
expected_full_summary = "{0}/{0}-pass".format(release_full_total) if isinstance(release_full_total, int) else ""
if working_candidate.get("local_validation", {}).get("adk_full") != expected_full_summary:
    failures.append("product scorecard ADK full summary does not match release evidence")

previous_adk_commit = field(status_text, "adk_previous_commit")
mapping_paths = ["agents", "skills", "optional-skills", "workflows", "templates"]
expected_comparison = "{}..{}".format(previous_adk_commit, adk_release_commit)
if release_mapping.get("comparison") != expected_comparison:
    failures.append("software M5 release evidence comparison does not match current-status commits")
mapping_diff = git(
    "diff",
    "--quiet",
    previous_adk_commit,
    adk_release_commit,
    "--",
    *mapping_paths,
    cwd=path("agent-dev-kit"),
    check=False,
)
actual_mapped_content_changed = mapping_diff.returncode != 0
if isinstance(mapped_content_changed, bool) and mapped_content_changed != actual_mapped_content_changed:
    failures.append("mapped ADK asset diff does not match release evidence declaration")
post_release_mapping_diff = git(
    "diff",
    "--quiet",
    adk_release_commit,
    adk_status_commit,
    "--",
    *mapping_paths,
    cwd=path("agent-dev-kit"),
    check=False,
)
if post_release_mapping_diff.returncode != 0:
    failures.append("mapped ADK asset paths changed after release baseline; current no-live-write decision is invalid")

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
    "repository_runtime_campaign",
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
        [subrepo_checker, root, "--summary-json"]
        + (["--allow-agent-dev-kit-dirty"] if worktree_integration else []),
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
    "agent_dev_kit_release_commit": adk_release_commit,
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
    "gate_mode": "working-tree" if worktree_integration else "release",
}

if summary_json:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
elif failures:
    for failure in failures:
        print("[FAIL] {}".format(failure), file=sys.stderr)
else:
    print(
        "[PASS] product status consistent: root={} adk={} release={} m5=m5-ready/blocked".format(
            root_head, adk_status_commit[:7], adk_release_commit[:7]
        )
    )

if failures:
    sys.exit(1)
PY
