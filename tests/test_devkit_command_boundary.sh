#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVKIT="$ROOT/scripts/devkit.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

expect_rejected() {
  local expected_code="$1" expected_text="$2" exit_code=0
  shift 2
  bash "$DEVKIT" "$@" >"$TMP/output" 2>&1 || exit_code=$?
  if [[ "$exit_code" -ne "$expected_code" ]]; then
    echo "[FAIL] unexpected exit ${exit_code} for devkit $* (expected ${expected_code})" >&2
    cat "$TMP/output" >&2
    exit 1
  fi
  if ! grep -Fq -- "$expected_text" "$TMP/output"; then
    echo "[FAIL] missing diagnostic: ${expected_text}" >&2
    cat "$TMP/output" >&2
    exit 1
  fi
}

# No invalid CLI request may silently turn into a quick check or real cleanup.
expect_rejected 2 'agent-dev-kit/scripts/devkit.sh validate --strict' validate --strict
expect_rejected 2 'check 不支持参数' check --strict
expect_rejected 2 'check 参数冲突' check --full --quick
expect_rejected 2 'cleanup 不支持参数' cleanup --dryrun
expect_rejected 1 '未知子命令' unsupported-subcommand

bash "$DEVKIT" help >"$TMP/help"
grep -Fq -- 'check [--smoke|--quick|--full]' "$TMP/help"
grep -Fq -- 'agent-dev-kit/scripts/devkit.sh validate --strict' "$TMP/help"

echo '[PASS] Root devkit rejects unsupported flags and routes ADK validation explicitly'
