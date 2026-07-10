#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

GENERATOR="${ROOT}/scripts/generate-runtime-target-evidence-index.sh"
CHECKER="${ROOT}/scripts/check-runtime-target-evidence-index.sh"

codex_out="${TMP_DIR}/codex-home.md"
candidate_out="${TMP_DIR}/claude-code-home.md"
codex_jsonl="${TMP_DIR}/codex-home.jsonl"

"${GENERATOR}" "${ROOT}" --target codex-home --format both --out "${codex_out}" --jsonl-out "${codex_jsonl}" >/dev/null
"${GENERATOR}" "${ROOT}" --target claude-code-home --out "${candidate_out}" >/dev/null

if ! rg -q --fixed-strings -- "CODEX-HOME-DECL-001" "${codex_out}"; then
  echo "[FAIL] codex evidence index missing stable evidence id" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "- activation_ready: true" "${codex_out}"; then
  echo "[FAIL] codex evidence index missing activation_ready=true" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"schema_version":"runtime-target-evidence-index/v1"' "${codex_jsonl}"; then
  echo "[FAIL] codex evidence jsonl missing schema_version" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"approval_status":"required"' "${codex_jsonl}"; then
  echo "[FAIL] codex evidence jsonl missing approval_status=required" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- '"artifact_sha256":null' "${codex_jsonl}"; then
  echo "[FAIL] codex evidence jsonl missing artifact_sha256 placeholder" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "CLAUDE-CODE-HOME-DECL-001" "${candidate_out}"; then
  echo "[FAIL] candidate evidence index missing stable evidence id" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "- activation_ready: false" "${candidate_out}"; then
  echo "[FAIL] candidate evidence index missing activation_ready=false" >&2
  exit 1
fi

if ! rg -q --fixed-strings -- "Candidate targets remain blocked" "${candidate_out}"; then
  echo "[FAIL] candidate evidence index missing blocked boundary" >&2
  exit 1
fi

missing_out="${TMP_DIR}/missing.out"
if "${GENERATOR}" "${ROOT}" --target missing-runtime-home >"${missing_out}" 2>&1; then
  echo "[FAIL] missing target evidence index unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "runtime target not declared: missing-runtime-home" "${missing_out}"; then
  echo "[FAIL] missing target evidence index did not explain failure" >&2
  sed -n '1,80p' "${missing_out}" >&2 || true
  exit 1
fi

"${CHECKER}" "${ROOT}" >/dev/null
"${CHECKER}" "${ROOT}" --target hermes-agent-home --target opencode-home >/dev/null

summary_out="${TMP_DIR}/summary.json"
"${CHECKER}" "${ROOT}" --summary-json >"${summary_out}"
if ! rg -q --fixed-strings -- '"status":"pass"' "${summary_out}"; then
  echo "[FAIL] checker summary json did not pass" >&2
  sed -n '1,80p' "${summary_out}" >&2 || true
  exit 1
fi
if ! rg -q --fixed-strings -- '"error_code":null' "${summary_out}"; then
  echo "[FAIL] checker pass summary did not include null error_code" >&2
  sed -n '1,80p' "${summary_out}" >&2 || true
  exit 1
fi

unknown_arg_summary="${TMP_DIR}/unknown-arg-summary.json"
if "${CHECKER}" "${ROOT}" --summary-json --bad-arg >"${unknown_arg_summary}" 2>"${TMP_DIR}/unknown-arg-summary.err"; then
  echo "[FAIL] checker unknown arg summary unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- '"error_code":"RUNTIME_TARGET_EVIDENCE_INDEX_UNKNOWN_ARG"' "${unknown_arg_summary}"; then
  echo "[FAIL] checker unknown arg summary did not include stable error code" >&2
  sed -n '1,80p' "${unknown_arg_summary}" >&2 || true
  exit 1
fi

strict_without_index="${TMP_DIR}/strict-without-index.out"
if "${CHECKER}" "${ROOT}" --strict-artifacts >"${strict_without_index}" 2>&1; then
  echo "[FAIL] strict-artifacts without index unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "--strict-artifacts requires --index or --require-index" "${strict_without_index}"; then
  echo "[FAIL] strict-artifacts failure did not explain required index" >&2
  sed -n '1,80p' "${strict_without_index}" >&2 || true
  exit 1
fi

strict_without_index_summary="${TMP_DIR}/strict-without-index-summary.json"
if "${CHECKER}" "${ROOT}" --strict-artifacts --summary-json >"${strict_without_index_summary}" 2>"${TMP_DIR}/strict-without-index-summary.err"; then
  echo "[FAIL] strict-artifacts without index summary unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- '"error_code":"RUNTIME_TARGET_EVIDENCE_INDEX_STRICT_REQUIRES_INDEX"' "${strict_without_index_summary}"; then
  echo "[FAIL] strict-artifacts summary did not include stable error code" >&2
  sed -n '1,80p' "${strict_without_index_summary}" >&2 || true
  exit 1
fi
if ! rg -q --fixed-strings -- '"message":"--strict-artifacts requires --index or --require-index"' "${strict_without_index_summary}"; then
  echo "[FAIL] strict-artifacts summary did not include stable message" >&2
  sed -n '1,80p' "${strict_without_index_summary}" >&2 || true
  exit 1
fi

require_missing="${TMP_DIR}/require-missing.out"
if "${CHECKER}" "${ROOT}" --target codex-home --require-index >"${require_missing}" 2>&1; then
  echo "[FAIL] require-index without persisted index unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "index missing:" "${require_missing}"; then
  echo "[FAIL] require-index failure did not report missing index" >&2
  sed -n '1,80p' "${require_missing}" >&2 || true
  exit 1
fi

fixture_root="${TMP_DIR}/fixture-root"
fixture_dir="${fixture_root}/reports/runtime-target-activation/codex-home"
cross_target_fixture_dir="${fixture_root}/reports/runtime-target-activation/claude-code-home"
mkdir -p "${fixture_dir}"
mkdir -p "${cross_target_fixture_dir}"
printf 'explain target artifact\n' >"${fixture_dir}/explain-target.json"
printf 'cross target artifact\n' >"${cross_target_fixture_dir}/explain-target.json"
"${GENERATOR}" "${ROOT}" --target codex-home --format jsonl >"${fixture_dir}/evidence-index.jsonl"

python3 - "${fixture_dir}/evidence-index.jsonl" <<'PY'
import hashlib
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
artifact = path.parent / "explain-target.json"
lines = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
for item in lines:
    if item["evidence_id"] == "CODEX-HOME-DECL-001":
        item["artifact_exists"] = True
        item["artifact_sha256"] = hashlib.sha256(artifact.read_bytes()).hexdigest()
        item["exit_code"] = 0
        item["execution_status"] = "passed"
path.write_text("\n".join(json.dumps(item, ensure_ascii=False, separators=(",", ":")) for item in lines) + "\n", encoding="utf-8")
PY

"${CHECKER}" "${fixture_root}" --target codex-home --index "${fixture_dir}/evidence-index.jsonl" --strict-artifacts >/dev/null

make_bad_index() {
  local case_name="$1"
  local out_file="${TMP_DIR}/${case_name}.jsonl"
  python3 - "${fixture_dir}/evidence-index.jsonl" "${out_file}" "${case_name}" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
case = sys.argv[3]
lines = [json.loads(line) for line in src.read_text(encoding="utf-8").splitlines() if line.strip()]
if case == "bad-gate":
    lines[0]["gate"] = "bad-gate"
elif case == "live-no-approval":
    for item in lines:
        if item["gate"] == "apply":
            item["approval_required"] = "no"
            break
elif case == "completed-placeholder":
    for item in lines:
        if item["gate"] == "apply":
            item["execution_status"] = "passed"
            item["exit_code"] = 0
            break
elif case == "hash-mismatch":
    lines[0]["artifact_sha256"] = "0" * 64
elif case == "duplicate-id":
    lines.append(dict(lines[0]))
elif case == "bad-target-id":
    lines[0]["target_id"] = "claude-code-home"
elif case == "artifact-cross-target-path":
    lines[0]["artifact_path"] = "reports/runtime-target-activation/claude-code-home/explain-target.json"
else:
    raise SystemExit(f"unknown case: {case}")
dst.write_text("\n".join(json.dumps(item, ensure_ascii=False, separators=(",", ":")) for item in lines) + "\n", encoding="utf-8")
PY
  printf '%s' "${out_file}"
}

for case_name in bad-gate live-no-approval completed-placeholder hash-mismatch duplicate-id bad-target-id artifact-cross-target-path; do
  bad_index="$(make_bad_index "${case_name}")"
  bad_out="${TMP_DIR}/${case_name}.out"
  if "${CHECKER}" "${fixture_root}" --target codex-home --index "${bad_index}" --strict-artifacts >"${bad_out}" 2>&1; then
    echo "[FAIL] bad fixture unexpectedly passed: ${case_name}" >&2
    exit 1
  fi
done

echo "[PASS] runtime target evidence index generator behaves as expected"
