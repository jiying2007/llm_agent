#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/same-run-evidence.sh
source "${ROOT}/scripts/lib/same-run-evidence.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

fixture="${TMP_DIR}/fixture"
evidence="${TMP_DIR}/evidence"
output="${TMP_DIR}/producer.out"
mkdir -p "${fixture}/scripts"

cat >"${fixture}/scripts/check-leaf.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
echo "[PASS] leaf"
SH
chmod +x "${fixture}/scripts/check-leaf.sh"

git -C "${fixture}" init -q
git -C "${fixture}" add scripts/check-leaf.sh
git -C "${fixture}" \
  -c user.name="Evidence Contract" \
  -c user.email="evidence@example.invalid" \
  commit -q -m "fixture"

mkdir -p "${fixture}/agent-dev-kit"
printf '%s\n' "adk baseline" >"${fixture}/agent-dev-kit/contract.txt"
git -C "${fixture}/agent-dev-kit" init -q
git -C "${fixture}/agent-dev-kit" add contract.txt
git -C "${fixture}/agent-dev-kit" \
  -c user.name="Evidence Contract" \
  -c user.email="evidence@example.invalid" \
  commit -q -m "adk fixture"

printf '%s\n' "untracked baseline" >"${fixture}/untracked-contract.txt"
printf '%s\n' "[PASS] leaf" >"${output}"
producer_pid="$$"
producer_start="$(llm_agent_process_start_token "${producer_pid}")"
fingerprint="$(llm_agent_workspace_fingerprint "${fixture}")"

initialize_pass_evidence() {
  rm -rf "${evidence}"
  llm_agent_same_run_init \
    "${evidence}" \
    "${producer_pid}" \
    "${producer_start}" \
    "${fixture}" \
    "${fingerprint}"
  llm_agent_same_run_record \
    "${evidence}" \
    "${producer_pid}" \
    "${producer_start}" \
    "${fixture}" \
    "${fingerprint}" \
    "check-leaf.sh" \
    "${fixture}/scripts/check-leaf.sh" \
    0 \
    "${output}"
}

expect_rejected() {
  local name="$1"
  shift
  if "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"; then
    echo "[FAIL] invalid evidence unexpectedly accepted: ${name}" >&2
    exit 1
  fi
}

initialize_pass_evidence
validated_output="$(
  llm_agent_same_run_validate \
    "${evidence}" \
    "${producer_pid}" \
    "${producer_start}" \
    "${fixture}" \
    "${fingerprint}" \
    "check-leaf.sh" \
    "${fixture}/scripts/check-leaf.sh" \
    "[PASS] leaf"
)"
[[ "${validated_output}" == "${output}" ]]

reuse_report="${TMP_DIR}/reuse.tsv"
: >"${reuse_report}"
chmod 600 "${reuse_report}"
llm_agent_same_run_report_append \
  "${evidence}" \
  "${reuse_report}" \
  "leaf_consumer" \
  "check-leaf.sh"
rg -q $'^leaf_consumer\tcheck-leaf.sh$' "${reuse_report}"

outside_report="${TMP_DIR}/outside/reuse.tsv"
mkdir -p "$(dirname "${outside_report}")"
: >"${outside_report}"
chmod 600 "${outside_report}"
expect_rejected \
  "report-outside-parent" \
  llm_agent_same_run_report_append \
  "${evidence}" \
  "${outside_report}" \
  "leaf_consumer" \
  "check-leaf.sh"

expect_rejected \
  "missing-marker" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh" \
  "[PASS] absent"

expect_rejected \
  "producer-pid" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "$((producer_pid + 1))" \
  "${producer_start}" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"

expect_rejected \
  "producer-start" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}-stale" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"

other_root="${TMP_DIR}/other-root"
mkdir -p "${other_root}"
expect_rejected \
  "workspace-root" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${other_root}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"

printf '%s\n' "tampered output" >>"${output}"
expect_rejected \
  "output-digest" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"
printf '%s\n' "[PASS] leaf" >"${output}"

initialize_pass_evidence
cp "${fixture}/scripts/check-leaf.sh" "${TMP_DIR}/check-leaf.backup"
printf '%s\n' "# drift" >>"${fixture}/scripts/check-leaf.sh"
expect_rejected \
  "script-digest" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"
cp "${TMP_DIR}/check-leaf.backup" "${fixture}/scripts/check-leaf.sh"
chmod +x "${fixture}/scripts/check-leaf.sh"

untracked_before="$(llm_agent_workspace_fingerprint "${fixture}")"
printf '%s\n' "untracked drift" >"${fixture}/untracked-contract.txt"
untracked_after="$(llm_agent_workspace_fingerprint "${fixture}")"
[[ "${untracked_after}" != "${untracked_before}" ]]
printf '%s\n' "untracked baseline" >"${fixture}/untracked-contract.txt"

adk_before="$(llm_agent_workspace_fingerprint "${fixture}")"
printf '%s\n' "adk drift" >>"${fixture}/agent-dev-kit/contract.txt"
adk_after="$(llm_agent_workspace_fingerprint "${fixture}")"
[[ "${adk_after}" != "${adk_before}" ]]
printf '%s\n' "adk baseline" >"${fixture}/agent-dev-kit/contract.txt"

initialize_pass_evidence
printf '%s\n' "tracked drift" >>"${fixture}/scripts/check-leaf.sh"
drifted_fingerprint="$(llm_agent_workspace_fingerprint "${fixture}")"
[[ "${drifted_fingerprint}" != "${fingerprint}" ]]
expect_rejected \
  "workspace-fingerprint" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${fixture}" \
  "${drifted_fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"
cp "${TMP_DIR}/check-leaf.backup" "${fixture}/scripts/check-leaf.sh"
chmod +x "${fixture}/scripts/check-leaf.sh"

initialize_pass_evidence
llm_agent_same_run_record \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh" \
  7 \
  "${output}"
expect_rejected \
  "failed-producer" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"

initialize_pass_evidence
rm -f "${evidence}/check-leaf.sh.json"
ln -s "${TMP_DIR}/missing.json" "${evidence}/check-leaf.sh.json"
expect_rejected \
  "metadata-symlink" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"

rm -rf "${evidence}"
expect_rejected \
  "missing-evidence" \
  llm_agent_same_run_validate \
  "${evidence}" \
  "${producer_pid}" \
  "${producer_start}" \
  "${fixture}" \
  "${fingerprint}" \
  "check-leaf.sh" \
  "${fixture}/scripts/check-leaf.sh"

echo "[PASS] same-run evidence accepts only current, intact PASS results"
