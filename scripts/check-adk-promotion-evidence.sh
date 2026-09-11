#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "${1:-.}" && pwd)"
EVIDENCE="$ROOT/reports/promotion/agent-dev-kit/promotion-evidence.json"
ATTESTATION="$ROOT/reports/promotion/agent-dev-kit/promotion-attestation.json"
TRUSTED_ROOT="$(mktemp)"
trap 'rm -f "$TRUSTED_ROOT"' EXIT

[[ -f "$EVIDENCE" ]] || { echo "[FAIL] missing $EVIDENCE" >&2; exit 1; }
[[ -f "$ATTESTATION" ]] || { echo "[FAIL] missing $ATTESTATION" >&2; exit 1; }
command -v gh >/dev/null || { echo '[FAIL] GitHub CLI is required for attestation verification' >&2; exit 1; }

python3 -m tools.control_plane.adk_promotion_evidence \
  --evidence "$EVIDENCE" \
  --lock "$ROOT/adk.lock" \
  --interface "$ROOT/manifests/adk_interface.lock.json" \
  --summary-json

commit="$(awk -F= '$1=="agent-dev-kit.commit"{print $2; exit}' "$ROOT/adk.lock")"
[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { echo '[FAIL] invalid ADK commit in adk.lock' >&2; exit 1; }

gh attestation trusted-root > "$TRUSTED_ROOT"
gh attestation verify \
  "$EVIDENCE" \
  --repo jiying2007/agent-dev-kit \
  --bundle "$ATTESTATION" \
  --custom-trusted-root "$TRUSTED_ROOT" \
  --signer-workflow jiying2007/agent-dev-kit/.github/workflows/ci.yml \
  --source-ref refs/heads/main \
  --source-digest "$commit" \
  --deny-self-hosted-runners \
  --format json

echo '[PASS] ADK promotion evidence claims and keyless provenance verified'
