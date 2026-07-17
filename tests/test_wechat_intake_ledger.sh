#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="${ROOT}/scripts/check-wechat-intake-ledger.sh"
GENERATOR="${ROOT}/scripts/generate-wechat-intake-ledger.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

expect_fail() {
  local case_name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[FAIL] negative fixture unexpectedly passed: ${case_name}" >&2
    exit 1
  fi
}

check_fixture() {
  WECHAT_INTAKE_MIN_ARTICLES=3 "${CHECKER}" "$@"
}

fixture="${TMP_DIR}/workspace"
mkdir -p "${fixture}/scripts" "${fixture}/reports" "${fixture}/wechat-articles/fixture"
cp "${CHECKER}" "${fixture}/scripts/check-wechat-intake-ledger.sh"
cp "${GENERATOR}" "${fixture}/scripts/generate-wechat-intake-ledger.sh"
chmod +x "${fixture}/scripts/check-wechat-intake-ledger.sh" "${fixture}/scripts/generate-wechat-intake-ledger.sh"

printf 'id\tdecision\tstatus\ttarget_asset\tevidence\tnotes\n' > "${fixture}/reports/wechat-article-decisions.tsv"
for number in $(seq -w 1 3); do
  printf '# Fixture article %s\n\nStable fixture content.\n' "${number}" \
    > "${fixture}/wechat-articles/fixture/${number}.md"
done

"${GENERATOR}" --root "${fixture}" --no-batch-report >/dev/null
check_fixture "${fixture}" >/dev/null

external_corpus="${TMP_DIR}/external-corpus"
mv "${fixture}/wechat-articles" "${external_corpus}"
check_fixture "${fixture}" >/dev/null
expect_fail "portable mode must fail when strict corpus is required" \
  env WECHAT_INTAKE_MIN_ARTICLES=3 "${CHECKER}" "${fixture}" --require-corpus
check_fixture "${fixture}" --articles-dir "${external_corpus}" --require-corpus >/dev/null

cp "${external_corpus}/fixture/1.md" "${TMP_DIR}/1.md"
printf '\nstale change\n' >> "${external_corpus}/fixture/1.md"
expect_fail "live corpus drift" \
  env WECHAT_INTAKE_MIN_ARTICLES=3 "${CHECKER}" "${fixture}" --articles-dir "${external_corpus}"
cp "${TMP_DIR}/1.md" "${external_corpus}/fixture/1.md"

cp "${fixture}/reports/wechat-article-intake.jsonl" "${TMP_DIR}/ledger.jsonl"
printf '\n' >> "${fixture}/reports/wechat-article-intake.jsonl"
expect_fail "ledger tamper" env WECHAT_INTAKE_MIN_ARTICLES=3 "${CHECKER}" "${fixture}"
cp "${TMP_DIR}/ledger.jsonl" "${fixture}/reports/wechat-article-intake.jsonl"

mv "${fixture}/reports/wechat-article-intake.manifest.json" "${TMP_DIR}/manifest.json"
expect_fail "missing portable snapshot manifest" env WECHAT_INTAKE_MIN_ARTICLES=3 "${CHECKER}" "${fixture}"
mv "${TMP_DIR}/manifest.json" "${fixture}/reports/wechat-article-intake.manifest.json"

rm "${external_corpus}/fixture/3.md"
expect_fail "live corpus count mismatch" \
  env WECHAT_INTAKE_MIN_ARTICLES=3 "${CHECKER}" "${fixture}" --articles-dir "${external_corpus}"

echo "[PASS] wechat intake ledger portable/live fixtures behave as expected"
