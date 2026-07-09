#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGETS=()

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

usage() {
  cat <<USAGE
usage: scripts/check-runtime-target-evidence-index.sh [root] [--target <id> ...]

Generates runtime target activation Evidence Index drafts in a temporary
directory and validates stable markdown/jsonl schema markers, status enums and
approval boundaries. The command is read-only for the repository.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGETS+=("${2:-}")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${#TARGETS[@]}" -eq 0 ]]; then
  TARGETS=(codex-home claude-code-home)
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAILURES=0

record_fail() {
  echo "[FAIL] $*" >&2
  FAILURES=$((FAILURES + 1))
}

assert_contains() {
  local file="$1"
  local token="$2"
  if ! rg -q --fixed-strings -- "${token}" "${file}"; then
    record_fail "$(basename "${file}") missing token: ${token}"
  fi
}

assert_jsonl_contract() {
  local file="$1"
  local target="$2"
  if python3 - "$file" "$target" <<'PY'
import json
import sys

path, target = sys.argv[1:3]
allowed_gates = {"declare", "dry-run", "health", "footprint", "apply", "rollback", "activation"}
allowed_scopes = {"read-only", "source-repo-only", "workspace-local", "live-root", "rollback-live-root"}
allowed_status = {"planned", "passed", "failed", "blocked", "approved"}
allowed_approval_status = {"not-required", "required", "approved", "denied", "expired"}
required = {
    "schema_version",
    "evidence_id",
    "target_id",
    "runtime",
    "gate",
    "command",
    "exit_code",
    "expected_result",
    "result_summary",
    "write_scope",
    "artifact_path",
    "artifact_exists",
    "artifact_sha256",
    "layer",
    "related_artifact",
    "approval_required",
    "approval_status",
    "execution_status",
    "created_at",
    "notes",
}
entries = []
with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if line:
            entries.append(json.loads(line))
if len(entries) < 9:
    raise SystemExit(f"expected at least 9 entries, got {len(entries)}")
if not any(item["gate"] == "apply" for item in entries):
    raise SystemExit("missing apply gate")
if not any(item["execution_status"] == "blocked" for item in entries):
    raise SystemExit("missing blocked path")
for item in entries:
    missing = required - set(item)
    if missing:
        raise SystemExit(f"{item.get('evidence_id')}: missing fields {sorted(missing)}")
    if item["schema_version"] != "runtime-target-evidence-index/v1":
        raise SystemExit(f"{item['evidence_id']}: bad schema_version")
    if item["target_id"] != target:
        raise SystemExit(f"{item['evidence_id']}: bad target_id")
    if item["gate"] not in allowed_gates:
        raise SystemExit(f"{item['evidence_id']}: bad gate")
    if item["write_scope"] not in allowed_scopes:
        raise SystemExit(f"{item['evidence_id']}: bad write_scope")
    if item["execution_status"] not in allowed_status:
        raise SystemExit(f"{item['evidence_id']}: bad execution_status")
    if item["approval_status"] not in allowed_approval_status:
        raise SystemExit(f"{item['evidence_id']}: bad approval_status")
    if item["write_scope"] in {"live-root", "rollback-live-root"} and item["approval_required"] != "yes":
        raise SystemExit(f"{item['evidence_id']}: live write without approval")
    if item["execution_status"] in {"passed", "failed", "approved"} and str(item["command"]).startswith("<"):
        raise SystemExit(f"{item['evidence_id']}: completed placeholder command")
PY
  then
    return 0
  fi
  record_fail "$(basename "${file}") jsonl contract mismatch"
}

for target in "${TARGETS[@]}"; do
  if [[ -z "${target}" ]]; then
    record_fail "empty --target"
    continue
  fi
  out="${TMP_DIR}/${target}.md"
  jsonl_out="${TMP_DIR}/${target}.jsonl"
  if ! "${ROOT}/scripts/generate-runtime-target-evidence-index.sh" "${ROOT}" --target "${target}" --format both --out "${out}" --jsonl-out "${jsonl_out}" >/dev/null; then
    record_fail "generator failed for target: ${target}"
    continue
  fi

  assert_contains "${out}" "# Runtime Target Evidence Index: ${target}"
  assert_contains "${out}" "| Evidence ID | Target ID | Gate | Command | Exit Code | Expected Result | Result Summary | Write Scope | Artifact / Report | Layer | Related Artifact | Approval Required | Approval Status | Status |"
  assert_contains "${out}" "reports/runtime-target-activation/${target}/explain-target.json"
  assert_contains "${out}" "reports/runtime-target-activation/${target}/evidence-index.md"
  assert_contains "${out}" "reports/runtime-target-activation/${target}/evidence-index.jsonl"
  assert_contains "${out}" "Real apply, live root writes and real rollback require explicit human approval."
  assert_contains "${out}" "required_evidence is not artifact evidence; declaration gate only."
  assert_contains "${out}" "check-runtime-targets.sh"
  assert_contains "${out}" "live-root"
  assert_contains "${out}" "yes"
  assert_contains "${out}" "required"
  assert_contains "${out}" "RuntimeTarget"
  assert_jsonl_contract "${jsonl_out}" "${target}"

  if rg -q --fixed-strings -- "| pending |" "${out}"; then
    record_fail "${target} uses non-enum pending status"
  fi
  if rg -q --fixed-strings -- "temp only" "${out}"; then
    record_fail "${target} uses non-enum write scope"
  fi
  if ! rg -q --fixed-strings -- "-APPLY-001" "${out}"; then
    record_fail "${target} missing apply gate"
  fi
  if ! rg -q --fixed-strings -- "| live-root |" "${out}"; then
    record_fail "${target} missing live-root write scope"
  fi
  if ! rg -q --fixed-strings -- "| yes | required | blocked |" "${out}"; then
    record_fail "${target} missing blocked approval row"
  fi
done

if (( FAILURES > 0 )); then
  echo "[SUMMARY] runtime target evidence index check failed: ${FAILURES}" >&2
  exit 1
fi

echo "[PASS] runtime target evidence index templates ready"
