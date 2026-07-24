#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

mkdir -p "${TMP_DIR}/scripts"
mkdir -p "${TMP_DIR}/scripts/lib"
cp "${ROOT}/scripts/check-all.sh" "${TMP_DIR}/scripts/check-all.sh"
cp "${ROOT}/scripts/lib/same-run-evidence.sh" "${TMP_DIR}/scripts/lib/same-run-evidence.sh"

cat >"${TMP_DIR}/scripts/check-pass.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "pass detail"
SH

cat >"${TMP_DIR}/scripts/check-fail.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "line one"
echo "line two"
echo "line three"
exit 7
SH

git -C "${TMP_DIR}" init -q
git -C "${TMP_DIR}" add scripts
git -C "${TMP_DIR}" \
  -c user.name="Check All Contract" \
  -c user.email="check-all@example.invalid" \
  commit -q -m "fixture"

result_json="${TMP_DIR}/result.json"
output="${TMP_DIR}/output.txt"
if bash "${TMP_DIR}/scripts/check-all.sh" \
  --full \
  --result-json "${result_json}" \
  --max-failure-lines 2 >"${output}" 2>&1; then
  echo "[FAIL] fixture check-all unexpectedly passed" >&2
  exit 1
fi

rg -q --fixed-strings -- "check-fail.sh failure log (last 2 lines)" "${output}"
rg -q --fixed-strings -- "line two" "${output}"
rg -q --fixed-strings -- "line three" "${output}"
if rg -q --fixed-strings -- "line one" "${output}"; then
  echo "[FAIL] bounded failure output leaked more than two lines" >&2
  exit 1
fi

python3 - "${result_json}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
assert data["schema_version"] == 1
assert data["suite"] == "llm-agent-check-all"
assert data["mode"] == "full"
assert data["status"] == "fail"
assert data["total"] == 2
assert data["pass"] == 1
assert data["fail"] == 1
assert data["same_run_reuse"]["eligible"] is False
assert data["same_run_reuse"]["count"] == 0
assert data["same_run_reuse"]["checks"] == []
checks = {item["name"]: item for item in data["checks"]}
assert checks["check-pass.sh"]["status"] == "pass"
assert checks["check-pass.sh"]["exit_code"] == 0
assert checks["check-fail.sh"]["status"] == "fail"
assert checks["check-fail.sh"]["exit_code"] == 7
PY

if bash "${TMP_DIR}/scripts/check-all.sh" --max-failure-lines nope >"${TMP_DIR}/bad.out" 2>&1; then
  echo "[FAIL] invalid max-failure-lines unexpectedly passed" >&2
  exit 1
fi
rg -q --fixed-strings -- "--max-failure-lines must be numeric" "${TMP_DIR}/bad.out"

integration_root="${TMP_DIR}/integration"
mkdir -p "${integration_root}/scripts/lib"
cp "${ROOT}/scripts/check-all.sh" "${integration_root}/scripts/check-all.sh"
cp "${ROOT}/scripts/lib/same-run-evidence.sh" "${integration_root}/scripts/lib/same-run-evidence.sh"

cat >"${integration_root}/scripts/check-leaf.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "[PASS] integration leaf"
SH

cat >"${integration_root}/scripts/check-workspace-entrypoints.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$1"
source "${ROOT}/scripts/lib/same-run-evidence.sh"
[[ -n "${LLM_AGENT_SAME_RUN_EVIDENCE_DIR:-}" ]]
[[ "${LLM_AGENT_SAME_RUN_PRODUCER_PID:-}" == "${PPID}" ]]
current_start="$(llm_agent_process_start_token "${PPID}")"
[[ "${LLM_AGENT_SAME_RUN_PRODUCER_START:-}" == "${current_start}" ]]
fingerprint="$(llm_agent_workspace_fingerprint "${ROOT}")"
evidence_output="$(
  llm_agent_same_run_validate \
    "${LLM_AGENT_SAME_RUN_EVIDENCE_DIR}" \
    "${LLM_AGENT_SAME_RUN_PRODUCER_PID}" \
    "${LLM_AGENT_SAME_RUN_PRODUCER_START}" \
    "${ROOT}" \
    "${fingerprint}" \
    "check-leaf.sh" \
    "${ROOT}/scripts/check-leaf.sh" \
    "[PASS] integration leaf"
)"
[[ -f "${evidence_output}" ]]
llm_agent_same_run_report_append \
  "${LLM_AGENT_SAME_RUN_EVIDENCE_DIR}" \
  "${LLM_AGENT_SAME_RUN_REUSE_REPORT}" \
  "integration_leaf" \
  "check-leaf.sh"
echo "[REUSE] integration_leaf <- check-leaf.sh"
# Stdout text is diagnostic only and must not be counted as machine evidence.
echo "[REUSE] stdout_spoof <- check-leaf.sh"
SH

chmod +x "${integration_root}/scripts/"*.sh
git -C "${integration_root}" init -q
git -C "${integration_root}" add scripts
git -C "${integration_root}" \
  -c user.name="Same Run Contract" \
  -c user.email="same-run@example.invalid" \
  commit -q -m "fixture"

integration_result="${TMP_DIR}/integration-result.json"
integration_output="${TMP_DIR}/integration-output.txt"
bash "${integration_root}/scripts/check-all.sh" \
  --full \
  --result-json "${integration_result}" >"${integration_output}" 2>&1

python3 - "${integration_result}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
assert data["status"] == "pass"
assert data["total"] == 2
assert data["same_run_reuse"]["eligible"] is True
assert data["same_run_reuse"]["count"] == 1
assert data["same_run_reuse"]["checks"] == [
    {"consumer": "integration_leaf", "producer": "check-leaf.sh"}
]
PY

echo "[PASS] check-all diagnostics and result JSON behave as expected"
