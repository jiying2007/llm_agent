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
mkdir -p "$TMP/reference-repo"
printf '# untouched reference source\n' > "$TMP/reference-repo/AGENTS.md"
expect_rejected 2 'onboard 已退役' onboard "$TMP/reference-repo" --observe
[[ "$(cat "$TMP/reference-repo/AGENTS.md")" == '# untouched reference source' ]] || {
  echo '[FAIL] retired onboarding mutated reference source' >&2
  exit 1
}
expect_rejected 2 'check 不支持参数' check --strict
expect_rejected 2 'check 参数冲突' check --full --quick
expect_rejected 2 'cleanup 不支持参数' cleanup --dryrun
expect_rejected 1 '未知子命令' unsupported-subcommand

bash "$DEVKIT" help >"$TMP/help"
grep -Fq -- 'check [--smoke|--quick|--full]' "$TMP/help"
grep -Fq -- 'agent-dev-kit/scripts/devkit.sh validate --strict' "$TMP/help"

# The unreviewed legacy writer and its manual clone/write guidance must stay retired.
[[ ! -e "$ROOT/scripts/new-repo-onboard.sh" ]] || {
  echo '[FAIL] legacy direct-write onboarding script was reintroduced' >&2
  exit 1
}
[[ ! -e "$ROOT/docs/runbooks/new-repo-onboarding.md" ]] || {
  echo '[FAIL] legacy manual onboarding runbook was reintroduced' >&2
  exit 1
}
grep -Fq -- 'scripts/onboard-reference-repository.sh' "$ROOT/scripts/README.md"
if grep -Eq -- 'new-repo-onboard\.sh|devkit\.sh onboard' "$ROOT/scripts/README.md"; then
  echo '[FAIL] active manual routes to the retired onboarding writer' >&2
  exit 1
fi

echo '[PASS] Root devkit rejects unsupported flags and routes ADK validation explicitly'
