#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FIXTURE="${TMP_DIR}/workspace"
REPO="${FIXTURE}/sample-repo"
mkdir -p "${FIXTURE}/scripts" "${FIXTURE}/subrepos" "${REPO}"
cp "${ROOT}/scripts/classify-repo-worktree.sh" "${FIXTURE}/scripts/"
cp "${ROOT}/scripts/analyze-repo.sh" "${FIXTURE}/scripts/"
cp "${ROOT}/scripts/sync-subrepos.sh" "${FIXTURE}/scripts/"
chmod +x "${FIXTURE}/scripts/"*.sh

git -C "${REPO}" init -q
git -C "${REPO}" config user.email "fixture@example.invalid"
git -C "${REPO}" config user.name "Fixture"
git -C "${REPO}" config core.fileMode true
printf '# committed source\n' >"${REPO}/README.md"
printf 'system_prompt = "committed"\n' >"${REPO}/prompt.py"
git -C "${REPO}" add README.md prompt.py
git -C "${REPO}" commit -q -m "fixture source"
SOURCE_COMMIT="$(git -C "${REPO}" rev-parse HEAD)"
SOURCE_SHORT="${SOURCE_COMMIT:0:12}"

printf '# dirty working tree\n' >"${REPO}/README.md"
chmod 755 "${REPO}/prompt.py"
mkdir -p "${REPO}/uncommitted-skill"
printf '%s\n' '---' 'name: uncommitted-skill' '---' >"${REPO}/uncommitted-skill/SKILL.md"

CLASSIFICATION_JSON="$("${FIXTURE}/scripts/classify-repo-worktree.sh" "${FIXTURE}" sample-repo)"
python3 - "${CLASSIFICATION_JSON}" <<'PY'
import json
import sys

record = json.loads(sys.argv[1])
assert record["classification"] == "mode+content+untracked", record
assert record["mode_changes"] == 1, record
assert record["content_changes"] == 1, record
assert record["type_changes"] == 0, record
assert record["untracked_changes"] == 1, record
PY

"${FIXTURE}/scripts/analyze-repo.sh" sample-repo --skill >"${TMP_DIR}/analyze.out"
ANALYSIS_DIR="${FIXTURE}/reports/repo-analysis/sample-repo/${SOURCE_SHORT}"
[[ -f "${ANALYSIS_DIR}/skill-deep-analysis.md" ]] || {
  echo "[FAIL] commit snapshot analysis report missing" >&2
  exit 1
}
[[ -f "${ANALYSIS_DIR}/README.md" ]] || {
  echo "[FAIL] commit snapshot analysis index missing" >&2
  exit 1
}
[[ ! -e "${REPO}/analysis" ]] || {
  echo "[FAIL] analysis wrote back into reference repository" >&2
  exit 1
}
rg -q --fixed-strings -- "source_commit: ${SOURCE_COMMIT}" "${ANALYSIS_DIR}/skill-deep-analysis.md"
rg -q --fixed-strings -- "snapshot_mode: git-archive" "${ANALYSIS_DIR}/skill-deep-analysis.md"
rg -q --fixed-strings -- "analysis_policy: commit-snapshot-only" "${ANALYSIS_DIR}/skill-deep-analysis.md"
rg -q --fixed-strings -- "| (无 SKILL.md) |" "${ANALYSIS_DIR}/skill-deep-analysis.md"
if rg -q --fixed-strings -- "uncommitted-skill" "${ANALYSIS_DIR}/skill-deep-analysis.md"; then
  echo "[FAIL] analysis consumed uncommitted worktree content" >&2
  exit 1
fi

cat >"${FIXTURE}/subrepos/registry.csv" <<'CSV'
repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade
sample-repo,reference,P1,pull,main,yes,fixture,active,tester,2026-07-13,observe-first,A
CSV
cat >"${FIXTURE}/subrepos/phase-gate.env" <<'ENV'
phase=test
allow_upstream_sync=yes
ENV

HEAD_BEFORE="$(git -C "${REPO}" rev-parse HEAD)"
if "${FIXTURE}/scripts/sync-subrepos.sh" "${FIXTURE}" pull >"${TMP_DIR}/sync.out" 2>&1; then
  echo "[FAIL] dirty pull unexpectedly passed" >&2
  exit 1
fi
rg -q --fixed-strings -- "pull refused for dirty worktree" "${TMP_DIR}/sync.out"
[[ "$(git -C "${REPO}" rev-parse HEAD)" == "${HEAD_BEFORE}" ]] || {
  echo "[FAIL] dirty pull changed repository HEAD" >&2
  exit 1
}

if "${FIXTURE}/scripts/classify-repo-worktree.sh" "${FIXTURE}" ../escape >"${TMP_DIR}/escape.out" 2>&1; then
  echo "[FAIL] invalid repository traversal unexpectedly passed" >&2
  exit 1
fi
rg -q --fixed-strings -- "invalid repo name" "${TMP_DIR}/escape.out"

echo "[PASS] reference source integrity checks behave as expected"
