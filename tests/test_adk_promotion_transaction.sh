#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FIXTURE="$TMP_DIR/root"
CANDIDATE="$FIXTURE/agent-dev-kit"
mkdir -p \
  "$CANDIDATE" \
  "$FIXTURE/manifests" \
  "$FIXTURE/reports" \
  "$FIXTURE/scripts" \
  "$FIXTURE/tools/control_plane"

# Build a minimal ADK repository with an old pinned commit and a newer candidate.
git -C "$CANDIDATE" init -q
git -C "$CANDIDATE" config user.email fixture@example.invalid
git -C "$CANDIDATE" config user.name Fixture
printf '{"version":"5.0.0-rc.2"}\n' >"$CANDIDATE/manifest.json"
git -C "$CANDIDATE" add manifest.json
git -C "$CANDIDATE" commit -q -m 'old adk'
OLD_ADK="$(git -C "$CANDIDATE" rev-parse HEAD)"
OLD_TREE="$(git -C "$CANDIDATE" rev-parse HEAD^{tree})"
OLD_MANIFEST="$(git -C "$CANDIDATE" rev-parse HEAD:manifest.json)"

# Build the parent repository at the old pin. The status projection source is
# copied only because it is one of the projection's content-addressed inputs.
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email fixture@example.invalid
git -C "$FIXTURE" config user.name Fixture
cp "$ROOT/tools/control_plane/status_projection.py" "$FIXTURE/tools/control_plane/status_projection.py"
printf '{}\n' >"$FIXTURE/manifests/gates.json"
cat >"$FIXTURE/manifests/product_maturity_scorecard.json" <<'JSON'
{
  "overall": {
    "level": "M3",
    "terminal_mature": false,
    "field_status": "self_pilot_active"
  },
  "software_m5": {
    "readiness_status": "not-ready",
    "certified": false
  }
}
JSON
cat >"$FIXTURE/manifests/software_m5_policy.json" <<JSON
{
  "release": {
    "candidate_version": "5.0.0-rc.2",
    "candidate_commit": "$OLD_ADK"
  }
}
JSON
cat >"$FIXTURE/adk.lock" <<LOCK
schema=llm-agent-adk-lock/v2
agent-dev-kit.version=5.0.0-rc.2
agent-dev-kit.commit=$OLD_ADK
agent-dev-kit.tree=$OLD_TREE
agent-dev-kit.manifest_blob=$OLD_MANIFEST
updated_at=2026-09-10
LOCK
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

# Advance only the nested ADK worktree. This is the sole pre-promotion worktree
# difference the promotion command is allowed to accept.
printf 'candidate\n' >"$CANDIDATE/candidate.txt"
git -C "$CANDIDATE" add candidate.txt
git -C "$CANDIDATE" commit -q -m 'new adk candidate'
NEW_ADK="$(git -C "$CANDIDATE" rev-parse HEAD)"

SUMMARY="$TMP_DIR/apply.json"
python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" \
  --candidate-dir "$CANDIDATE" \
  --updated-at 2026-09-11 \
  --apply \
  --summary-json >"$SUMMARY"

python3 - "$SUMMARY" "$FIXTURE" "$NEW_ADK" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

summary_path, root_text, expected_commit = sys.argv[1:]
root = Path(root_text)
result = json.loads(Path(summary_path).read_text(encoding="utf-8"))
expected_paths = ["adk.lock", "agent-dev-kit", "reports/current-status.md"]
assert result["status"] == "applied-not-verified", result
assert result["staged_paths"] == expected_paths, result
assert result["staged_transaction_complete"] is True, result
staged = subprocess.check_output(
    ["git", "-C", str(root), "diff", "--cached", "--name-only"], text=True
).splitlines()
assert sorted(staged) == expected_paths, staged
index = subprocess.check_output(
    ["git", "-C", str(root), "ls-files", "-s", "agent-dev-kit"], text=True
).split()
assert index[1] == expected_commit, index
lock = dict(
    line.split("=", 1)
    for line in (root / "adk.lock").read_text(encoding="utf-8").splitlines()
    if "=" in line
)
assert lock["agent-dev-kit.commit"] == expected_commit, lock
status = (root / "reports/current-status.md").read_text(encoding="utf-8")
assert f"- current_adk_commit: {expected_commit}" in status, status
PY

# A failure after mutation must restore both worktree files and the index.
git -C "$FIXTURE" reset --hard -q "$PARENT_HEAD"
if PROMOTION_TEST_FORCE_FAIL=1 python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" \
  --candidate-dir "$CANDIDATE" \
  --updated-at 2026-09-11 \
  --apply >/dev/null 2>&1; then
  echo '[FAIL] forced post-apply failure unexpectedly succeeded' >&2
  exit 1
fi
[[ -z "$(git -C "$FIXTURE" diff --cached --name-only)" ]] || {
  echo '[FAIL] rollback left staged changes behind' >&2
  git -C "$FIXTURE" diff --cached --name-status >&2
  exit 1
}
git -C "$FIXTURE" diff --quiet -- adk.lock reports/current-status.md || {
  echo '[FAIL] rollback did not restore lock/status worktree content' >&2
  exit 1
}
ROLLED_BACK_PIN="$(git -C "$FIXTURE" ls-files -s agent-dev-kit | awk '{print $2; exit}')"
[[ "$ROLLED_BACK_PIN" == "$OLD_ADK" ]] || {
  echo '[FAIL] rollback did not restore the original gitlink' >&2
  exit 1
}

# Any pre-existing staged change must fail before the promotion mutates source.
printf 'pre-staged\n' >>"$FIXTURE/sentinel.txt"
git -C "$FIXTURE" add sentinel.txt
if python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" \
  --candidate-dir "$CANDIDATE" \
  --updated-at 2026-09-11 \
  --apply >/dev/null 2>&1; then
  echo '[FAIL] promotion accepted a pre-existing staged change' >&2
  exit 1
fi
mapfile -t PRESTAGED < <(git -C "$FIXTURE" diff --cached --name-only)
[[ "${#PRESTAGED[@]}" -eq 1 && "${PRESTAGED[0]}" == "sentinel.txt" ]] || {
  echo '[FAIL] preflight rejection changed the existing staged set' >&2
  printf 'staged: %s\n' "${PRESTAGED[*]}" >&2
  exit 1
}
git -C "$FIXTURE" diff --quiet -- adk.lock reports/current-status.md || {
  echo '[FAIL] preflight rejection mutated lock/status' >&2
  exit 1
}

# Re-promoting an already pinned candidate is not a transaction and must fail.
git -C "$FIXTURE" reset --hard -q "$PARENT_HEAD"
git -C "$FIXTURE" update-index --add --cacheinfo "160000,$NEW_ADK,agent-dev-kit"
cat >"$FIXTURE/adk.lock" <<LOCK
schema=llm-agent-adk-lock/v2
agent-dev-kit.version=5.0.0-rc.2
agent-dev-kit.commit=$NEW_ADK
agent-dev-kit.tree=$(git -C "$CANDIDATE" rev-parse HEAD^{tree})
agent-dev-kit.manifest_blob=$(git -C "$CANDIDATE" rev-parse HEAD:manifest.json)
updated_at=2026-09-11
LOCK
git -C "$FIXTURE" add adk.lock
# Commit the already-pinned state so the index is clean before the no-op attempt.
git -C "$FIXTURE" commit -q -m 'already pinned candidate'
if python3 -m tools.control_plane.adk_promotion \
  --root "$FIXTURE" \
  --candidate-dir "$CANDIDATE" \
  --updated-at 2026-09-11 \
  --apply >/dev/null 2>&1; then
  echo '[FAIL] promotion accepted an already pinned candidate' >&2
  exit 1
fi

echo '[PASS] ADK promotion stages exactly one three-path transaction and rolls back atomically'
