#!/usr/bin/env bash
set -euo pipefail
trap 'rc=$?; echo "[FAIL] promotion fixture line ${LINENO}: ${BASH_COMMAND}" >&2; exit "$rc"' ERR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FIXTURE="$TMP_DIR/root"
CANDIDATE="$FIXTURE/agent-dev-kit"
mkdir -p \
  "$CANDIDATE" \
  "$FIXTURE/manifests" \
  "$FIXTURE/reports/promotion/agent-dev-kit" \
  "$FIXTURE/scripts" \
  "$FIXTURE/tools/control_plane"

# Minimal ADK repo with an old commit followed by a new candidate.
git -C "$CANDIDATE" init -q
git -C "$CANDIDATE" config user.email fixture@example.invalid
git -C "$CANDIDATE" config user.name Fixture
printf '{"version":"5.0.0-rc.2"}\n' >"$CANDIDATE/manifest.json"
git -C "$CANDIDATE" add manifest.json
git -C "$CANDIDATE" commit -q -m 'old adk'
OLD_ADK="$(git -C "$CANDIDATE" rev-parse HEAD)"
OLD_TREE="$(git -C "$CANDIDATE" rev-parse HEAD^{tree})"
OLD_MANIFEST="$(git -C "$CANDIDATE" rev-parse HEAD:manifest.json)"

# Minimal parent repo and projection inputs.
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email fixture@example.invalid
git -C "$FIXTURE" config user.name Fixture
cp "$ROOT/tools/control_plane/status_projection.py" "$FIXTURE/tools/control_plane/status_projection.py"
printf '{}\n' >"$FIXTURE/manifests/gates.json"
cat >"$FIXTURE/manifests/product_maturity_scorecard.json" <<'JSON'
{
  "overall": {"level":"M3","terminal_mature":false,"field_status":"self_pilot_active"},
  "software_m5": {"readiness_status":"not-ready","certified":false}
}
JSON
cat >"$FIXTURE/manifests/software_m5_policy.json" <<JSON
{"release":{"candidate_version":"5.0.0-rc.2","candidate_commit":"$OLD_ADK"}}
JSON
cat >"$FIXTURE/adk.lock" <<LOCK
schema=llm-agent-adk-lock/v2
agent-dev-kit.version=5.0.0-rc.2
agent-dev-kit.commit=$OLD_ADK
agent-dev-kit.tree=$OLD_TREE
agent-dev-kit.manifest_blob=$OLD_MANIFEST
updated_at=2026-09-10
LOCK
python3 - "$ROOT" "$FIXTURE" "$OLD_ADK" "$OLD_TREE" "$OLD_MANIFEST" <<'PY'
import json, sys
from pathlib import Path
root, fixture, commit, tree, manifest_blob = sys.argv[1:]
sys.path.insert(0, root)
from tools.control_plane.adk_interface import interface_payload
payload = interface_payload(
    {"version":"5.0.0-rc.2","commit":commit,"tree":tree,"manifest_blob":manifest_blob},
    "2026-09-10",
)
Path(fixture, "manifests", "adk_interface.lock.json").write_text(
    json.dumps(payload, indent=2) + "\n", encoding="utf-8"
)
PY
cat >"$FIXTURE/reports/current-status.md" <<'STATUS'
# Current Product Status

- status_semantics: last-verified-product-baseline
- last_verified_at: 2026-09-10
- root_product_commit: BASELINE_PLACEHOLDER
STATUS
cat >"$FIXTURE/scripts/check-adk-lock.sh" <<'CHECK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${PROMOTION_TEST_FORCE_FAIL:-0}" == "1" ]]; then
  echo '[FAIL] forced post-apply validation failure' >&2
  exit 19
fi
root="${1:-.}"
lock_commit="$(awk -F= '$1=="agent-dev-kit.commit"{print $2; exit}' "$root/adk.lock")"
gitlink="$(git -C "$root" ls-files -s agent-dev-kit | awk '{print $2; exit}')"
[[ -n "$lock_commit" && "$lock_commit" == "$gitlink" ]]
CHECK
chmod +x "$FIXTURE/scripts/check-adk-lock.sh"
printf 'sentinel\n' >"$FIXTURE/sentinel.txt"

git -C "$FIXTURE" add adk.lock manifests reports scripts sentinel.txt tools agent-dev-kit
git -C "$FIXTURE" commit -q -m 'fixture seed'
BASELINE="$(git -C "$FIXTURE" rev-parse HEAD)"
sed -i "s/BASELINE_PLACEHOLDER/$BASELINE/" "$FIXTURE/reports/current-status.md"
git -C "$FIXTURE" add reports/current-status.md
git -C "$FIXTURE" commit -q -m 'bind historical baseline'
PARENT_HEAD="$(git -C "$FIXTURE" rev-parse HEAD)"

# Advance only the nested ADK candidate.
printf 'candidate\n' >"$CANDIDATE/candidate.txt"
git -C "$CANDIDATE" add candidate.txt
git -C "$CANDIDATE" commit -q -m 'new adk candidate'
NEW_ADK="$(git -C "$CANDIDATE" rev-parse HEAD)"
NEW_TREE="$(git -C "$CANDIDATE" rev-parse HEAD^{tree})"
NEW_MANIFEST="$(git -C "$CANDIDATE" rev-parse HEAD:manifest.json)"

EVIDENCE="$TMP_DIR/promotion-evidence.json"
ATTESTATION="$TMP_DIR/promotion-attestation.json"
cat >"$EVIDENCE" <<JSON
{
  "schema":"adk-promotion-evidence/v1",
  "source":{
    "version":"5.0.0-rc.2",
    "commit":"$NEW_ADK",
    "tree":"$NEW_TREE",
    "manifest_blob":"$NEW_MANIFEST"
  },
  "provenance":{"subject":"promotion-evidence.json","format":"sigstore-bundle/v1"}
}
JSON
printf '{"mediaType":"application/vnd.dev.sigstore.bundle+json;version=0.3","verificationMaterial":{}}\n' >"$ATTESTATION"

SUMMARY="$TMP_DIR/apply.json"
python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" \
  --candidate-dir "$CANDIDATE" \
  --updated-at 2026-09-11 \
  --promotion-evidence "$EVIDENCE" \
  --promotion-attestation "$ATTESTATION" \
  --apply \
  --summary-json >"$SUMMARY"

python3 - "$SUMMARY" "$FIXTURE" "$NEW_ADK" <<'PY'
import hashlib, json, subprocess, sys
from pathlib import Path
summary_path, root_text, expected_commit = sys.argv[1:]
root = Path(root_text)
result = json.loads(Path(summary_path).read_text(encoding="utf-8"))
expected_paths = sorted([
    "adk.lock",
    "agent-dev-kit",
    "manifests/adk_interface.lock.json",
    "reports/current-status.md",
    "reports/promotion/agent-dev-kit/promotion-evidence.json",
    "reports/promotion/agent-dev-kit/promotion-attestation.json",
])
assert result["status"] == "applied-not-verified", result
assert result["schema"] == "llm-agent-adk-promotion/v4", result
assert result["staged_paths"] == expected_paths, result
assert result["staged_transaction_complete"] is True, result
assert result["verification_model"] == "portable-attested-evidence", result
for key in ("interface_sha256", "promotion_evidence_sha256", "promotion_attestation_sha256"):
    assert isinstance(result[key], str) and len(result[key]) == 64, result
staged = subprocess.check_output(
    ["git", "-C", str(root), "diff", "--cached", "--name-only"], text=True
).splitlines()
assert sorted(staged) == expected_paths, staged
index = subprocess.check_output(
    ["git", "-C", str(root), "ls-files", "-s", "agent-dev-kit"], text=True
).split()
assert index[1] == expected_commit, index
assert (root / "reports/promotion/agent-dev-kit/promotion-evidence.json").is_file()
assert (root / "reports/promotion/agent-dev-kit/promotion-attestation.json").is_file()
assert result["promotion_evidence_sha256"] == hashlib.sha256(
    (root / "reports/promotion/agent-dev-kit/promotion-evidence.json").read_bytes()
).hexdigest()
assert result["promotion_attestation_sha256"] == hashlib.sha256(
    (root / "reports/promotion/agent-dev-kit/promotion-attestation.json").read_bytes()
).hexdigest()
PY

# Failure after mutation must restore all six transaction paths.
git -C "$FIXTURE" reset --hard -q "$PARENT_HEAD"
rm -rf "$FIXTURE/reports/promotion"
if PROMOTION_TEST_FORCE_FAIL=1 python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" \
  --candidate-dir "$CANDIDATE" \
  --updated-at 2026-09-11 \
  --promotion-evidence "$EVIDENCE" \
  --promotion-attestation "$ATTESTATION" \
  --apply >/dev/null 2>&1; then
  echo '[FAIL] forced post-apply failure unexpectedly succeeded' >&2
  exit 1
fi
[[ -z "$(git -C "$FIXTURE" diff --cached --name-only)" ]] || {
  echo '[FAIL] rollback left staged changes behind' >&2
  exit 1
}
[[ ! -e "$FIXTURE/reports/promotion/agent-dev-kit/promotion-evidence.json" ]] || {
  echo '[FAIL] rollback left promotion evidence behind' >&2
  exit 1
}
[[ ! -e "$FIXTURE/reports/promotion/agent-dev-kit/promotion-attestation.json" ]] || {
  echo '[FAIL] rollback left promotion attestation behind' >&2
  exit 1
}
ROLLED_BACK_PIN="$(git -C "$FIXTURE" ls-files -s agent-dev-kit | awk '{print $2; exit}')"
[[ "$ROLLED_BACK_PIN" == "$OLD_ADK" ]] || {
  echo '[FAIL] rollback did not restore original gitlink' >&2
  exit 1
}

# Pre-existing staged work must fail before any promotion mutation.
printf 'pre-staged\n' >>"$FIXTURE/sentinel.txt"
git -C "$FIXTURE" add sentinel.txt
if python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" \
  --candidate-dir "$CANDIDATE" \
  --updated-at 2026-09-11 \
  --promotion-evidence "$EVIDENCE" \
  --promotion-attestation "$ATTESTATION" \
  --apply >/dev/null 2>&1; then
  echo '[FAIL] promotion accepted pre-existing staged change' >&2
  exit 1
fi
mapfile -t PRESTAGED < <(git -C "$FIXTURE" diff --cached --name-only)
[[ "${#PRESTAGED[@]}" -eq 1 && "${PRESTAGED[0]}" == "sentinel.txt" ]] || {
  echo '[FAIL] preflight rejection changed staged set' >&2
  exit 1
}

# Evidence identity mismatch must fail before staging anything.
git -C "$FIXTURE" reset --hard -q "$PARENT_HEAD"
python3 - "$EVIDENCE" "$TMP_DIR/bad-evidence.json" <<'PY'
import json, sys
src, dst = sys.argv[1:]
value = json.load(open(src, encoding='utf-8'))
value['source']['commit'] = '0' * 40
json.dump(value, open(dst, 'w', encoding='utf-8'))
PY
if python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" \
  --candidate-dir "$CANDIDATE" \
  --updated-at 2026-09-11 \
  --promotion-evidence "$TMP_DIR/bad-evidence.json" \
  --promotion-attestation "$ATTESTATION" \
  --apply >/dev/null 2>&1; then
  echo '[FAIL] promotion accepted mismatched evidence identity' >&2
  exit 1
fi
[[ -z "$(git -C "$FIXTURE" diff --cached --name-only)" ]] || {
  echo '[FAIL] mismatched evidence staged changes' >&2
  exit 1
}

echo '[PASS] ADK promotion stages one six-path source+evidence transaction and rolls back atomically'
