#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/software-m5-runtime-smoke.yml"

require_literal() {
  local literal="$1"
  grep -Fq -- "$literal" "$WORKFLOW" || {
    echo "[FAIL] runtime-smoke workflow missing contract literal: $literal" >&2
    exit 1
  }
}

require_literal "issue_comment:"
require_literal "types: [created]"
require_literal "github.event_name == 'issue_comment'"
require_literal "github.event.issue.number == 41"
require_literal "github.actor == github.repository_owner"
require_literal "github.event.comment.body == '/run-m5-5.1-smoke'"
require_literal "CONFIRM_PAID_RUNTIME: \${{ github.event_name == 'issue_comment' && 'true' || inputs.confirm_paid_runtime }}"
require_literal "CODEX_CLI_VERSION: \${{ github.event_name == 'issue_comment' && '0.154.0' || inputs.codex_cli_version }}"
require_literal "MODEL: \${{ github.event_name == 'issue_comment' && 'gpt-5.5' || inputs.model }}"
require_literal "ROOT_INTEGRATION_RUN_ID: \${{ github.event_name == 'issue_comment' && '34707461578' || inputs.root_integration_run_id }}"
require_literal "default: '34707461578'"
require_literal "contents: read"

if grep -Eq '^[[:space:]]+contents:[[:space:]]+write([[:space:]]|$)' "$WORKFLOW"; then
  echo '[FAIL] runtime-smoke workflow must not gain contents: write' >&2
  exit 1
fi
if grep -Fq 'pull_request_target:' "$WORKFLOW"; then
  echo '[FAIL] runtime-smoke workflow must not use pull_request_target' >&2
  exit 1
fi

echo '[PASS] owner-only Issue #41 runtime-smoke trigger is fail-closed and parameter-pinned'
