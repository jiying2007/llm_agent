#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGETS=()
INDEX_PATH=""
REQUIRE_INDEX=0
STRICT_ARTIFACTS=0
SUMMARY_JSON=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

usage() {
  cat <<USAGE
usage: scripts/check-runtime-target-evidence-index.sh [root] [--target <id> ...] [--index <path>] [--require-index] [--strict-artifacts] [--summary-json]

Generates runtime target activation Evidence Index drafts in a temporary
directory and validates stable markdown/jsonl schema markers, status enums and
approval boundaries. With --index or --require-index it validates persisted
evidence-index.jsonl packages. The command is read-only for the repository.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGETS+=("${2:-}")
      shift 2
      ;;
    --index)
      INDEX_PATH="${2:-}"
      shift 2
      ;;
    --require-index)
      REQUIRE_INDEX=1
      shift
      ;;
    --strict-artifacts)
      STRICT_ARTIFACTS=1
      shift
      ;;
    --summary-json)
      SUMMARY_JSON=1
      shift
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

if [[ "${STRICT_ARTIFACTS}" -eq 1 && -z "${INDEX_PATH}" && "${REQUIRE_INDEX}" -eq 0 ]]; then
  if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
    printf '{"status":"fail","mode":"generated","targets":%s,"checked":0,"strict_artifacts":true,"require_index":false,"failures":1}\n' "${#TARGETS[@]}"
  else
    echo "[FAIL] --strict-artifacts requires --index or --require-index" >&2
  fi
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAILURES=0
CHECKED=0
MODE="generated"

record_fail() {
  if [[ "${SUMMARY_JSON}" -eq 0 ]]; then
    echo "[FAIL] $*" >&2
  fi
  FAILURES=$((FAILURES + 1))
}

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

json_summary() {
  local status="$1"
  printf '{"status":%s,"mode":%s,"targets":%s,"checked":%s,"strict_artifacts":%s,"require_index":%s,"failures":%s}\n' \
    "$(json_string "${status}")" \
    "$(json_string "${MODE}")" \
    "${#TARGETS[@]}" \
    "${CHECKED}" \
    "$([[ "${STRICT_ARTIFACTS}" -eq 1 ]] && echo true || echo false)" \
    "$([[ "${REQUIRE_INDEX}" -eq 1 ]] && echo true || echo false)" \
    "${FAILURES}"
}

assert_contains() {
  local file="$1"
  local token="$2"
  if [[ ! -f "${file}" ]]; then
    record_fail "file missing: ${file}"
    return
  fi
  if ! rg -q --fixed-strings -- "${token}" "${file}"; then
    record_fail "$(basename "${file}") missing token: ${token}"
  fi
}

assert_jsonl_contract() {
  local file="$1"
  local target="$2"
  local strict="$3"
  if python3 - "$file" "$target" "$strict" "$ROOT" <<'PY'
import hashlib
import json
import os
import sys

path, target, strict_text, root = sys.argv[1:5]
strict = strict_text == "1"
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
    "approved_by",
    "approved_at",
    "approval_scope",
    "execution_status",
    "created_at",
    "notes",
}

def artifact_abs(path_value):
    if os.path.isabs(path_value):
        return path_value
    return os.path.join(root, path_value)

def sha256(path_value):
    digest = hashlib.sha256()
    with open(path_value, "rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()

entries = []
seen_ids = set()
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
    if item["evidence_id"] in seen_ids:
        raise SystemExit(f"{item['evidence_id']}: duplicate evidence_id")
    seen_ids.add(item["evidence_id"])
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
    if item["execution_status"] in {"passed", "failed", "approved"} and item["exit_code"] is None:
        raise SystemExit(f"{item['evidence_id']}: completed evidence missing exit_code")
    if item["execution_status"] in {"passed", "approved"} and item["exit_code"] != 0:
        raise SystemExit(f"{item['evidence_id']}: passed evidence must have exit_code=0")
    if item["execution_status"] == "failed" and item["exit_code"] == 0:
        raise SystemExit(f"{item['evidence_id']}: failed evidence must have nonzero exit_code")
    if item["approval_required"] == "yes" and item["execution_status"] in {"passed", "approved"}:
        if item["approval_status"] != "approved":
            raise SystemExit(f"{item['evidence_id']}: approved evidence missing approval_status=approved")
        for field in ("approved_by", "approved_at", "approval_scope"):
            if not item.get(field):
                raise SystemExit(f"{item['evidence_id']}: approved evidence missing {field}")
    if item["approval_status"] in {"denied", "expired"} and item["execution_status"] in {"passed", "approved"}:
        raise SystemExit(f"{item['evidence_id']}: denied or expired approval cannot pass")
    if strict and item["execution_status"] in {"passed", "failed", "approved"}:
        artifact_value = str(item["artifact_path"])
        if os.path.isabs(artifact_value):
            raise SystemExit(f"{item['evidence_id']}: artifact_path must be relative")
        normalized = os.path.normpath(artifact_value)
        if normalized.startswith("..") or "/../" in normalized:
            raise SystemExit(f"{item['evidence_id']}: artifact_path escapes root")
        expected_prefix = os.path.join("reports", "runtime-target-activation", target) + os.sep
        if not normalized.startswith(expected_prefix):
            raise SystemExit(f"{item['evidence_id']}: artifact_path outside target evidence dir")
        artifact_path = artifact_abs(item["artifact_path"])
        if not os.path.isfile(artifact_path):
            raise SystemExit(f"{item['evidence_id']}: artifact missing: {item['artifact_path']}")
        if os.path.islink(artifact_path) and not os.path.realpath(artifact_path).startswith(os.path.realpath(root) + os.sep):
            raise SystemExit(f"{item['evidence_id']}: artifact symlink escapes root")
        if item.get("artifact_exists") is not True:
            raise SystemExit(f"{item['evidence_id']}: artifact_exists must be true")
        expected_hash = item.get("artifact_sha256")
        if not expected_hash or not isinstance(expected_hash, str) or len(expected_hash) != 64 or any(ch not in "0123456789abcdef" for ch in expected_hash):
            raise SystemExit(f"{item['evidence_id']}: artifact_sha256 missing")
        actual_hash = sha256(artifact_path)
        if actual_hash != expected_hash:
            raise SystemExit(f"{item['evidence_id']}: artifact_sha256 mismatch")
    elif strict and item.get("artifact_sha256"):
        artifact_path = artifact_abs(item["artifact_path"])
        if not os.path.isfile(artifact_path):
            raise SystemExit(f"{item['evidence_id']}: hashed artifact missing")
        if sha256(artifact_path) != item["artifact_sha256"]:
            raise SystemExit(f"{item['evidence_id']}: artifact_sha256 mismatch")
PY
  then
    CHECKED=$((CHECKED + 1))
    return 0
  fi
  record_fail "$(basename "${file}") jsonl contract mismatch"
}

validate_generated_target() {
  local target="$1"
  if [[ -z "${target}" ]]; then
    record_fail "empty --target"
    return
  fi
  local out="${TMP_DIR}/${target}.md"
  local jsonl_out="${TMP_DIR}/${target}.jsonl"
  if ! "${ROOT}/scripts/generate-runtime-target-evidence-index.sh" "${ROOT}" --target "${target}" --format both --out "${out}" --jsonl-out "${jsonl_out}" >/dev/null; then
    record_fail "generator failed for target: ${target}"
    return
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
  assert_jsonl_contract "${jsonl_out}" "${target}" "${STRICT_ARTIFACTS}"

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
}

validate_index_file() {
  local index="$1"
  local target="$2"
  if [[ -z "${index}" ]]; then
    record_fail "empty --index"
    return
  fi
  if [[ ! -f "${index}" ]]; then
    record_fail "index missing: ${index}"
    return
  fi
  if [[ "${index}" == *.md ]]; then
    assert_contains "${index}" "| Evidence ID | Target ID | Gate | Command | Exit Code | Expected Result | Result Summary | Write Scope | Artifact / Report | Layer | Related Artifact | Approval Required | Approval Status | Status |"
    local sibling="${index%/*}/evidence-index.jsonl"
    if [[ -f "${sibling}" ]]; then
      assert_jsonl_contract "${sibling}" "${target}" "${STRICT_ARTIFACTS}"
    elif [[ "${STRICT_ARTIFACTS}" -eq 1 || "${REQUIRE_INDEX}" -eq 1 ]]; then
      record_fail "$(basename "${index}") missing sibling evidence-index.jsonl"
    else
      CHECKED=$((CHECKED + 1))
    fi
    return
  fi
  assert_jsonl_contract "${index}" "${target}" "${STRICT_ARTIFACTS}"
}

if [[ -n "${INDEX_PATH}" ]]; then
  MODE="index"
  if [[ "${#TARGETS[@]}" -ne 1 ]]; then
    record_fail "--index requires exactly one --target"
  else
    validate_index_file "${INDEX_PATH}" "${TARGETS[0]}"
  fi
elif [[ "${REQUIRE_INDEX}" -eq 1 ]]; then
  MODE="require-index"
  for target in "${TARGETS[@]}"; do
    validate_index_file "${ROOT}/reports/runtime-target-activation/${target}/evidence-index.jsonl" "${target}"
  done
else
  MODE="generated"
  for target in "${TARGETS[@]}"; do
    validate_generated_target "${target}"
  done
fi

if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
  if (( FAILURES > 0 )); then
    json_summary "fail"
  else
    json_summary "pass"
  fi
else
  if (( FAILURES > 0 )); then
    echo "[SUMMARY] runtime target evidence index check failed: ${FAILURES}" >&2
  else
    echo "[PASS] runtime target evidence index templates ready"
  fi
fi

if (( FAILURES > 0 )); then
  exit 1
fi
