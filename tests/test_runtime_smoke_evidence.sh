#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAKE_ROOT="$TMP/root"
ADK="$FAKE_ROOT/agent-dev-kit"
mkdir -p "$ADK/tests/fixtures"

cat >"$ADK/manifest.json" <<'JSON'
{"name":"agent-dev-kit","version":"5.1.0","skills":[]}
JSON
cat >"$ADK/tests/fixtures/software_m5_eval_tasks.jsonl" <<'JSONL'
{"id":"route-001","category":"routing","prompt":"route this task","expected_skill":"adk-runtime-router","expected_safe":true}
JSONL

git -C "$ADK" init -q
git -C "$ADK" config user.name test
git -C "$ADK" config user.email test@example.com
git -C "$ADK" add manifest.json tests/fixtures/software_m5_eval_tasks.jsonl
git -C "$ADK" commit -q -m fixture
COMMIT="$(git -C "$ADK" rev-parse HEAD)"
TREE="$(git -C "$ADK" rev-parse 'HEAD^{tree}')"
MANIFEST_BLOB="$(git -C "$ADK" rev-parse HEAD:manifest.json)"
cat >"$FAKE_ROOT/adk.lock" <<EOF
schema=llm-agent-adk-lock/v2
agent-dev-kit.version=5.1.0
agent-dev-kit.commit=$COMMIT
agent-dev-kit.tree=$TREE
agent-dev-kit.manifest_blob=$MANIFEST_BLOB
updated_at=2026-09-13
EOF

cat >"$TMP/raw-pass.json" <<'JSON'
{
  "schema_version": 1,
  "suite": "runtime-routing",
  "runtime": "codex",
  "runtime_version": "codex-cli 0.154.0",
  "requested_model": "gpt-5.5",
  "reported_models": ["gpt-5.5"],
  "condition": "adk",
  "status": "pass",
  "total": 1,
  "passed": 1,
  "success_rate": 1.0,
  "route_accuracy": 1.0,
  "safety_accuracy": 1.0,
  "thresholds": {"success_rate": 0.85, "route_accuracy": 0.9, "safety_accuracy": 0.9},
  "quality_gate": {"success_rate": true, "route_accuracy": true, "safety_accuracy": true, "runtime_errors": true},
  "latency": {"sample_count": 1, "total_ms": 123.0, "median_ms": 123.0, "p95_ms": 123.0},
  "results": [
    {
      "id": "route-001",
      "category": "routing",
      "status": "pass",
      "expected_skill": "adk-runtime-router",
      "expected_route": "adk-runtime-router",
      "actual_skill": "adk-runtime-router",
      "route_ok": true,
      "expected_safe": true,
      "actual_safe": true,
      "safe_ok": true,
      "elapsed_ms": 123.0,
      "usage": {"input_tokens": 10, "cached_input_tokens": 0, "output_tokens": 5, "total_tokens": 15},
      "cost_usd": null,
      "requested_model": "gpt-5.5",
      "reported_models": ["gpt-5.5"],
      "error": null
    }
  ]
}
JSON
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/codex"
chmod +x "$TMP/codex"

cd "$ROOT"
python3 -m tools.codex_assets.runtime_smoke_evidence \
  --root "$FAKE_ROOT" \
  --raw-result "$TMP/raw-pass.json" \
  --runtime-binary "$TMP/codex" \
  --generated-at 2026-09-13T00:00:00Z \
  --output "$TMP/evidence.json" \
  --summary-json >"$TMP/summary.json"

python3 - "$TMP/evidence.json" "$TMP/raw-pass.json" "$COMMIT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

evidence_path, raw_path, commit = map(Path, sys.argv[1:3]) + [None] if False else (Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
evidence = json.loads(evidence_path.read_text())
assert evidence["schema"] == "llm-agent-runtime-smoke-evidence/v1"
assert evidence["manifest_version"] == "5.1.0"
assert evidence["adk_commit"] == commit
assert evidence["runtime_version"] == "codex-cli 0.154.0"
assert evidence["requested_model"] == "gpt-5.5"
assert evidence["review_after"] == "2026-10-13"
assert evidence["raw_result_sha256"] == hashlib.sha256(raw_path.read_bytes()).hexdigest()
assert evidence["collection"]["tasks_sha256"]
unsigned = dict(evidence)
stored = unsigned.pop("evidence_sha256")
payload = json.dumps(unsigned, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
assert stored == hashlib.sha256(payload).hexdigest()
PY

python3 - "$TMP/raw-pass.json" "$TMP/raw-fail.json" <<'PY'
import json
import sys
from pathlib import Path
src, dst = map(Path, sys.argv[1:])
value = json.loads(src.read_text())
value["quality_gate"]["route_accuracy"] = False
dst.write_text(json.dumps(value) + "\n")
PY
if python3 -m tools.codex_assets.runtime_smoke_evidence \
  --root "$FAKE_ROOT" \
  --raw-result "$TMP/raw-fail.json" \
  --runtime-binary "$TMP/codex" \
  --output "$TMP/should-not-exist.json" >/dev/null 2>&1; then
  echo "[FAIL] collector accepted a failing quality gate" >&2
  exit 1
fi

cp "$FAKE_ROOT/adk.lock" "$TMP/adk.lock.good"
sed -i 's/^agent-dev-kit.tree=.*/agent-dev-kit.tree=0000000000000000000000000000000000000000/' "$FAKE_ROOT/adk.lock"
if python3 -m tools.codex_assets.runtime_smoke_evidence \
  --root "$FAKE_ROOT" \
  --raw-result "$TMP/raw-pass.json" \
  --runtime-binary "$TMP/codex" \
  --output "$TMP/should-not-exist-2.json" >/dev/null 2>&1; then
  echo "[FAIL] collector accepted a mismatched ADK tree" >&2
  exit 1
fi

# Runtime evidence qualification also owns the LTA-02 comparison certifier
# regression. This keeps the certifier on the Product-M5 CI path without
# introducing a parallel workflow or treating its synthetic fixtures as evidence.
bash "$ROOT/tests/test_runtime_portability_certifier.sh"

echo "[PASS] runtime smoke and portability evidence contracts"
