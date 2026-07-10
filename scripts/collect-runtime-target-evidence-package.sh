#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGET_ID=""
PROFILE="minimal"
OUT_DIR=""
TIMESTAMP=""
SUMMARY_JSON=0
PROMOTE_CURRENT=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

usage() {
  cat <<USAGE
usage: scripts/collect-runtime-target-evidence-package.sh [root] --target <id> [--profile minimal|security|strict] [--out-dir <dir>] [--timestamp <stamp>] [--promote-current] [--summary-json]

Collects a report-only runtime target activation evidence package. The command
runs only read-only gates, writes artifacts under reports/runtime-target-activation
or the explicit --out-dir, and never runs source-to-live apply, rollback or live
root writes. By default it writes only a timestamped package. With
--promote-current, it first validates the generated package with
check-runtime-target-evidence-index.sh --strict-artifacts, then refreshes the
canonical evidence-index.jsonl, evidence-index.md and current-status.md for the
target. Promotion requires --out-dir to stay under
reports/runtime-target-activation/<target-id>/ and never changes target enabled
state.
USAGE
}

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "${value}"
}

fail_with_summary() {
  local error_code="$1"
  local message="$2"
  local exit_code="${3:-1}"
  local print_usage="${4:-0}"
  echo "[FAIL] ${message}" >&2
  if [[ "${SUMMARY_JSON}" -eq 1 ]]; then
    printf '{"status":"fail","target_id":%s,"error_code":%s,"message":%s}\n' \
      "$(json_string "${TARGET_ID}")" \
      "$(json_string "${error_code}")" \
      "$(json_string "${message}")"
  fi
  if [[ "${print_usage}" -eq 1 ]]; then
    usage >&2
  fi
  exit "${exit_code}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET_ID="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --timestamp)
      TIMESTAMP="${2:-}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    --promote-current)
      PROMOTE_CURRENT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail_with_summary "RUNTIME_TARGET_EVIDENCE_UNKNOWN_ARG" "unknown arg: $1" 1 1
      ;;
  esac
done

if [[ -z "${TARGET_ID}" ]]; then
  fail_with_summary "RUNTIME_TARGET_EVIDENCE_TARGET_REQUIRED" "--target is required" 1 1
fi

if [[ -z "${TIMESTAMP}" ]]; then
  TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
fi

if [[ -z "${OUT_DIR}" ]]; then
  OUT_DIR="${ROOT}/reports/runtime-target-activation/${TARGET_ID}/${TIMESTAMP}"
fi

python3 - "$ROOT" "$TARGET_ID" "$PROFILE" "$OUT_DIR" "$TIMESTAMP" "$SUMMARY_JSON" "$PROMOTE_CURRENT" <<'PY'
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

root, target_id, profile, out_dir, timestamp, summary_json_text, promote_current_text = sys.argv[1:8]
root = os.path.abspath(root)
out_dir = os.path.abspath(out_dir)
summary_json = summary_json_text == "1"
promote_current = promote_current_text == "1"
manifest_path = os.path.join(root, "manifests", "runtime_targets.json")
adapters_path = os.path.join(root, "manifests", "runtime_health_adapters.json")


def read_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def target_prefix(value):
    return re.sub(r"[^A-Z0-9]+", "-", value.upper()).strip("-")


def compact(text, limit=220):
    value = " ".join((text or "").split())
    return value[:limit] + ("..." if len(value) > limit else "")


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fail(message, code=1, error_code="RUNTIME_TARGET_EVIDENCE_ERROR", details=None):
    print(f"[FAIL] {message}", file=sys.stderr)
    if details:
        print(str(details).rstrip(), file=sys.stderr)
    if summary_json:
        payload = {
            "status": "fail",
            "target_id": target_id,
            "timestamp": timestamp,
            "out_dir": out_dir,
            "error_code": error_code,
            "message": message,
        }
        if details:
            payload["details"] = compact(str(details), 500)
        print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    sys.exit(code)


def atomic_copy(src, dst):
    tmp = f"{dst}.tmp-{os.getpid()}"
    shutil.copyfile(src, tmp)
    os.replace(tmp, dst)


def atomic_write_text(path, text):
    tmp = f"{path}.tmp-{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.replace(tmp, path)


def split_runtime_activation_path(path):
    absolute = os.path.abspath(path)
    marker = os.sep + os.path.join("reports", "runtime-target-activation") + os.sep
    if marker in absolute:
        artifact_root, suffix = absolute.split(marker, 1)
        return artifact_root.rstrip(os.sep) or os.sep, os.path.normpath(os.path.join("reports", "runtime-target-activation", suffix))
    return None, None


def rel_artifact(path):
    artifact_root, rel = split_runtime_activation_path(path)
    if artifact_root is not None:
        return artifact_root, rel
    absolute = os.path.abspath(path)
    return root, os.path.relpath(absolute, root)


def validate_promotion_out_dir(path, target):
    artifact_root, rel = split_runtime_activation_path(path)
    expected_base = os.path.join("reports", "runtime-target-activation", target)
    if artifact_root is None:
        fail(f"--promote-current requires --out-dir under reports/runtime-target-activation/{target}/", error_code="RUNTIME_TARGET_EVIDENCE_PROMOTE_OUT_DIR_REQUIRED")
    if rel == expected_base:
        fail(f"--promote-current --out-dir must be a package subdirectory under {expected_base}/", error_code="RUNTIME_TARGET_EVIDENCE_PROMOTE_PACKAGE_DIR_REQUIRED")
    if not rel.startswith(expected_base + os.sep):
        fail(f"--promote-current --out-dir must stay under {expected_base}/", error_code="RUNTIME_TARGET_EVIDENCE_PROMOTE_OUT_DIR_SCOPE")
    expected_abs_base = os.path.join(artifact_root, expected_base)
    real_expected_base = os.path.realpath(expected_abs_base)
    real_path = os.path.realpath(os.path.abspath(path))
    if real_path == real_expected_base or not real_path.startswith(real_expected_base + os.sep):
        fail(f"--promote-current --out-dir realpath must stay under {expected_base}/", error_code="RUNTIME_TARGET_EVIDENCE_PROMOTE_REALPATH_SCOPE")
    return artifact_root


def forced_strict_failure_code():
    value = os.environ.get("ADK_TEST_RUNTIME_TARGET_EVIDENCE_FORCE_STRICT_FAIL", "")
    if not value:
        return None
    if not re.fullmatch(r"[0-9]+", value):
        fail("ADK_TEST_RUNTIME_TARGET_EVIDENCE_FORCE_STRICT_FAIL must be a non-zero integer", error_code="RUNTIME_TARGET_EVIDENCE_FORCE_STRICT_FAIL_CONFIG")
    code = int(value)
    if code <= 0 or code > 255:
        fail("ADK_TEST_RUNTIME_TARGET_EVIDENCE_FORCE_STRICT_FAIL must be between 1 and 255", error_code="RUNTIME_TARGET_EVIDENCE_FORCE_STRICT_FAIL_CONFIG")
    return code


def run_capture(name, command_label, argv):
    artifact = os.path.join(out_dir, name)
    proc = subprocess.run(argv, cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    with open(artifact, "w", encoding="utf-8") as handle:
        handle.write(proc.stdout)
    _artifact_root, rel = rel_artifact(artifact)
    return {
        "artifact": artifact,
        "artifact_path": rel,
        "artifact_sha256": sha256(artifact),
        "exit_code": proc.returncode,
        "summary": compact(proc.stdout),
        "command": command_label,
    }


def entry(evidence_id, gate, command, expected, scope, artifact_path, approval_required,
          approval_status, status, result_summary, exit_code=None, artifact_hash=None,
          artifact_exists=False, related="-", notes=""):
    return {
        "schema_version": "runtime-target-evidence-index/v1",
        "evidence_id": evidence_id,
        "target_id": target_id,
        "runtime": target.get("runtime"),
        "gate": gate,
        "command": command,
        "exit_code": exit_code,
        "expected_result": expected,
        "result_summary": result_summary,
        "write_scope": scope,
        "artifact_path": artifact_path,
        "artifact_exists": artifact_exists,
        "artifact_sha256": artifact_hash,
        "layer": "RuntimeTarget",
        "related_artifact": related,
        "approval_required": approval_required,
        "approval_status": approval_status,
        "approved_by": None,
        "approved_at": None,
        "approval_scope": None,
        "execution_status": status,
        "created_at": generated_at,
        "notes": notes,
    }


manifest = read_json(manifest_path)
adapters_manifest = read_json(adapters_path)
targets = manifest.get("targets") or []
target = next((item for item in targets if item.get("id") == target_id), None)
if not target:
    fail(f"runtime target not declared: {target_id}", error_code="RUNTIME_TARGET_EVIDENCE_TARGET_NOT_DECLARED")

promotion_artifact_root = None
if promote_current:
    promotion_artifact_root = validate_promotion_out_dir(out_dir, target_id)

os.makedirs(out_dir, exist_ok=True)

adapter_id = target.get("health_adapter")
adapters = adapters_manifest.get("adapters") or []
adapter = next((item for item in adapters if item.get("id") == adapter_id), None)
prefix = target_prefix(target_id)
generated_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
entries = []

explain = run_capture(
    "explain-target.json",
    f"rtk scripts/check-runtime-targets.sh . --explain-target {target_id}",
    [os.path.join(root, "scripts", "check-runtime-targets.sh"), root, "--explain-target", target_id],
)
activation_ready = False
try:
    activation_ready = json.loads(open(explain["artifact"], encoding="utf-8").read()).get("activation_ready") is True
except Exception:
    activation_ready = False
entries.append(entry(
    f"{prefix}-DECL-001",
    "declare",
    explain["command"],
    "activation_ready=true for active targets; clear next_action for candidates",
    "read-only",
    explain["artifact_path"],
    "no",
    "not-required",
    "passed" if explain["exit_code"] == 0 and activation_ready else "blocked",
    explain["summary"],
    exit_code=explain["exit_code"],
    artifact_hash=explain["artifact_sha256"],
    artifact_exists=True,
))

targets_summary = run_capture(
    "runtime-targets.json",
    "rtk scripts/check-runtime-targets.sh . --summary-json",
    [os.path.join(root, "scripts", "check-runtime-targets.sh"), root, "--summary-json"],
)
entries.append(entry(
    f"{prefix}-TARGETS-001",
    "declare",
    targets_summary["command"],
    "status=pass",
    "read-only",
    targets_summary["artifact_path"],
    "no",
    "not-required",
    "passed" if targets_summary["exit_code"] == 0 else "failed",
    targets_summary["summary"],
    exit_code=targets_summary["exit_code"],
    artifact_hash=targets_summary["artifact_sha256"],
    artifact_exists=True,
))

adapters_fixture = run_capture(
    "adapter-fixtures.md",
    "rtk scripts/check-runtime-health-adapters-fixtures.sh .",
    [os.path.join(root, "scripts", "check-runtime-health-adapters-fixtures.sh"), root],
)
entries.append(entry(
    f"{prefix}-ADAPTERS-001",
    "health",
    adapters_fixture["command"],
    "fixture pass and adapter contract remains read-only",
    "workspace-local",
    adapters_fixture["artifact_path"],
    "no",
    "not-required",
    "passed" if adapters_fixture["exit_code"] == 0 else "failed",
    adapters_fixture["summary"],
    exit_code=adapters_fixture["exit_code"],
    artifact_hash=adapters_fixture["artifact_sha256"],
    artifact_exists=True,
    related="adapter contract",
))

enabled = target.get("enabled") is True
adapter_ready = bool(adapter and adapter.get("enabled") is True and adapter.get("status") == "active")
if enabled and adapter_ready:
    health = run_capture(
        "runtime-health.json",
        f"rtk scripts/check-runtime-health.sh . --target {target_id} --profile {profile} --summary-json",
        [os.path.join(root, "scripts", "check-runtime-health.sh"), root, "--target", target_id, "--profile", profile, "--summary-json"],
    )
    entries.append(entry(
        f"{prefix}-HEALTH-001",
        "health",
        health["command"],
        "status=pass",
        "read-only",
        health["artifact_path"],
        "no",
        "not-required",
        "passed" if health["exit_code"] == 0 else "failed",
        health["summary"],
        exit_code=health["exit_code"],
        artifact_hash=health["artifact_sha256"],
        artifact_exists=True,
        related="runtime health",
    ))
else:
    entries.append(entry(
        f"{prefix}-HEALTH-001",
        "health",
        f"rtk scripts/check-runtime-health.sh . --target {target_id} --profile {profile} --summary-json",
        "status=pass",
        "read-only",
        f"reports/runtime-target-activation/{target_id}/{timestamp}/runtime-health.json",
        "no",
        "not-required",
        "blocked",
        "not executed: target or adapter is not active",
        related="runtime health",
    ))

default_target = manifest.get("default_target")
footprint_script = target.get("footprint_check")
if enabled and footprint_script and target_id == default_target:
    footprint = run_capture(
        "footprint-policy.json",
        "rtk scripts/check-runtime-live-footprint.sh . --summary-json",
        [os.path.join(root, "scripts", "check-runtime-live-footprint.sh"), root, "--summary-json"],
    )
    entries.append(entry(
        f"{prefix}-FOOTPRINT-001",
        "footprint",
        footprint["command"],
        "no missing required assets and no unexplained overwrite/delete",
        "read-only",
        footprint["artifact_path"],
        "no",
        "not-required",
        "passed" if footprint["exit_code"] == 0 else "failed",
        footprint["summary"],
        exit_code=footprint["exit_code"],
        artifact_hash=footprint["artifact_sha256"],
        artifact_exists=True,
        related="footprint policy",
    ))
else:
    entries.append(entry(
        f"{prefix}-FOOTPRINT-001",
        "footprint",
        footprint_script or "<target footprint command>",
        "no missing required assets and no unexplained overwrite/delete",
        "read-only",
        f"reports/runtime-target-activation/{target_id}/{timestamp}/footprint-policy.json",
        "no",
        "not-required",
        "blocked",
        "not executed: target is not default active runtime or footprint command is missing",
        related="footprint policy",
    ))

for suffix, gate, command, expected, scope, artifact, approval, approval_status, status, related, summary in (
    ("PLAN", "dry-run", "<source repo plan command>", "plan generated and reviewed", "source-repo-only", "apply-plan.md", "no", "not-required", "blocked", "source-to-live plan", "not executed by collector"),
    ("DRYRUN", "dry-run", "<source repo apply dry-run>", "dry-run only; no live root write", "source-repo-only", "apply-dry-run.md", "no", "not-required", "blocked", "source-to-live dry-run", "not executed by collector"),
    ("ROLLBACK", "rollback", "<rollback dry-run or documented procedure>", "rollback path reviewed; real rollback requires approval", "read-only", "rollback.md", "yes", "required", "blocked", "rollback plan", "not executed by collector"),
    ("APPLY", "apply", "<source repo apply command>", "live root updated only within approved scope", "live-root", "apply-report.md", "yes", "required", "blocked", "apply report", "not executed by collector"),
):
    entries.append(entry(
        f"{prefix}-{suffix}-001",
        gate,
        command,
        expected,
        scope,
        f"reports/runtime-target-activation/{target_id}/{timestamp}/{artifact}",
        approval,
        approval_status,
        status,
        summary,
        related=related,
    ))

jsonl_path = os.path.join(out_dir, "evidence-index.jsonl")
with open(jsonl_path, "w", encoding="utf-8") as handle:
    for item in entries:
        handle.write(json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n")

md_path = os.path.join(out_dir, "evidence-index.md")
with open(md_path, "w", encoding="utf-8") as handle:
    handle.write(f"# Runtime Target Evidence Package: {target_id}\n\n")
    handle.write(f"- generated_at: {generated_at}\n")
    handle.write(f"- target_id: {target_id}\n")
    handle.write(f"- timestamp: {timestamp}\n")
    handle.write(f"- evidence_index_jsonl: {os.path.relpath(jsonl_path, root) if os.path.commonpath([os.path.abspath(root), os.path.abspath(jsonl_path)]) == os.path.abspath(root) else jsonl_path}\n\n")
    handle.write("| Evidence ID | Gate | Command | Exit Code | Artifact | Status |\n")
    handle.write("|---|---|---|---:|---|---|\n")
    for item in entries:
        exit_code = "-" if item["exit_code"] is None else str(item["exit_code"])
        handle.write(f"| {item['evidence_id']} | {item['gate']} | `{item['command']}` | {exit_code} | `{item['artifact_path']}` | {item['execution_status']} |\n")

status = "pass" if all(item["execution_status"] != "failed" for item in entries) else "needs-fix"
completed_count = sum(1 for item in entries if item["execution_status"] in {"passed", "failed", "approved"})
blocked_count = sum(1 for item in entries if item["execution_status"] == "blocked")
promoted = False
canonical_index = None
canonical_markdown = None
current_status = None
strict_command_label = None

if promote_current and status != "pass":
    fail(f"evidence package status is {status}; current evidence was not promoted", error_code="RUNTIME_TARGET_EVIDENCE_PACKAGE_NOT_PASS")

if promote_current:
    artifact_root = promotion_artifact_root
    canonical_dir = os.path.join(artifact_root, "reports", "runtime-target-activation", target_id)
    canonical_index = os.path.join(canonical_dir, "evidence-index.jsonl")
    canonical_markdown = os.path.join(canonical_dir, "evidence-index.md")
    current_status = os.path.join(canonical_dir, "current-status.md")
    checker = os.path.join(root, "scripts", "check-runtime-target-evidence-index.sh")
    strict_command = [
        checker,
        artifact_root,
        "--target",
        target_id,
        "--index",
        jsonl_path,
        "--strict-artifacts",
    ]
    strict_command_label = (
        "rtk scripts/check-runtime-target-evidence-index.sh "
        f"{artifact_root} --target {target_id} --index {jsonl_path} --strict-artifacts"
    )
    proc = subprocess.run(
        strict_command,
        cwd=root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    strict_returncode = proc.returncode
    strict_output = proc.stdout
    forced_code = forced_strict_failure_code()
    if forced_code is not None:
        strict_returncode = forced_code
        injected = "[FAIL] injected strict artifact failure"
        strict_output = (strict_output.rstrip() + "\n" + injected + "\n") if strict_output else injected + "\n"
    if strict_returncode != 0:
        fail(
            "strict artifact validation failed; current evidence was not promoted",
            code=strict_returncode,
            error_code="RUNTIME_TARGET_EVIDENCE_STRICT_VALIDATION_FAILED",
            details=strict_output,
        )
    os.makedirs(canonical_dir, exist_ok=True)
    for src, dst in ((jsonl_path, canonical_index), (md_path, canonical_markdown)):
        if os.path.abspath(src) != os.path.abspath(dst):
            atomic_copy(src, dst)
    source_display = os.path.relpath(out_dir, artifact_root) if os.path.commonpath([os.path.abspath(artifact_root), os.path.abspath(out_dir)]) == os.path.abspath(artifact_root) else out_dir
    index_display = os.path.relpath(canonical_index, artifact_root)
    markdown_display = os.path.relpath(canonical_markdown, artifact_root)
    current_display = os.path.relpath(current_status, artifact_root)
    current_status_text = "\n".join([
        f"# Runtime Target Current Evidence: {target_id}",
        "",
        f"- promoted_at: {generated_at}",
        f"- target_id: {target_id}",
        f"- target_enabled: {str(enabled).lower()}",
        f"- target_role: {target.get('role')}",
        f"- activation_ready: {str(activation_ready).lower()}",
        f"- source_package: {source_display}",
        f"- evidence_index_jsonl: {index_display}",
        f"- evidence_index_md: {markdown_display}",
        f"- current_status: {current_display}",
        f"- strict_check: `{strict_command_label}`",
        f"- entries: {len(entries)}",
        f"- completed: {completed_count}",
        f"- blocked: {blocked_count}",
        "- write_scope: report-only; no source-to-live apply, rollback or live-root write was executed by this collector.",
        "- target_state: active and candidate targets may be promoted only as evidence pointers; promotion never changes enabled state.",
        "- promotion_rule: canonical files are refreshed only after strict artifact validation passes.",
        "",
    ])
    atomic_write_text(current_status, current_status_text)
    promoted = True

if summary_json:
    print(json.dumps({
        "status": status,
        "target_id": target_id,
        "timestamp": timestamp,
        "out_dir": out_dir,
        "evidence_index": jsonl_path,
        "entries": len(entries),
        "completed": completed_count,
        "blocked": blocked_count,
        "promoted": promoted,
        "canonical_index": canonical_index,
        "canonical_markdown": canonical_markdown,
        "current_status": current_status,
        "strict_check": strict_command_label,
        "target_enabled": enabled,
        "activation_ready": activation_ready,
        "error_code": None,
        "message": None,
    }, ensure_ascii=False, separators=(",", ":")))
else:
    if promoted:
        print(f"[PASS] runtime target evidence package written and promoted: {out_dir}")
    else:
        print(f"[PASS] runtime target evidence package written: {out_dir}")

sys.exit(0 if status == "pass" else 1)
PY
