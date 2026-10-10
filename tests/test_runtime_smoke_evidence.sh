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
  "manifest_sha256": "62be23a53635c7a2b2c49fff25b82806e2e220234c31501ce31b7eabc1dacb67",
  "task_set_sha256": "6c03017c27fb6020faa7cc44b253f7c8ffc6a96393e32188ea0bc8d800046483",
  "task_set_identity_scope": "parsed-ordered-selected-task-sequence",
  "task_snapshot_frozen": true,
  "source_snapshot_atomic": false,
  "grader_contract": "adk-runtime-routing-grader/v1",
  "prompt_version": "adk-runtime-routing-v1",
  "runtime": "codex",
  "runtime_version": "codex-cli 0.154.0",
  "requested_model": "gpt-6.1-sol",
  "reported_models": ["gpt-6.1-sol"],
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
      "prompt_sha256": "d71d4457608f439bec8ff0ad3131ddb9673db2ade8d72f05925c061c65792891",
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
      "requested_model": "gpt-6.1-sol",
      "reported_models": ["gpt-6.1-sol"],
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
assert evidence["requested_model"] == "gpt-6.1-sol"
assert evidence["review_after"] == "2026-10-13"
assert evidence["raw_result_sha256"] == hashlib.sha256(raw_path.read_bytes()).hexdigest()
assert evidence["collection"]["tasks_sha256"]
assert evidence["collection"]["runtime_identity"] == "unverified-import"
unsigned = dict(evidence)
stored = unsigned.pop("evidence_sha256")
payload = json.dumps(unsigned, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
assert stored == hashlib.sha256(payload).hexdigest()
PY

python3 - "$TMP/raw-pass.json" "$TMP/raw-legacy.json" "$TMP/raw-model-swap.json" "$TMP/raw-duplicate.json" "$TMP/raw-nonfinite.json" "$TMP/raw-wrong-model.json" <<'PY'
import json
import sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
legacy = json.loads(json.dumps(source))
legacy.pop("task_set_sha256")
Path(sys.argv[2]).write_text(json.dumps(legacy), encoding="utf-8")
swapped = json.loads(json.dumps(source))
swapped["results"][0]["reported_models"] = ["different-model"]
Path(sys.argv[3]).write_text(json.dumps(swapped), encoding="utf-8")
duplicate = Path(sys.argv[1]).read_text(encoding="utf-8").replace(
    '"suite":', '"suite":"forged","suite":', 1,
)
Path(sys.argv[4]).write_text(duplicate, encoding="utf-8")
nonfinite = Path(sys.argv[1]).read_text(encoding="utf-8").replace(
    '"success_rate": 1.0', '"success_rate": NaN', 1,
)
Path(sys.argv[5]).write_text(nonfinite, encoding="utf-8")
wrong_model = json.loads(json.dumps(source))
wrong_model["reported_models"] = ["different-model"]
wrong_model["results"][0]["reported_models"] = ["different-model"]
Path(sys.argv[6]).write_text(json.dumps(wrong_model), encoding="utf-8")
PY
for invalid in raw-legacy raw-model-swap raw-duplicate raw-nonfinite raw-wrong-model; do
  if python3 -m tools.codex_assets.runtime_smoke_evidence \
    --root "$FAKE_ROOT" \
    --raw-result "$TMP/$invalid.json" \
    --runtime-binary "$TMP/codex" \
    --output "$TMP/$invalid.evidence.json" >/dev/null 2>&1; then
    echo "[FAIL] collector accepted unbound runtime report: $invalid" >&2
    exit 1
  fi
  test ! -e "$TMP/$invalid.evidence.json"
done

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

cp "$TMP/adk.lock.good" "$FAKE_ROOT/adk.lock"
printf 'uncommitted fixture\n' >"$ADK/untracked.txt"
if python3 -m tools.codex_assets.runtime_smoke_evidence \
  --root "$FAKE_ROOT" \
  --raw-result "$TMP/raw-pass.json" \
  --runtime-binary "$TMP/codex" \
  --output "$TMP/should-not-exist-dirty.json" >/dev/null 2>&1; then
  echo "[FAIL] collector accepted a dirty ADK source" >&2
  exit 1
fi

# Candidate projection and long-term qualification rehearsal stay on the mandatory
# Product-M5 tooling path. The rehearsal itself runs the R2 + longitudinal
# certifier fixtures but is explicitly simulated/non-terminal and must leave the
# worktree unchanged.
bash "$ROOT/tests/test_digital_worker_runtime_pilot_contract.sh"
bash "$ROOT/tests/test_long_term_asset_rehearsal.sh"

echo "[PASS] runtime smoke, candidate projection, and non-terminal long-term rehearsal contracts"
