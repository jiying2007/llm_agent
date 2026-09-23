#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$ROOT"

python3 - "$ROOT/scripts/check-adk-promotion-evidence.sh" "$ROOT/.github/workflows/ci.yml" <<'PY'
from pathlib import Path
import sys

script = Path(sys.argv[1]).read_text(encoding="utf-8")
workflow = Path(sys.argv[2]).read_text(encoding="utf-8")

for token in (
    "cosign verify-blob",
    "--bundle \"$ATTESTATION\"",
    "--certificate-identity 'https://github.com/jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main'",
    "--certificate-oidc-issuer 'https://token.actions.githubusercontent.com'",
):
    assert token in script, token

for token in (
    "cosign-release: v3.1.3",
    "cosign verify-blob",
    "--bundle reports/promotion/agent-dev-kit/promotion-attestation.json",
    "--certificate-identity https://github.com/jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main",
    "--certificate-oidc-issuer https://token.actions.githubusercontent.com",
):
    assert token in workflow, token

for retired in ("--use-signed-timestamps", "--rfc3161-timestamp-path"):
    assert retired not in script, retired
    assert retired not in workflow, retired

for retired in ("cosign initialize", "trusted_root.json", "--trusted-root", "--new-bundle-format"):
    assert retired not in script, retired
PY

python - "$TMP" <<'PY'
import datetime as dt
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
version = '5.0.0-rc.2'
commit = '1' * 40
tree = '2' * 40
blob = '3' * 40
(root / 'adk.lock').write_text(
    'schema=llm-agent-adk-lock/v2\n'
    f'agent-dev-kit.version={version}\n'
    f'agent-dev-kit.commit={commit}\n'
    f'agent-dev-kit.tree={tree}\n'
    f'agent-dev-kit.manifest_blob={blob}\n'
    'updated_at=2026-09-11\n',
    encoding='utf-8',
)
(root / 'interface.json').write_text(json.dumps({
    'schema': 'llm-agent-adk-interface-lock/v1',
    'version': version,
    'commit': commit,
    'tree': tree,
    'manifest_blob': blob,
}), encoding='utf-8')
issued = dt.datetime.now(dt.UTC).isoformat().replace('+00:00', 'Z')
evidence = {
    'schema': 'adk-promotion-evidence/v1',
    'issued_at': issued,
    'source': {
        'repository': 'jiying2007/agent-dev-kit',
        'version': version,
        'commit': commit,
        'tree': tree,
        'manifest_blob': blob,
        'manifest_sha256': '4' * 64,
        'ref': 'refs/heads/main',
        'event': 'push',
        'workflow': 'agent-dev-kit-ci',
        'workflow_ref': 'jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main',
        'workflow_sha': '5' * 40,
        'run_id': 123,
        'run_attempt': 1,
    },
    'contracts': {
        'contract_registry_sha256': '6' * 64,
        'schema_set_sha256': '7' * 64,
        'release_manifest_sha256': '8' * 64,
    },
    'ci': {
        'contract_matrix': {'status': 'success', 'python': ['3.11', '3.12']},
        'regression_matrix': {'status': 'success', 'python': ['3.11', '3.12']},
        'static_security': 'success',
        'deterministic_eval_package': 'success',
    },
    'release': {'artifact_sha256': '9' * 64, 'release_eligible': False},
    'provenance': {'subject': 'promotion-evidence.json', 'format': 'sigstore-bundle/v1'},
}
(root / 'evidence.json').write_text(json.dumps(evidence), encoding='utf-8')

bad = json.loads(json.dumps(evidence))
bad['source']['commit'] = 'a' * 40
(root / 'bad-identity.json').write_text(json.dumps(bad), encoding='utf-8')
bad = json.loads(json.dumps(evidence))
bad['ci']['regression_matrix']['status'] = 'failure'
(root / 'bad-ci.json').write_text(json.dumps(bad), encoding='utf-8')
bad = json.loads(json.dumps(evidence))
bad['source']['ref'] = 'refs/pull/1/merge'
(root / 'bad-ref.json').write_text(json.dumps(bad), encoding='utf-8')
bad = json.loads(json.dumps(evidence))
bad['issued_at'] = '2020-01-01T00:00:00Z'
(root / 'stale.json').write_text(json.dumps(bad), encoding='utf-8')
PY

python -m tools.control_plane.adk_promotion_evidence \
  --evidence "$TMP/evidence.json" \
  --lock "$TMP/adk.lock" \
  --interface "$TMP/interface.json" \
  --summary-json

for bad in bad-identity bad-ci bad-ref stale; do
  if python -m tools.control_plane.adk_promotion_evidence \
      --evidence "$TMP/$bad.json" \
      --lock "$TMP/adk.lock" \
      --interface "$TMP/interface.json" \
      --summary-json; then
    echo "[FAIL] $bad evidence unexpectedly validated" >&2
    exit 1
  fi
done

echo '[PASS] portable ADK promotion evidence verifier'
