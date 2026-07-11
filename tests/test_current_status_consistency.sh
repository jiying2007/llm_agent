#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="${ROOT}/scripts/check-current-status-consistency.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${CHECKER}" "${ROOT}" --summary-json >/dev/null

make_fixture() {
  local dest="$1"
  mkdir -p "${dest}/reports/architecture" "${dest}/agent-dev-kit"
  cp "${ROOT}/reports/current-status.md" "${dest}/reports/current-status.md"
  cp "${ROOT}/reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md" "${dest}/reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md"
  cp "${ROOT}/adk.lock" "${dest}/adk.lock"

  git -C "${dest}/agent-dev-kit" init -q
  git -C "${dest}/agent-dev-kit" config user.email "fixture@example.invalid"
  git -C "${dest}/agent-dev-kit" config user.name "Fixture"
  printf 'version: 2.9.0\n' >"${dest}/agent-dev-kit/manifest.yaml"
  git -C "${dest}/agent-dev-kit" add manifest.yaml
  git -C "${dest}/agent-dev-kit" commit -q -m "fixture adk"
  local adk_commit
  adk_commit="$(git -C "${dest}/agent-dev-kit" rev-parse HEAD)"

  python3 - "${dest}/adk.lock" "${dest}/reports/current-status.md" "${adk_commit}" <<'PY'
import pathlib
import re
import sys

lock_path, status_path, adk_commit = sys.argv[1:4]
lock = pathlib.Path(lock_path).read_text(encoding="utf-8")
lock = re.sub(r"agent-dev-kit.commit=.*", f"agent-dev-kit.commit={adk_commit}", lock)
pathlib.Path(lock_path).write_text(lock, encoding="utf-8")

status = pathlib.Path(status_path).read_text(encoding="utf-8")
status = re.sub(r"- agent_dev_kit_v4_commit: .*", f"- agent_dev_kit_v4_commit: {adk_commit[:7]}", status)
pathlib.Path(status_path).write_text(status, encoding="utf-8")
PY

  git -C "${dest}" init -q
  git -C "${dest}" config user.email "fixture@example.invalid"
  git -C "${dest}" config user.name "Fixture"
  git -C "${dest}" add reports/current-status.md reports/architecture/llm-agent-adk-target-architecture-2026-07-11.md adk.lock
  git -C "${dest}" update-index --add --cacheinfo "160000,${adk_commit},agent-dev-kit"
  git -C "${dest}" commit -q -m "fixture root"
  local root_commit
  root_commit="$(git -C "${dest}" rev-parse --short=7 HEAD)"

  python3 - "${dest}/reports/current-status.md" "${root_commit}" <<'PY'
import pathlib
import re
import sys

status_path, root_commit = sys.argv[1:3]
status = pathlib.Path(status_path).read_text(encoding="utf-8")
status = re.sub(r"- root_v4_source_commit: .*", f"- root_v4_source_commit: {root_commit}", status)
pathlib.Path(status_path).write_text(status, encoding="utf-8")
PY

  git -C "${dest}" add reports/current-status.md
  git -C "${dest}" commit -q -m "fixture status"
}

expect_fail_contains() {
  local fixture="$1"
  local expected="$2"
  local out="${fixture}.out"
  if "${CHECKER}" "${fixture}" --summary-json >"${out}" 2>&1; then
    echo "[FAIL] fixture unexpectedly passed: ${fixture}" >&2
    exit 1
  fi
  if ! rg -q --fixed-strings -- "${expected}" "${out}"; then
    echo "[FAIL] expected failure did not include: ${expected}" >&2
    sed -n '1,120p' "${out}" >&2 || true
    exit 1
  fi
}

pass_root="${TMP_DIR}/pass-root"
make_fixture "${pass_root}"
"${CHECKER}" "${pass_root}" --summary-json >/dev/null

stale_root="${TMP_DIR}/stale-root"
make_fixture "${stale_root}"
python3 - "${stale_root}/reports/current-status.md" <<'PY'
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("V4 closed-loop architecture | PASS", "V4 closed-loop architecture | IN PROGRESS")
path.write_text(text, encoding="utf-8")
PY
expect_fail_contains "${stale_root}" "V4 closed-loop architecture | IN PROGRESS"

submit_root="${TMP_DIR}/submit-root"
make_fixture "${submit_root}"
printf '\n- 本轮 V4 模板升级需再次提交子仓并同步父仓 gitlink 与 `adk.lock`。\n' >>"${submit_root}/reports/current-status.md"
expect_fail_contains "${submit_root}" "本轮 V4 模板升级需再次提交"

mismatch_root="${TMP_DIR}/mismatch-root"
make_fixture "${mismatch_root}"
python3 - "${mismatch_root}/reports/current-status.md" <<'PY'
import pathlib
import re
import sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(r"- agent_dev_kit_v4_commit: .*", "- agent_dev_kit_v4_commit: 0000000", text)
path.write_text(text, encoding="utf-8")
PY
expect_fail_contains "${mismatch_root}" "current-status agent_dev_kit_v4_commit"

active_root="${TMP_DIR}/active-root"
make_fixture "${active_root}"
python3 - "${active_root}/reports/current-status.md" <<'PY'
import pathlib
import re
import sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(
    r"- knowledge_promotion_status: .*",
    "- knowledge_promotion_status: active promotion applied",
    text,
)
path.write_text(text, encoding="utf-8")
PY
expect_fail_contains "${active_root}" "knowledge_promotion_status must record apply_supported=false"

echo "[PASS] current status consistency checks behave as expected"
