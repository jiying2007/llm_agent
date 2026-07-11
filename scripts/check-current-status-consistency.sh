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

Checks reports/current-status.md against git/adk/source-to-live/Hub boundary
facts so completed architecture work cannot regress to stale in-progress text.
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
import json
import os
import re
import subprocess
import sys

root, summary_json = sys.argv[1:3]
summary_json = summary_json == "1"
current_status = os.path.join(root, "reports", "current-status.md")
arch_report = os.path.join(root, "reports", "architecture", "llm-agent-adk-target-architecture-2026-07-11.md")
lock_path = os.path.join(root, "adk.lock")
failures = []


def rel(path):
    return os.path.relpath(path, root)


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def git(*args, cwd=root, check=True):
    proc = subprocess.run(["git", "-C", cwd, *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if check and proc.returncode != 0:
        failures.append(f"git {' '.join(args)} failed: {proc.stderr.strip()}")
    return proc


def lock_value(content, key):
    for line in content.splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip()
    return ""


def field(content, name):
    match = re.search(rf"^- {re.escape(name)}:\s*(.+)$", content, re.MULTILINE)
    return match.group(1).strip() if match else ""


for path in (current_status, arch_report, lock_path):
    if not os.path.isfile(path):
        failures.append(f"missing required file: {rel(path)}")

status_text = read(current_status) if os.path.isfile(current_status) else ""
arch_text = read(arch_report) if os.path.isfile(arch_report) else ""
lock_text = read(lock_path) if os.path.isfile(lock_path) else ""

root_head = git("rev-parse", "--short=7", "HEAD").stdout.strip()
root_head_full = git("rev-parse", "HEAD").stdout.strip()
adk_lock_commit = lock_value(lock_text, "agent-dev-kit.commit")
adk_lock_short = adk_lock_commit[:7]

index_proc = git("ls-files", "-s", "agent-dev-kit")
gitlink_commit = ""
for line in index_proc.stdout.splitlines():
    parts = line.split()
    if len(parts) >= 2 and parts[0] == "160000":
        gitlink_commit = parts[1]
        break

adk_proc = git("rev-parse", "HEAD", cwd=os.path.join(root, "agent-dev-kit"), check=False)
adk_worktree_commit = adk_proc.stdout.strip() if adk_proc.returncode == 0 else ""

if not adk_lock_commit:
    failures.append("adk.lock missing agent-dev-kit.commit")
if not gitlink_commit:
    failures.append("agent-dev-kit gitlink missing from index")
if adk_lock_commit and gitlink_commit and adk_lock_commit != gitlink_commit:
    failures.append(f"agent-dev-kit gitlink {gitlink_commit} != adk.lock {adk_lock_commit}")
if adk_lock_commit and adk_worktree_commit and adk_lock_commit != adk_worktree_commit:
    failures.append(f"agent-dev-kit worktree {adk_worktree_commit} != adk.lock {adk_lock_commit}")

stale_tokens = [
    "V4 closed-loop architecture | IN PROGRESS",
    "本轮 V4 模板升级需再次提交",
    "pending V4",
    "pending source-to-live",
    "Hub dry-run promotion pending",
]
for token in stale_tokens:
    if token in status_text:
        failures.append(f"{rel(current_status)} contains stale status token: {token}")

adk_status_commit = field(status_text, "agent_dev_kit_v4_commit")
if adk_lock_short and adk_status_commit and adk_status_commit != adk_lock_short:
    failures.append(f"current-status agent_dev_kit_v4_commit {adk_status_commit} != adk.lock {adk_lock_short}")

root_v4_commit = field(status_text, "root_v4_source_commit")
if root_v4_commit:
    ancestor = git("merge-base", "--is-ancestor", root_v4_commit, "HEAD", check=False)
    if ancestor.returncode != 0:
        failures.append(f"current-status root_v4_source_commit is not an ancestor of HEAD: {root_v4_commit}")
else:
    failures.append("current-status missing root_v4_source_commit")

live_status = field(status_text, "live_refresh_status")
if "live-applied" in live_status:
    for token in ("copy=0", "overwrite=0", "delete=0", "mkdir=270"):
        if token not in live_status:
            failures.append(f"live_refresh_status missing apply summary token: {token}")
    for token in ("source-to-live dry-run/apply", "source-to-live post-check"):
        if token not in status_text:
            failures.append(f"current-status missing live-applied evidence row: {token}")
else:
    failures.append("live_refresh_status must explicitly state live-applied boundary")

knowledge_status = field(status_text, "knowledge_promotion_status")
if "apply_supported=false" not in knowledge_status:
    failures.append("knowledge_promotion_status must record apply_supported=false")
if re.search(r"knowledge_promotion_status:.*active promotion applied", status_text, re.IGNORECASE):
    failures.append("knowledge_promotion_status must not claim active promotion applied")
if "PASS_WITH_BOUNDARY" not in status_text:
    failures.append("current-status must record Knowledge Hub dry-run as PASS_WITH_BOUNDARY")

for token in (
    "Runtime Delivery Contract",
    "Knowledge Promotion Contract",
    "State Reconciliation Contract",
    "Status Consistency Gate",
):
    if token not in arch_text:
        failures.append(f"{rel(arch_report)} missing architecture consistency token: {token}")

status = "pass" if not failures else "fail"
payload = {
    "status": status,
    "failures": failures,
    "root_head": root_head,
    "root_head_full": root_head_full,
    "agent_dev_kit_head": adk_worktree_commit[:7] if adk_worktree_commit else "",
    "adk_lock_commit": adk_lock_short,
    "live_refresh_status": live_status,
    "knowledge_promotion_status": knowledge_status,
}

if summary_json:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
elif failures:
    for failure in failures:
        print(f"[FAIL] {failure}", file=sys.stderr)
else:
    print(f"[PASS] current status consistent: root={root_head} adk={adk_lock_short}")

if failures:
    sys.exit(1)
PY
