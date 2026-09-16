#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${ROOT}/scripts/check-runtime-targets.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

write_fixture() {
  rm -rf "${TMP_DIR:?}"/*
  mkdir -p "${TMP_DIR}/manifests" "${TMP_DIR}/scripts" "${TMP_DIR}/subrepos"
  printf 'codex.source=~/codex\ncodex.target=~/.codex\n' >"${TMP_DIR}/adk.lock"
  printf 'repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade\ncodex,runtime-target,0,manual,main,no,"~/codex to ~/.codex",disabled,adk-team,2026-07-09,pilot-first,A\n' >"${TMP_DIR}/subrepos/registry.csv"
  for script in check-global-codex-health.sh check-claude-code-health.sh check-runtime-live-footprint.sh check-global-codex-target-policy.sh; do
    printf '#!/usr/bin/env bash\nexit 0\n' >"${TMP_DIR}/scripts/${script}"
    chmod +x "${TMP_DIR}/scripts/${script}"
  done
  python3 - "${TMP_DIR}" <<'PY'
import json
import os
import sys

root = sys.argv[1]
targets = {
    "schema_version": 1,
    "status": "active",
    "last_updated": "2026-07-09",
    "default_target": "codex-home",
    "supported_runtime_kinds": ["codex", "claude-code", "opencode"],
    "rules": {
        "targets_must_be_declared": True,
        "live_writes_must_use_declared_apply_chain": True,
        "llm_agent_must_not_write_live_root": True,
        "reference_subrepos_must_not_be_runtime_targets": True,
        "future_targets_require_source_and_live_chain": True,
    },
    "targets": [
        {
            "id": "codex-home",
            "runtime": "codex",
            "role": "external-handoff-target",
            "enabled": True,
            "source_repo": "~/codex",
            "live_root": "~/.codex",
            "registry_repo": "codex",
            "source_to_live_chain": ["agent-dev-kit", "~/codex", "~/.codex"],
            "health_adapter": "codex-global-health",
            "footprint_check": "scripts/check-runtime-live-footprint.sh",
            "target_policy_check": "scripts/check-global-codex-target-policy.sh",
            "runtime_footprint": {
                "required_skills": ["adk-runtime-router"],
                "forbidden_skills": ["using-superpowers"],
                "forbidden_paths": ["vendor/plugins/superpowers"],
            },
            "required_evidence": [
                "~/codex build",
                "~/codex doctor",
                "~/codex apply plan",
                "~/codex apply dry-run",
                "rollback evidence",
                "global runtime health",
                "runtime live footprint",
            ],
            "write_policy": "report-only-from-llm_agent",
        },
        {
            "id": "claude-code-home",
            "runtime": "claude-code",
            "role": "target-candidate",
            "enabled": False,
            "source_repo": None,
            "live_root": None,
            "registry_repo": None,
            "source_to_live_chain": [],
            "health_adapter": None,
            "footprint_check": None,
            "target_policy_check": None,
            "required_evidence": ["declared source repo", "declared live root", "read-only health adapter", "dry-run apply evidence", "rollback evidence"],
            "write_policy": "not-enabled",
            "activation_requirements": [
                "declare source_repo and live_root",
                "add read-only health adapter",
                "add source-to-live apply and rollback evidence",
                "pass runtime target gate with enabled=true",
            ],
        },
        {
            "id": "opencode-home",
            "runtime": "opencode",
            "role": "target-candidate",
            "enabled": False,
            "source_repo": None,
            "live_root": None,
            "registry_repo": None,
            "source_to_live_chain": [],
            "health_adapter": None,
            "footprint_check": None,
            "target_policy_check": None,
            "required_evidence": ["declared source repo", "declared live root", "read-only health adapter", "dry-run apply evidence", "rollback evidence"],
            "write_policy": "not-enabled",
            "activation_requirements": [
                "declare source_repo and live_root",
                "add read-only health adapter",
                "add source-to-live apply and rollback evidence",
                "pass runtime target gate with enabled=true",
            ],
        },
    ],
}
adapters = {
    "schema_version": 1,
    "status": "active",
    "last_updated": "2026-07-09",
    "rules": {
        "targets_must_reference_adapter_id": True,
        "enabled_adapters_must_be_read_only": True,
        "enabled_adapters_must_have_executable_script": True,
        "disabled_adapters_must_not_dispatch": True,
        "adapter_runtime_must_match_target_runtime": True,
    },
    "adapters": [
        {
            "id": "codex-global-health",
            "runtime": "codex",
            "status": "active",
            "enabled": True,
            "script": "scripts/check-global-codex-health.sh",
            "target_ids": ["codex-home"],
            "profiles": ["minimal", "security", "strict"],
            "read_only": True,
        },
        {"id": "claude-code-health", "runtime": "claude-code", "status": "candidate", "enabled": False, "script": None, "target_ids": [], "profiles": [], "read_only": True, "activation_requirements": ["declare active runtime target", "add executable read-only health script", "bind target.health_adapter to this adapter id", "pass disabled target negative gate before activation"]},
        {"id": "opencode-health", "runtime": "opencode", "status": "candidate", "enabled": False, "script": None, "target_ids": [], "profiles": [], "read_only": True, "activation_requirements": ["declare active runtime target", "add executable read-only health script", "bind target.health_adapter to this adapter id", "pass disabled target negative gate before activation"]},
    ],
}
for name, data in (
    ("runtime_targets.json", targets),
    ("runtime_health_adapters.json", adapters),
):
    with open(os.path.join(root, "manifests", name), "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
PY
}

mutate_json() {
  python3 - "${TMP_DIR}" "$1" <<'PY'
import json
import os
import stat
import sys

root, case = sys.argv[1:3]
targets_path = os.path.join(root, "manifests", "runtime_targets.json")
adapters_path = os.path.join(root, "manifests", "runtime_health_adapters.json")
with open(targets_path, "r", encoding="utf-8") as handle:
    targets = json.load(handle)
with open(adapters_path, "r", encoding="utf-8") as handle:
    adapters = json.load(handle)

adapter = adapters["adapters"][0]
target = targets["targets"][0]

def enable_second_target():
    second_target = targets["targets"][1]
    second_adapter = adapters["adapters"][1]
    second_target.update({
        "role": "external-handoff-target",
        "enabled": True,
        "source_repo": "~/claude-code",
        "live_root": "~/.claude",
        "registry_repo": "claude-code",
        "source_to_live_chain": ["agent-dev-kit", "~/claude-code", "~/.claude"],
        "health_adapter": "claude-code-health",
        "footprint_check": "scripts/check-runtime-live-footprint.sh",
        "target_policy_check": "scripts/check-global-codex-target-policy.sh",
        "runtime_footprint": {
            "required_skills": ["adk-runtime-router"],
            "forbidden_skills": ["using-superpowers"],
            "forbidden_paths": ["vendor/plugins/superpowers"],
        },
        "required_evidence": [
            "declared source repo",
            "declared live root",
            "dry-run apply evidence",
            "rollback evidence",
            "runtime health",
            "runtime live footprint",
        ],
        "write_policy": "report-only-from-llm_agent",
    })
    second_adapter.update({
        "status": "active",
        "enabled": True,
        "script": "scripts/check-claude-code-health.sh",
        "target_ids": ["claude-code-home"],
        "profiles": ["minimal", "security", "strict"],
    })
    second_adapter.pop("activation_requirements", None)
    return second_target, second_adapter

if case == "runtime_mismatch":
    adapter["runtime"] = "opencode"
elif case == "disabled_adapter":
    adapter["enabled"] = False
elif case == "missing_profile":
    adapter["profiles"].remove("strict")
elif case == "missing_binding":
    adapter["target_ids"] = []
elif case == "legacy_target_health_check":
    target["health_check"] = "scripts/check-global-codex-health.sh"
elif case == "script_not_executable":
    script_path = os.path.join(root, "scripts", "check-global-codex-health.sh")
    os.chmod(script_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
elif case == "second_enabled_valid":
    enable_second_target()
elif case == "second_enabled_runtime_mismatch":
    _second_target, second_adapter = enable_second_target()
    second_adapter["runtime"] = "opencode"
elif case == "second_enabled_missing_binding":
    _second_target, second_adapter = enable_second_target()
    second_adapter["target_ids"] = []
elif case == "second_enabled_missing_adapter":
    second_target, _second_adapter = enable_second_target()
    second_target["health_adapter"] = "missing-claude-health"
elif case == "second_enabled_empty_chain":
    second_target, _second_adapter = enable_second_target()
    second_target["source_to_live_chain"] = []
elif case == "missing_runtime_footprint":
    target.pop("runtime_footprint")
else:
    raise SystemExit(f"unknown case: {case}")

with open(targets_path, "w", encoding="utf-8") as handle:
    json.dump(targets, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
with open(adapters_path, "w", encoding="utf-8") as handle:
    json.dump(adapters, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
}

expect_pass() {
  write_fixture
  if [[ "${1:-}" != "" ]]; then
    mutate_json "$1"
  fi
  out="${TMP_DIR}/pass.out"
  if ! "${CHECK}" "${TMP_DIR}" --summary-json >"${out}" 2>&1; then
    echo "[FAIL] runtime adapter pass fixture failed" >&2
    sed -n '1,80p' "${out}" >&2 || true
    exit 1
  fi
}

expect_fail() {
  local case_name="$1"
  local expected="$2"
  write_fixture
  mutate_json "${case_name}"
  out="${TMP_DIR}/${case_name}.out"
  if "${CHECK}" "${TMP_DIR}" --summary-json >"${out}" 2>&1; then
    echo "[FAIL] runtime adapter fixture unexpectedly passed: ${case_name}" >&2
    exit 1
  fi
  if ! rg -q --fixed-strings -- "${expected}" "${out}"; then
    echo "[FAIL] runtime adapter fixture missing expected failure: ${case_name} -> ${expected}" >&2
    sed -n '1,80p' "${out}" >&2 || true
    exit 1
  fi
}

expect_health_fail() {
  local case_name="$1"
  local expected="$2"
  local profile="${3:-minimal}"
  write_fixture
  mutate_json "${case_name}"
  out="${TMP_DIR}/${case_name}-health.out"
  if "${ROOT}/scripts/check-runtime-health.sh" "${TMP_DIR}" --profile "${profile}" --summary-json >"${out}" 2>&1; then
    echo "[FAIL] runtime health fixture unexpectedly passed: ${case_name}" >&2
    exit 1
  fi
  if ! rg -q --fixed-strings -- "${expected}" "${out}"; then
    echo "[FAIL] runtime health fixture missing expected failure: ${case_name} -> ${expected}" >&2
    sed -n '1,80p' "${out}" >&2 || true
    exit 1
  fi
}

expect_health_fail_for_target() {
  local case_name="$1"
  local target_id="$2"
  local expected="$3"
  write_fixture
  mutate_json "${case_name}"
  out="${TMP_DIR}/${case_name}-${target_id}-health.out"
  if "${ROOT}/scripts/check-runtime-health.sh" "${TMP_DIR}" --target "${target_id}" --summary-json >"${out}" 2>&1; then
    echo "[FAIL] runtime health target fixture unexpectedly passed: ${case_name} -> ${target_id}" >&2
    exit 1
  fi
  if ! rg -q --fixed-strings -- "${expected}" "${out}"; then
    echo "[FAIL] runtime health target fixture missing expected failure: ${case_name} -> ${expected}" >&2
    sed -n '1,80p' "${out}" >&2 || true
    exit 1
  fi
}

expect_explain() {
  local target_id="$1"
  local expected="$2"
  write_fixture
  out="${TMP_DIR}/explain-${target_id}.out"
  if ! "${CHECK}" "${TMP_DIR}" --explain-target "${target_id}" >"${out}" 2>&1; then
    echo "[FAIL] explain target unexpectedly failed: ${target_id}" >&2
    sed -n '1,80p' "${out}" >&2 || true
    exit 1
  fi
  if ! rg -q --fixed-strings -- "${expected}" "${out}"; then
    echo "[FAIL] explain target missing expected output: ${target_id} -> ${expected}" >&2
    sed -n '1,80p' "${out}" >&2 || true
    exit 1
  fi
}

expect_explain_fail() {
  local target_id="$1"
  local expected="$2"
  write_fixture
  out="${TMP_DIR}/explain-${target_id}.out"
  if "${CHECK}" "${TMP_DIR}" --explain-target "${target_id}" >"${out}" 2>&1; then
    echo "[FAIL] explain target unexpectedly passed: ${target_id}" >&2
    exit 1
  fi
  if ! rg -q --fixed-strings -- "${expected}" "${out}"; then
    echo "[FAIL] explain target failure missing expected output: ${target_id} -> ${expected}" >&2
    sed -n '1,80p' "${out}" >&2 || true
    exit 1
  fi
}

expect_explain_arg_fail() {
  local expected="$1"
  write_fixture
  out="${TMP_DIR}/explain-arg-fail.out"
  if "${CHECK}" "${TMP_DIR}" --summary-json --explain-target codex-home >"${out}" 2>&1; then
    echo "[FAIL] explain arg fixture unexpectedly passed" >&2
    exit 1
  fi
  if ! rg -q --fixed-strings -- "${expected}" "${out}"; then
    echo "[FAIL] explain arg fixture missing expected output: ${expected}" >&2
    sed -n '1,80p' "${out}" >&2 || true
    exit 1
  fi
}

expect_pass
expect_pass "second_enabled_valid"
expect_fail "runtime_mismatch" "enabled runtime target health_adapter runtime mismatch: codex-home -> codex-global-health"
expect_fail "disabled_adapter" "enabled runtime target health_adapter must be enabled: codex-home -> codex-global-health"
expect_fail "missing_profile" "enabled runtime health adapter missing profile: codex-global-health -> strict"
expect_fail "script_not_executable" "runtime target script not executable: scripts/check-global-codex-health.sh"
expect_fail "missing_binding" "enabled runtime target health_adapter missing target binding: codex-home -> codex-global-health"
expect_fail "legacy_target_health_check" "runtime target must not declare health_check; use health_adapter"
expect_fail "second_enabled_runtime_mismatch" "enabled runtime target health_adapter runtime mismatch: claude-code-home -> claude-code-health"
expect_fail "second_enabled_missing_binding" "enabled runtime target health_adapter missing target binding: claude-code-home -> claude-code-health"
expect_fail "second_enabled_missing_adapter" "enabled runtime target health_adapter not declared: claude-code-home -> missing-claude-health"
expect_fail "second_enabled_empty_chain" "enabled runtime target source_to_live_chain must be non-empty: claude-code-home"
expect_fail "missing_runtime_footprint" "enabled runtime target missing runtime_footprint: codex-home"
expect_health_fail "runtime_mismatch" "runtime health adapter runtime mismatch"
expect_health_fail "disabled_adapter" "runtime health adapter is not enabled"
expect_health_fail "missing_profile" "runtime health adapter does not support profile=strict" "strict"
expect_health_fail "script_not_executable" "runtime health adapter missing or not executable"
expect_health_fail "missing_binding" "runtime health adapter is not bound to target"
expect_health_fail "legacy_target_health_check" "runtime target must not declare health_check; use health_adapter"
expect_health_fail_for_target "second_enabled_missing_binding" "claude-code-home" "runtime health adapter is not bound to target: claude-code-health -> claude-code-home"
expect_explain "codex-home" '"activation_ready":true'
expect_explain "claude-code-home" '"next_action":"declare source_repo and live_root"'
expect_explain_fail "missing-runtime-home" "runtime target not declared: missing-runtime-home"
expect_explain_arg_fail "--summary-json cannot be combined with --explain-target"

echo "[PASS] runtime health adapter fixtures behave as expected"
