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
usage: scripts/check-current-status-consistency.sh [root] [--summary-json]

Checks the last verified product baseline against root/adk commits, maturity
SSOT, runtime evidence, source-to-live applicability and knowledge boundaries.
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
import datetime as dt
import json
import os
import re
import subprocess
import sys


root, summary_json = sys.argv[1:3]
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
    "audit": path("reports", "architecture", "llm-agent-adk-product-maturity-audit-2026-07-13.md"),
    "release": path("reports", "adk-v3-release-evidence-2026-07-13.json"),
    "lock": path("adk.lock"),
    "manifest": path("agent-dev-kit", "manifest.json"),
    "comparison": path("agent-dev-kit", "docs", "changes", "adk-v3-product-maturity", "codex-comparison-final.json"),
    "claude_baseline": path("agent-dev-kit", "docs", "changes", "adk-v3-product-maturity", "claude-baseline-final.json"),
    "claude_adk": path("agent-dev-kit", "docs", "changes", "adk-v3-product-maturity", "claude-adk-final.json"),
}
for label, file_path in required.items():
    if not os.path.isfile(file_path):
        failures.append("missing required {} file: {}".format(label, os.path.relpath(file_path, root)))

status_text = read_text(required["status"])
audit_text = read_text(required["audit"])
lock = key_values(read_text(required["lock"]))
scorecard = read_json(required["scorecard"])
task_pack = read_json(required["tasks"])
registry = read_json(required["registry"])
release = read_json(required["release"])
manifest = read_json(required["manifest"])
comparison = read_json(required["comparison"])
claude_reports = [read_json(required["claude_baseline"]), read_json(required["claude_adk"])]

expected_fields = {
    "status_semantics": "last-verified-product-baseline",
    "adk_version": "3.0.0",
    "product_maturity": "M3",
    "terminal_mature": "false",
    "field_status": "field_not_verified",
    "root_gate_status": "pass",
    "runtime_eval_status": "codex-pass-claude-not-run",
    "live_refresh_status": "not-required-no-mapped-assets",
    "knowledge_candidate_status": "dry-run-planned-not-applied",
}
for name, expected in expected_fields.items():
    actual = field(status_text, name)
    if actual != expected:
        failures.append("current-status {} must be {}, got {}".format(name, expected, actual or "<missing>"))

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

if lock.get("agent-dev-kit.version") != "3.0.0" or manifest.get("version") != "3.0.0":
    failures.append("ADK version is not synchronized across lock and manifest")

overall = scorecard.get("overall", {})
if not isinstance(overall, dict) or overall.get("level") != "M3":
    failures.append("product scorecard overall level must be M3")
if overall.get("terminal_mature") is not False:
    failures.append("product scorecard must keep terminal_mature=false")
if overall.get("field_status") != "field_not_verified":
    failures.append("product scorecard must keep field_not_verified")

task_status = {
    item.get("id"): item.get("status")
    for item in task_pack.get("tasks", [])
    if isinstance(item, dict)
}
for task_id, expected in (
    ("PM-07", "implemented"),
    ("PM-08", "not_required"),
    ("PM-09", "field_not_verified"),
    ("PM-10", "ready"),
):
    if task_status.get(task_id) != expected:
        failures.append("{} status must be {}".format(task_id, expected))

current_reports = [
    item for item in registry.get("reports", []) if isinstance(item, dict) and item.get("status") == "current"
]
expected_audit = "reports/architecture/llm-agent-adk-product-maturity-audit-2026-07-13.md"
if len(current_reports) != 1 or current_reports[0].get("path") != expected_audit:
    failures.append("report registry must select the product maturity audit as its only current report")

if comparison.get("suite") != "runtime-routing-comparison" or comparison.get("status") != "pass":
    failures.append("Codex runtime comparison is not pass")
if comparison.get("baseline", {}).get("success_rate") != 0.9:
    failures.append("Codex baseline success rate evidence must be 0.9")
if comparison.get("candidate", {}).get("success_rate") != 1.0:
    failures.append("Codex ADK success rate evidence must be 1.0")
if comparison.get("no_regression") is not True or comparison.get("measurable_gain") is not True:
    failures.append("Codex comparison must preserve no-regression and measurable-gain evidence")
for report in claude_reports:
    if report.get("status") != "not-run" or "not authenticated" not in str(report.get("reason", "")):
        failures.append("Claude runtime evidence must remain not-run with authentication reason")

previous_adk_commit = field(status_text, "adk_previous_commit")
mapping_paths = ["agents", "skills", "optional-skills", "workflows", "templates"]
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

release_adk = release.get("agent_dev_kit", {})
release_mapping = release.get("source_to_live", {})
if release_adk.get("commit") != adk_status_commit:
    failures.append("release evidence ADK commit does not match current-status")
if release_mapping.get("mapped_content_changed") is not False:
    failures.append("release evidence must record mapped_content_changed=false")
if release_mapping.get("decision") != "not-required-no-mapped-assets":
    failures.append("release evidence has an invalid source-to-live decision")
if release.get("field_status") != "field_not_verified":
    failures.append("release evidence must preserve field_not_verified")

for token in (
    "llm-agent-adk-v3-product-maturity-20260713",
    "active_promotion=false",
    "未执行 apply",
):
    if token not in audit_text:
        failures.append("maturity audit missing knowledge boundary token: {}".format(token))
if re.search(r"active promotion (?:was )?applied", status_text + audit_text, re.IGNORECASE):
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
    "field_status": field(status_text, "field_status"),
    "runtime_eval_status": field(status_text, "runtime_eval_status"),
    "live_refresh_status": field(status_text, "live_refresh_status"),
    "knowledge_candidate_status": field(status_text, "knowledge_candidate_status"),
    "subrepo_state": subrepo_state,
}

if summary_json:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
elif failures:
    for failure in failures:
        print("[FAIL] {}".format(failure), file=sys.stderr)
else:
    print("[PASS] product status consistent: root={} adk={}".format(root_head, adk_status_commit[:7]))

if failures:
    sys.exit(1)
PY
