#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HEALTH="${ROOT}/scripts/health-check.sh"
ADK_AGENTS="${ROOT}/agent-dev-kit/AGENTS.md"
ARCH_REPORT="${ROOT}/reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md"

[[ -x "${HEALTH}" ]] || { echo "[FAIL] health summary entry missing: ${HEALTH}" >&2; exit 1; }
[[ -f "${ADK_AGENTS}" ]] || { echo "[FAIL] ADK AGENTS missing: ${ADK_AGENTS}" >&2; exit 1; }
[[ -f "${ARCH_REPORT}" ]] || { echo "[FAIL] architecture report missing: ${ARCH_REPORT}" >&2; exit 1; }

SUMMARY="$(${HEALTH} "${ROOT}" --summary-json)"
python3 - "${ROOT}" "${SUMMARY}" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
summary = json.loads(sys.argv[2])
manifest = (root / "agent-dev-kit/manifest.yaml").read_text(encoding="utf-8")


def files(path, pattern="*"):
    return sum(1 for item in path.glob(pattern) if item.is_file())


def recursive_files(path, pattern="*"):
    return sum(1 for item in path.rglob(pattern) if item.is_file())


profiles = re.search(r"^profiles:\n(.*?)^workflows:", manifest, re.M | re.S)
workflows = re.search(r"^workflows:\n(.*?)^mcp_servers:", manifest, re.M | re.S)
expected = {
    "root_script_files": files(root / "scripts"),
    "root_manifest_files": files(root / "manifests"),
    "root_report_files": recursive_files(root / "reports"),
    "adk_agents": recursive_files(root / "agent-dev-kit/agents", "AGENTS.md"),
    "adk_core_skills": recursive_files(root / "agent-dev-kit/skills", "SKILL.md"),
    "adk_optional_skills": recursive_files(root / "agent-dev-kit/optional-skills", "SKILL.md"),
    "adk_profiles": len(re.findall(r"^  [a-z0-9][a-z0-9-]*:$", profiles.group(1), re.M)) if profiles else 0,
    "adk_workflows": len(re.findall(r"^  - name:", workflows.group(1), re.M)) if workflows else 0,
    "adk_test_files": recursive_files(root / "agent-dev-kit/tests"),
    "adk_manifest_files": files(root / "agent-dev-kit/manifests"),
}
failures = []
for key, value in expected.items():
    if summary.get(key) != value:
        failures.append(f"{key}: expected {value}, got {summary.get(key)}")
if summary.get("status") not in {"pass", "needs-fix"}:
    failures.append("health summary status must be pass or needs-fix")
if summary.get("subrepo_state") not in {"pass", "fail"}:
    failures.append("health summary subrepo_state must be pass or fail")
if failures:
    for failure in failures:
        print(f"[FAIL] {failure}", file=sys.stderr)
    raise SystemExit(1)
PY

for stale in "Agents: 16 个角色" "Core Skills: 47 个" "Workflows: 1 个"; do
  if rg -q --fixed-strings -- "${stale}" "${ADK_AGENTS}"; then
    echo "[FAIL] ADK AGENTS contains mutable stale count: ${stale}" >&2
    exit 1
  fi
done

rg -q --fixed-strings -- "设计时资产快照" "${ARCH_REPORT}" || {
  echo "[FAIL] architecture asset counts are not labeled as a historical snapshot" >&2
  exit 1
}
rg -q --fixed-strings -- "scripts/health-check.sh . --summary-json" "${ARCH_REPORT}" || {
  echo "[FAIL] architecture report does not route current inventory to health summary" >&2
  exit 1
}

echo "[PASS] dynamic asset inventory matches filesystem and manifest"
