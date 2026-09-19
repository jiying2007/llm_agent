#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="$WORKSPACE_ROOT/agent-dev-kit"

[[ -f "$ADK_ROOT/manifest.json" ]] || {
  echo "[FAIL] initialized agent-dev-kit source not found: $ADK_ROOT" >&2
  exit 1
}

checks=(
  check-codify-governance.sh
  check-context-experience-patterns.sh
  check-external-agent-patterns.sh
  check-knowledge-compile-model.sh
  check-reuse-before-rebuild.sh
  check-runtime-capabilities.sh
  check-tool-skill-evidence-contracts.sh
  check-official-docs-governance.sh
)

for checker in "${checks[@]}"; do
  path="$ADK_ROOT/scripts/$checker"
  [[ -f "$path" ]] || {
    echo "[FAIL] pinned ADK governance checker missing: scripts/$checker" >&2
    exit 1
  }
  bash "$path"
done

echo "[PASS] canonical ADK governance suite passed checks=${#checks[@]}"
