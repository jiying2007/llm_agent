#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "${1:-.}" && pwd)"
EVIDENCE="$ROOT/reports/promotion/agent-dev-kit/promotion-evidence.json"
ATTESTATION="$ROOT/reports/promotion/agent-dev-kit/promotion-attestation.json"

[[ -f "$EVIDENCE" ]] || { echo "[FAIL] missing $EVIDENCE" >&2; exit 1; }
[[ -f "$ATTESTATION" ]] || { echo "[FAIL] missing $ATTESTATION" >&2; exit 1; }
command -v cosign >/dev/null || { echo '[FAIL] cosign is required for promotion evidence verification' >&2; exit 1; }

python3 -m tools.control_plane.adk_promotion_evidence \
  --evidence "$EVIDENCE" \
  --lock "$ROOT/adk.lock" \
  --interface "$ROOT/manifests/adk_interface.lock.json" \
  --summary-json

cosign verify-blob \
  --use-signed-timestamps \
  --bundle "$ATTESTATION" \
  --certificate-identity 'https://github.com/jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  "$EVIDENCE"

echo '[PASS] ADK promotion evidence claims and producer-compatible Sigstore provenance verified'
