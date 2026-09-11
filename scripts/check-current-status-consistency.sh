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

Checks current source identity separately from the last verified release/runtime
baseline, plus release rehearsal, runtime campaign boundary, software M5
certifier, source-to-live applicability, report registry and subrepo state.
Historical baseline age is not a general consistency failure; release freshness
is enforced by the release-profile status projection gate.
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
import shutil
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


def adk_manifest_digest(value):
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


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


def manifest_at(commit):
    if not commit:
        failures.append("historical release ADK commit is missing")
        return {}
    completed = git("show", "{}:manifest.json".format(commit), cwd=path("agent-dev-kit"), check=False)
    if completed.returncode != 0:
        failures.append("cannot read historical release manifest at {}".format(commit))
        return {}
    try:
        value = json.loads(completed.stdout)
    except json.JSONDecodeError:
        failures.append("historical release manifest is invalid JSON at {}".format(commit))
        return {}
    if not isinstance(value, dict):
        failures.append("historical release manifest root must be an object")
        return {}
    return value


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
    "codex_smoke": policy_file("codex_runtime_evidence", "codex-runtime-evidence"),
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
    "software_m5_readiness": "not-ready",
    "software_m5_certified": "false",
    "terminal_mature": "false",
    "field_status": "self_pilot_active",
    "root_gate_status": "pass",
    "runtime_eval_status": "codex-current-smoke-pass-claude-owner-attested-v2",
    "m5_campaign_status": "blocked-full-campaign-and-field-pending",
}
for name, expected in expected_fields.items():
    actual = field(status_text, name)
    if actual != expected:
        failures.append("historical current-status {} must be {}, got {}".format(name, expected, actual or "<missing>"))

if field(status_text, "adk_version") != candidate_version:
    failures.append("historical current-status adk_version does not match software M5 candidate_version")
live_refresh_status = field(status_text, "live_refresh_status")
if live_refresh_status not in {
    "required-pending-owner-authorization",
    "authorized-pending-apply",
    "applied-declarative-changed",
    "applied-declarative-no-op",
    "not-required-mapped-no-change",
}:
    failures.append("historical current-status live_refresh_status is invalid for the recorded delivery")
knowledge_candidate_status = field(status_text, "knowledge_candidate_status")
if knowledge_candidate_status not in {
    "required-pending-capture",
    "captured-reviewing",
    "not-captured-outside-write-scope",
}:
    failures.append("historical current-status knowledge_candidate_status is invalid for the recorded delivery")

last_verified_at = field(status_text, "last_verified_at")
baseline_age_days = None
try:
    verified_date = dt.date.fromisoformat(last_verified_at)
except ValueError:
    failures.append("current-status last_verified_at must be an ISO date")
else:
    baseline_age_days = (dt.date.today() - verified_date).days
    if baseline_age_days < 0:
        failures.append("current-status last_verified_at must not be in the future")

root_product_commit = field(status_text, "root_product_commit")
if not root_product_commit:
    failures.append("current-status missing root_product_commit")
elif git("merge-base", "--is-ancestor", root_product_commit, "HEAD", check=False).returncode != 0:
    failures.append("historical current-status root_product_commit is not an ancestor of HEAD: {}".format(root_product_commit))

# Current source identity comes from the lock/gitlink/current ADK checkout. The
# historical baseline fields below are release/runtime evidence and must not be
# promoted merely because source moved forward.
index = git("ls-files", "-s", "agent-dev-kit").stdout.strip().split()
gitlink_commit = index[1] if len(index) >= 2 and index[0] == "160000" else ""
adk_worktree = git("rev-parse", "HEAD", cwd=path("agent-dev-kit"), check=False).stdout.strip()
adk_lock_commit = lock.get("agent-dev-kit.commit", "")
current_adk_commit = adk_lock_commit
current_adk_version = lock.get("agent-dev-kit.version", "")
current_adk_tree = lock.get("agent-dev-kit.tree", "")
current_adk_manifest_blob = lock.get("agent-dev-kit.manifest_blob", "")
adk_release_commit = field(status_text, "agent_dev_kit_release_commit") or field(status_text, "agent_dev_kit_commit")
release_manifest = manifest_at(adk_release_commit)
release_manifest_version = release_manifest.get("version") if isinstance(release_manifest, dict) else None

if not current_adk_commit:
    failures.append("adk.lock current ADK commit is missing")
if not current_adk_version:
    failures.append("adk.lock current ADK version is missing")
if not worktree_integration:
    if gitlink_commit != current_adk_commit or not gitlink_commit:
        failures.append("gitlink ADK commit does not match adk.lock current source: {}".format(gitlink_commit or "<missing>"))
    if adk_worktree != current_adk_commit or not adk_worktree:
        failures.append("ADK worktree does not match adk.lock current source: {}".format(adk_worktree or "<missing>"))
else:
    if (
        not gitlink_commit
        or gitlink_commit != current_adk_commit
        or not adk_worktree
        or git(
            "merge-base",
            "--is-ancestor",
            current_adk_commit,
            adk_worktree,
            cwd=path("agent-dev-kit"),
            check=False,
        ).returncode
        != 0
    ):
        failures.append("working-tree ADK commit must descend from the locked gitlink/current source")

effective_current_adk_commit = adk_worktree if worktree_integration and adk_worktree else current_adk_commit
if (
    not adk_release_commit
    or not effective_current_adk_commit
    or git(
        "merge-base",
        "--is-ancestor",
        adk_release_commit,
        effective_current_adk_commit,
        cwd=path("agent-dev-kit"),
        check=False,
    ).returncode
    != 0
):
    failures.append("historical ADK release commit must be an ancestor of the current ADK source")

locked_tree = git("rev-parse", "{}^{{tree}}".format(current_adk_commit), cwd=path("agent-dev-kit"), check=False).stdout.strip()
locked_manifest_blob = git("rev-parse", "{}:manifest.json".format(current_adk_commit), cwd=path("agent-dev-kit"), check=False).stdout.strip()
if not current_adk_tree or locked_tree != current_adk_tree:
    failures.append("adk.lock current tree does not match the locked ADK commit")
if not current_adk_manifest_blob or locked_manifest_blob != current_adk_manifest_blob:
    failures.append("adk.lock current manifest blob does not match the locked ADK commit")
if not current_adk_version or manifest.get("version") != current_adk_version:
    failures.append("current ADK manifest version does not match adk.lock")
if not isinstance(candidate_version, str) or not candidate_version:
    failures.append("software M5 policy candidate_version is missing")
elif release_manifest_version != candidate_version:
    failures.append("historical release manifest version does not match software M5 candidate_version")

# The historical baseline may be older than current source. It must retain the
# release identity rather than being rewritten to the current lock.
historical_status_commit = field(status_text, "agent_dev_kit_commit")
if historical_status_commit and historical_status_commit != adk_release_commit:
    failures.append("historical current-status ADK commit must remain bound to the release baseline")

release_relation = "current" if adk_release_commit == current_adk_commit else "historical"
recorded_release_relation = field(status_text, "release_evidence_relation")
if recorded_release_relation and recorded_release_relation != release_relation:
    failures.append("generated release_evidence_relation does not match current/release source identity")
if field(status_text, "release_authorized") not in {"", "false"}:
    failures.append("current status must not authorize release from historical evidence")

overall = scorecard.get("overall", {})
software_m5 = scorecard.get("software_m5", {})
if not isinstance(overall, dict) or overall.get("level") != "M3":
    failures.append("product scorecard overall level must be M3")
if overall.get("terminal_mature") is not False:
    failures.append("product scorecard must keep terminal_mature=false")
if overall.get("field_status") != "self_pilot_active":
    failures.append("product scorecard must keep self_pilot_active")
if not isinstance(software_m5, dict) or software_m5.get("readiness_status") != "not-ready":
    failures.append("product scorecard software M5 readiness must remain not-ready while release continuity is blocked")
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

release_artifacts_for_runtime = release.get("artifacts", {}) if isinstance(release, dict) else {}


def file_sha256(file_path):
    digest = hashlib.sha256()
    with open(file_path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def runtime_readback(executable_name, expected_version, expected_sha256, label):
    executable = shutil.which(executable_name)
    if not executable or file_sha256(executable) != expected_sha256:
        failures.append("{} runtime binary identity does not match evidence".format(label))
        return
    try:
        completed = subprocess.run(
            [executable, "--version"], check=False, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15,
        )
    except (OSError, subprocess.TimeoutExpired):
        failures.append("{} runtime version readback failed or timed out".format(label))
        return
    if completed.returncode != 0 or expected_version not in completed.stdout:
        failures.append("{} runtime version readback does not match evidence".format(label))


def validate_evidence_time(value, label):
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        failures.append("{} timestamp is invalid".format(label))
        return
    if parsed.tzinfo is None or parsed > dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=5):
        failures.append("{} timestamp is timezone-less or in the future".format(label))


release_manifest_sha256 = adk_manifest_digest(release_manifest) if release_manifest else ""
codex_result = codex_smoke.get("result", {}) if isinstance(codex_smoke, dict) else {}
unsigned_codex = dict(codex_smoke)
stored_codex_digest = unsigned_codex.pop("evidence_sha256", None)
if stored_codex_digest != canonical_digest(unsigned_codex):
    failures.append("Codex runtime evidence hash does not match content")
if (
    codex_smoke.get("schema") != "llm-agent-runtime-smoke-evidence/v1"
    or codex_smoke.get("runtime") != "codex"
    or codex_smoke.get("manifest_version") != candidate_version
    or codex_smoke.get("manifest_sha256") != release_manifest_sha256
    or codex_smoke.get("adk_commit") != adk_release_commit
    or codex_smoke.get("bundle_sha256") != release_artifacts_for_runtime.get("source_sha256")
    or codex_result.get("suite") != "runtime-routing"
    or codex_result.get("runtime") != "codex"
    or codex_result.get("status") != "pass"
    or codex_result.get("total") != 1
    or codex_result.get("passed") != 1
    or codex_result.get("requested_model") != "gpt-5.5"
    or not all(codex_result.get("quality_gate", {}).values())
):
    failures.append("Codex runtime smoke identity/result is invalid")
runtime_readback(
    "codex", str(codex_smoke.get("runtime_version", "")),
    str(codex_smoke.get("runtime_binary_sha256", "")), "Codex",
)
validate_evidence_time(codex_smoke.get("generated_at"), "Codex runtime evidence generated_at")
try:
    dt.date.fromisoformat(str(codex_smoke.get("review_after")))
except ValueError:
    failures.append("Codex runtime evidence review_after is invalid")

if (
    runtime_attestation.get("schema") != "llm-agent-runtime-owner-attestation/v2"
    or runtime_attestation.get("runtime") != "claude-code"
    or runtime_attestation.get("decision") != "default-pass"
    or runtime_attestation.get("status") != "pass"
    or runtime_attestation.get("trust_layer") != "owner-attested"
    or runtime_attestation.get("runtime_measured") is not False
    or runtime_attestation.get("manifest_version") != candidate_version
    or runtime_attestation.get("manifest_sha256") != release_manifest_sha256
    or runtime_attestation.get("adk_commit") != adk_release_commit
    or runtime_attestation.get("bundle_sha256") != release_artifacts_for_runtime.get("source_sha256")
):
    failures.append("Claude Code owner attestation is missing or invalid")
unsigned_attestation = dict(runtime_attestation)
stored_attestation_digest = unsigned_attestation.pop("evidence_sha256", None)
if stored_attestation_digest != canonical_digest(unsigned_attestation):
    failures.append("Claude Code owner attestation hash does not match content")
does_not_satisfy = runtime_attestation.get("does_not_satisfy", [])
for boundary in ("native runtime conformance receipt", "60-task three-trial dual-runtime campaign", "field certification"):
    if boundary not in does_not_satisfy:
        failures.append("Claude Code owner attestation weakens evidence boundary: {}".format(boundary))
try:
    dt.date.fromisoformat(str(runtime_attestation.get("review_after")))
except ValueError:
    failures.append("Claude Code owner attestation review_after is invalid")
runtime_readback(
    "claude", str(runtime_attestation.get("runtime_version", "")),
    str(runtime_attestation.get("runtime_binary_sha256", "")), "Claude Code",
)
validate_evidence_time(runtime_attestation.get("attested_at"), "Claude Code owner attestation attested_at")
supersedes = runtime_attestation.get("supersedes")
if not isinstance(supersedes, dict):
    failures.append("Claude Code owner attestation supersession evidence is missing")
else:
    superseded_relative = Path(str(supersedes.get("path", "")))
    if superseded_relative.is_absolute() or ".." in superseded_relative.parts:
        failures.append("Claude Code owner attestation supersedes path is unsafe")
    else:
        superseded_path = path(*superseded_relative.parts)
        if not os.path.isfile(superseded_path) or file_sha256(superseded_path) != supersedes.get("sha256"):
            failures.append("Claude Code owner attestation superseded record does not match immutable hash")

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

unsigned_rehearsal = dict(rehearsal)
stored_rehearsal_digest = unsigned_rehearsal.pop("report_sha256", None)
if stored_rehearsal_digest != canonical_digest(unsigned_rehearsal):
    failures.append("release rehearsal report hash does not match content")
if release_policy.get("previous_artifact_status") == "unavailable":
    if (
        rehearsal.get("status") != "blocked"
        or rehearsal.get("blocker_id") != "previous_official_artifact_unavailable"
        or rehearsal.get("release_continuity") is not False
        or rehearsal.get("previous_sha256") != release_policy.get("previous_sha256")
        or rehearsal.get("previous_manifest_sha256") != release_policy.get("previous_manifest_sha256")
    ):
        failures.append("release rehearsal must fail closed on the unavailable previous official artifact")
else:
    if rehearsal.get("status") != "pass" or rehearsal.get("candidate_version") != candidate_version:
        failures.append("release rehearsal is not a passing release-baseline rehearsal")
    if (
        rehearsal.get("rollback", {}).get("status") != "pass"
        or not isinstance(rehearsal.get("restored_assets"), int)
        or rehearsal.get("restored_assets", 0) < 1
    ):
        failures.append("release rehearsal rollback did not restore managed assets")

release_adk = release.get("agent_dev_kit", {})
release_artifacts = release.get("artifacts", {})
release_mapping = release.get("source_to_live", {})
release_m5 = release.get("software_m5", {})
if release.get("schema") != "llm-agent-adk-software-m5-ready-release-evidence/v1":
    failures.append("software M5 release evidence schema is invalid")
if release_adk.get("commit") != adk_release_commit or release_adk.get("version") != candidate_version:
    failures.append("software M5 release evidence ADK identity does not match historical release baseline")
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
    failures.append("software M5 release evidence source-to-live decision does not match historical current-status")
if release_m5.get("readiness_status") != "not-ready" or release_m5.get("certified") is not False:
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
expected_full_summary = (
    "{0}/{0}-pushed-baseline-pass-remediation-full-pending".format(release_full_total)
    if isinstance(release_full_total, int) and release.get("validation", {}).get("remediation_full", "").startswith("pending-")
    else "{0}/{0}-pushed-baseline-and-python-3.11/3.12-remediation-pass".format(release_full_total)
    if isinstance(release_full_total, int) and release.get("validation", {}).get("remediation_full", "").startswith("python-3.11.15-")
    else "{0}/{0}-pass".format(release_full_total) if isinstance(release_full_total, int) else ""
)
if working_candidate.get("local_validation", {}).get("adk_full") != expected_full_summary:
    failures.append("product scorecard ADK full summary does not match release evidence")

previous_adk_commit = field(status_text, "adk_previous_commit")
mapping_paths = ["agents", "skills", "optional-skills", "workflows", "templates"]
expected_comparison = "{}..{}".format(previous_adk_commit, adk_release_commit)
if release_mapping.get("comparison") != expected_comparison:
    failures.append("software M5 release evidence comparison does not match historical release commits")
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
    effective_current_adk_commit,
    "--",
    *mapping_paths,
    cwd=path("agent-dev-kit"),
    check=False,
)
if post_release_mapping_diff.returncode != 0:
    failures.append("mapped ADK asset paths changed after release baseline; historical no-live-write decision is invalid")

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
    "release_rehearsal",
    "repository_runtime_campaign",
    "required_field_events",
    "runtime_campaign",
]
if m5_status.get("integrity_status") != "pass" or m5_status.get("declaration_status") != "pass":
    failures.append("software M5 evidence integrity or scorecard declaration is not pass")
if m5_status.get("readiness_status") != "not-ready" or m5_status.get("software_m5_certified") is not False:
    failures.append("software M5 certifier boundary is not not-ready/blocked")
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
    "current_adk_commit": current_adk_commit,
    "current_adk_version": current_adk_version,
    "current_adk_tree": current_adk_tree,
    "current_adk_manifest_blob": current_adk_manifest_blob,
    "agent_dev_kit_commit": current_adk_commit,
    "agent_dev_kit_release_commit": adk_release_commit,
    "release_candidate_version": candidate_version,
    "release_evidence_relation": release_relation,
    "historical_baseline_age_days": baseline_age_days,
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
        "[PASS] product status consistent: root={} current_adk={} release={} relation={} m5=not-ready/blocked".format(
            root_head,
            current_adk_commit[:7],
            adk_release_commit[:7],
            release_relation,
        )
    )

if failures:
    sys.exit(1)
PY
