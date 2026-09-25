#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
FIXTURE="$TMP_DIR/workspace"
REPO="$FIXTURE/sample-repo"
mkdir -p "$FIXTURE/scripts" "$FIXTURE/subrepos" "$FIXTURE/manifests" \
  "$FIXTURE/tools/codex_assets" "$FIXTURE/tools/control_plane" "$REPO"
for script in classify-repo-worktree.sh analyze-repo.sh pipeline-subrepo-update.sh sync-subrepos.sh; do
  cp "$ROOT/scripts/$script" "$FIXTURE/scripts/"
done
cp "$ROOT/tools/__init__.py" "$FIXTURE/tools/"
cp "$ROOT/tools/codex_assets/__init__.py" "$ROOT/tools/codex_assets/intake_pipeline.py" \
  "$ROOT/tools/codex_assets/update_pipeline.py" "$FIXTURE/tools/codex_assets/"
cp "$ROOT/tools/control_plane/__init__.py" "$ROOT/tools/control_plane/reference_pins.py" \
  "$ROOT/tools/control_plane/process_budget.py" "$FIXTURE/tools/control_plane/"
chmod +x "$FIXTURE/scripts/"*.sh

git -C "$FIXTURE" init -q
git -C "$REPO" init -q
git -C "$REPO" config user.email fixture@example.invalid
git -C "$REPO" config user.name Fixture
git -C "$REPO" config core.fileMode true
git -C "$REPO" remote add origin https://github.com/example/sample-repo.git
printf '# committed source\n' >"$REPO/README.md"
printf 'system_prompt = "committed"\n' >"$REPO/prompt.py"
git -C "$REPO" add README.md prompt.py
git -C "$REPO" commit -q -m 'fixture source'
SOURCE_COMMIT="$(git -C "$REPO" rev-parse HEAD)"
printf '# dirty working tree\n' >"$REPO/README.md"
chmod 755 "$REPO/prompt.py"
mkdir -p "$REPO/uncommitted-skill"
printf '%s\n' '---' 'name: uncommitted-skill' '---' >"$REPO/uncommitted-skill/SKILL.md"
CLASSIFICATION_JSON="$("$FIXTURE/scripts/classify-repo-worktree.sh" "$FIXTURE" sample-repo)"
python3 - "$CLASSIFICATION_JSON" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
assert r['classification'] == 'mode+content+untracked', r
assert (r['mode_changes'], r['content_changes'], r['type_changes'], r['untracked_changes']) == (1, 1, 0, 1), r
PY

# Legacy worktree utilities remain covered independently; intake never uses this Root checkout.
cat >"$FIXTURE/subrepos/registry.csv" <<'CSV'
repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade
sample-repo,reference,P1,pull,main,yes,fixture,active,tester,2026-07-13,observe-first,A
CSV
printf 'phase=test\nallow_upstream_sync=yes\n' >"$FIXTURE/subrepos/phase-gate.env"
if "$FIXTURE/scripts/sync-subrepos.sh" "$FIXTURE" pull >"$TMP_DIR/sync.out" 2>&1; then
  echo '[FAIL] dirty pull unexpectedly passed' >&2; exit 1
fi
rg -q --fixed-strings 'pull refused for dirty worktree' "$TMP_DIR/sync.out"
test "$(git -C "$REPO" rev-parse HEAD)" = "$SOURCE_COMMIT"

CACHE="$TMP_DIR/cache"
mkdir -p "$CACHE/sample-repo"
cp -a "$REPO" "$CACHE/sample-repo/$SOURCE_COMMIT"
python3 - "$FIXTURE" "$SOURCE_COMMIT" <<'PY'
import json, sys
from pathlib import Path
value = {'schema': 'llm-agent-reference-pins/v2', 'policy': {
 'tracked_gitlink_forbidden': True, 'submodule_entry_forbidden': True,
 'runtime_enablement': False, 'pin_is_evidence_not_source': True,
 'materialization_root': 'user-cache-only', 'materialization_requires_explicit_id': True},
 'pins': [{'id':'sample-repo', 'kind':'reference-repo', 'path':'sample-repo',
           'url':'https://github.com/example/sample-repo.git', 'commit':sys.argv[2]}]}
(Path(sys.argv[1])/'manifests/reference_pins.json').write_text(json.dumps(value))
PY
ANALYZE_JSON="$("$FIXTURE/scripts/analyze-repo.sh" sample-repo --cache-root "$CACHE" --skill --summary-json)"
python3 - "$ANALYZE_JSON" "$SOURCE_COMMIT" "$FIXTURE" <<'PY'
import json, sys
from pathlib import Path
r = json.loads(sys.argv[1]); root = Path(sys.argv[3]); report = Path(r['report_dir'])
assert r['schema'] == 'llm-agent-intake-result/v2', r
assert r['source_commit'] == sys.argv[2], r
assert report == root/'reports/repo-analysis/sample-repo'/sys.argv[2][:12], r
analysis = json.loads((report/'analysis.json').read_text())
assert analysis['skills'] == [], analysis
assert analysis['source']['snapshot_mode'] == 'git-archive', analysis
assert analysis['source']['worktree']['classification'] == 'dirty-ignored-commit-snapshot', analysis
assert analysis['prompt_evidence']['code_signal_count'] == 1, analysis
assert (report/'skill-deep-analysis.md').is_file() and (report/'README.md').is_file()
assert 'uncommitted-skill' not in (report/'skill-deep-analysis.md').read_text()
decision = json.loads((report/'decision-candidate.json').read_text())
assert decision['evidence'] == ['analysis.json'], decision
assert decision['auto_apply'] is False and decision['status'] == 'review-required', decision
PY
test ! -e "$REPO/analysis"
test ! -e "$CACHE/sample-repo/$SOURCE_COMMIT/analysis"
if "$FIXTURE/scripts/analyze-repo.sh" sample-repo --cache-root "$CACHE" --ref=-unsafe >"$TMP_DIR/unsafe.out" 2>&1; then
  echo '[FAIL] unsafe ref accepted' >&2; exit 1
fi
rg -q --fixed-strings 'invalid git ref' "$TMP_DIR/unsafe.out"

# Poison old hooks: the cache pipeline must neither execute these nor use their grades.
for script in diff-scan.sh check-repo-quality.sh; do
  printf '#!/usr/bin/env bash\nexit 94\n' >"$FIXTURE/scripts/$script"
  chmod +x "$FIXTURE/scripts/$script"
done
PIPELINE_JSON="$("$FIXTURE/scripts/pipeline-subrepo-update.sh" --cache-root "$CACHE" --repository sample-repo \
  --report-only --recent-days 3650 --summary-json)"
python3 - "$PIPELINE_JSON" "$FIXTURE" <<'PY'
import json, sys
from pathlib import Path
r = json.loads(sys.argv[1])
assert r['schema'] == 'llm-agent-update-pipeline/v2', r
assert r['status'] == 'pass' and r['analyzed'] == [], r
assert r['eligible_repositories'] == [{'repository':'sample-repo','age_days':0}], r
assert r['network_writes'] is False and r['auto_apply'] is False, r
assert json.loads((Path(sys.argv[2])/r['report_json']).read_text()) == r
PY
"$FIXTURE/scripts/pipeline-subrepo-update.sh" --cache-root "$CACHE" --repository sample-repo \
  --recent-days 3650 --summary-json >"$TMP_DIR/active.json"
python3 - "$TMP_DIR/active.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
assert r['status'] == 'pass' and len(r['analyzed']) == 1, r
assert len(r['patterns']['evidence_files']) == 1, r
PY
if "$FIXTURE/scripts/pipeline-subrepo-update.sh" --cache-root "$TMP_DIR/missing" --summary-json >"$TMP_DIR/missing.json"; then
  echo '[FAIL] missing cache analysis accepted' >&2; exit 1
fi
python3 - "$TMP_DIR/missing.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
assert r['status'] == 'blocked' and r['analyzed'] == [], r
assert r['source_observations'][0]['status'] == 'not-materialized', r
PY
git -C "$CACHE/sample-repo/$SOURCE_COMMIT" remote set-url origin https://github.com/other/replaced.git
if "$FIXTURE/scripts/pipeline-subrepo-update.sh" --cache-root "$CACHE" --summary-json >"$TMP_DIR/replaced.json"; then
  echo '[FAIL] replaced source origin accepted' >&2; exit 1
fi
python3 - "$TMP_DIR/replaced.json" "$FIXTURE" <<'PY'
import json, sys
from pathlib import Path
r = json.load(open(sys.argv[1]))
assert r['status'] == 'fail' and 'origin' in r['failure'], r
assert json.loads((Path(sys.argv[2])/r['report_json']).read_text())['status'] == 'fail'
PY
if "$FIXTURE/scripts/classify-repo-worktree.sh" "$FIXTURE" ../escape >"$TMP_DIR/escape.out" 2>&1; then
  echo '[FAIL] traversal accepted' >&2; exit 1
fi
rg -q --fixed-strings 'invalid repo name' "$TMP_DIR/escape.out"
echo '[PASS] fixed-source analysis and cache-only pipeline preserve integrity and failure evidence'
