#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FIXTURE="$TMP/root"
CHILD="$FIXTURE/agent-dev-kit"
mkdir -p "$CHILD" "$FIXTURE/manifests" "$FIXTURE/reports/promotion/agent-dev-kit" "$FIXTURE/scripts" "$FIXTURE/tools/control_plane"
git -C "$CHILD" init -q
git -C "$CHILD" config user.name Fixture
git -C "$CHILD" config user.email fixture@example.invalid
printf '{"version":"9.0.0"}\n' >"$CHILD/manifest.json"
git -C "$CHILD" add manifest.json
git -C "$CHILD" commit -qm "old child"
OLD="$(git -C "$CHILD" rev-parse HEAD)"
OLD_TREE="$(git -C "$CHILD" rev-parse HEAD^{tree})"
OLD_MANIFEST="$(git -C "$CHILD" rev-parse HEAD:manifest.json)"
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.name Fixture
git -C "$FIXTURE" config user.email fixture@example.invalid
cp "$ROOT/tools/control_plane/status_projection.py" "$FIXTURE/tools/control_plane/status_projection.py"
cat >"$FIXTURE/scripts/check-adk-lock.sh" <<'CHECK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$(printenv SOURCE_PROMOTION_TEST_FORCE_FAIL 2>/dev/null || true)" == "1" ]]; then exit 39; fi
root="$1"
index="$(git -C "$root" ls-files -s agent-dev-kit | awk '$1=="160000" {print $2}')"
locked="$(awk -F= '$1=="agent-dev-kit.commit" {print $2}' "$root/adk.lock")"
[[ -n "$index" && "$index" == "$locked" ]]
CHECK
chmod 755 "$FIXTURE/scripts/check-adk-lock.sh"
cat >"$FIXTURE/adk.lock" <<LOCK
schema=llm-agent-adk-lock/v2
agent-dev-kit.version=9.0.0
agent-dev-kit.commit=$OLD
agent-dev-kit.tree=$OLD_TREE
agent-dev-kit.manifest_blob=$OLD_MANIFEST
updated_at=2026-11-10
LOCK
python3 - "$FIXTURE" "$OLD" "$OLD_TREE" "$OLD_MANIFEST" <<'PY'
import json,sys
from pathlib import Path
root,commit,tree,blob=sys.argv[1:]
Path(root,"manifests/gates.json").write_text("{}\n")
Path(root,"manifests/product_maturity_scorecard.json").write_text(json.dumps({
 "overall":{"level":"M3","terminal_mature":False,"field_status":"not-qualified"},
 "software_m5":{"readiness_status":"not-certified","certified":False}})+"\n")
Path(root,"manifests/software_m5_policy.json").write_text(json.dumps({
 "release":{"candidate_version":"9.0.0","candidate_commit":commit,"candidate_release_eligible":False}})+"\n")
PY
printf '# Current Product Status\n\n- root_product_commit: PLACEHOLDER\n- last_verified_at: 2026-11-10\n- verified_projection_inputs_sha256: historical\n' >"$FIXTURE/reports/current-status.md"
printf '{"historical":"signed-m5-evidence"}\n' >"$FIXTURE/reports/promotion/agent-dev-kit/promotion-evidence.json"
printf '{"historical":"signed-m5-bundle"}\n' >"$FIXTURE/reports/promotion/agent-dev-kit/promotion-attestation.json"
git -C "$FIXTURE" add agent-dev-kit adk.lock manifests reports scripts tools
git -C "$FIXTURE" commit -qm "seed root"
BASE="$(git -C "$FIXTURE" rev-parse HEAD)"
sed -i "s/PLACEHOLDER/$BASE/" "$FIXTURE/reports/current-status.md"
git -C "$FIXTURE" add reports/current-status.md
git -C "$FIXTURE" commit -qm "bind baseline"
BASE="$(git -C "$FIXTURE" rev-parse HEAD)"

printf '{"version":"9.0.1"}\n' >"$CHILD/manifest.json"
git -C "$CHILD" add manifest.json
git -C "$CHILD" commit -qm "candidate child"
NEW="$(git -C "$CHILD" rev-parse HEAD)"
EVIDENCE_SHA="$(sha256sum "$FIXTURE/reports/promotion/agent-dev-kit/promotion-evidence.json" | cut -d' ' -f1)"
ATTEST_SHA="$(sha256sum "$FIXTURE/reports/promotion/agent-dev-kit/promotion-attestation.json" | cut -d' ' -f1)"
python3 -m tools.control_plane.adk_promotion --root "$FIXTURE" \
 --updated-at 2026-11-10 --source-only --apply --summary-json >"$TMP/result.json"
python3 - "$TMP/result.json" "$NEW" <<'PY'
import json,sys
p=json.load(open(sys.argv[1],encoding="utf-8"))
assert p["schema"]=="llm-agent-adk-promotion/v5",p
assert p["source_only"] is True and p["status"]=="staged-not-verified",p
assert p["release_authorized"] is False,p
assert p["verification_model"]=="immutable-release-ci-required",p
assert p["staged_paths"]==sorted([
  "agent-dev-kit","adk.lock","reports/current-status.md"
]),p
assert p["staged_transaction_complete"] is True,p
assert p["candidate"]["commit"]==sys.argv[2],p
assert p["promotion_evidence_sha256"] is None,p
assert p["promotion_attestation_sha256"] is None,p
PY
[[ "$(git -C "$FIXTURE" ls-files -s agent-dev-kit | awk '{print $2}')" == "$NEW" ]]
[[ "$(sha256sum "$FIXTURE/reports/promotion/agent-dev-kit/promotion-evidence.json" | cut -d' ' -f1)" == "$EVIDENCE_SHA" ]]
[[ "$(sha256sum "$FIXTURE/reports/promotion/agent-dev-kit/promotion-attestation.json" | cut -d' ' -f1)" == "$ATTEST_SHA" ]]
[[ "$(git -C "$FIXTURE" diff --cached --name-only | wc -l)" -eq 3 ]]

git -C "$FIXTURE" reset --hard -q "$BASE"
if SOURCE_PROMOTION_TEST_FORCE_FAIL=1 python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" --updated-at 2026-11-10 --source-only --apply >/dev/null 2>&1; then
  echo "[FAIL] source promotion accepted forced pin verification failure" >&2
  exit 1
fi
[[ -z "$(git -C "$FIXTURE" diff --cached --name-only)" ]]
[[ "$(git -C "$FIXTURE" ls-files -s agent-dev-kit | awk '{print $2}')" == "$OLD" ]]
[[ "$(sha256sum "$FIXTURE/reports/promotion/agent-dev-kit/promotion-evidence.json" | cut -d' ' -f1)" == "$EVIDENCE_SHA" ]]
[[ "$(sha256sum "$FIXTURE/reports/promotion/agent-dev-kit/promotion-attestation.json" | cut -d' ' -f1)" == "$ATTEST_SHA" ]]
if python3 -m tools.control_plane.adk_promotion --root "$FIXTURE" \
  --updated-at 2026-11-10 --source-only --promotion-evidence "$TMP/result.json" --apply >/dev/null 2>&1; then
  echo "[FAIL] source-only mode accepted signed evidence substitution" >&2
  exit 1
fi
echo "[PASS] source-only ADK upgrade stages three source paths and preserves independent M5 evidence"
