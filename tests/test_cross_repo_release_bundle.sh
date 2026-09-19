#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for path in "$ROOT/scripts/cross-repo-release-bundle.sh" "$ROOT/tools/codex_assets/release_bundle.py"; do
  if grep -Eq '(^|[[:space:]"[])(rtk)([[:space:]",]]|$)' "$path"; then
    echo "[FAIL] release bundle implementation depends on local rtk wrapper: $path" >&2
    exit 1
  fi
done
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

for name in workspace adk codex hub; do
  repo="$TMP_DIR/$name"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email test@example.invalid
  git -C "$repo" config user.name test
  printf 'baseline\n' >"$repo/tracked.txt"
  git -C "$repo" add tracked.txt
  git -C "$repo" commit -q -m baseline
done

printf 'changed\n' >>"$TMP_DIR/workspace/tracked.txt"
printf 'untracked\n' >"$TMP_DIR/workspace/new.txt"
printf '%s\n' '{"schema_version":3,"content_changes":1,"content_noop":false,"build_receipt":{"tree_sha256":"build-hash"},"target_receipt":{"precondition_paths_sha256":"target-hash","precondition_paths":2}}' >"$TMP_DIR/plan.json"
printf '# reviewing candidate\n' >"$TMP_DIR/candidate.md"
printf '{"status":"pass"}\n' >"$TMP_DIR/evidence.json"

bash "$ROOT/scripts/cross-repo-release-bundle.sh" \
  --workspace-root "$TMP_DIR/workspace" \
  --adk-root "$TMP_DIR/adk" \
  --codex-root "$TMP_DIR/codex" \
  --hub-root "$TMP_DIR/hub" \
  --codex-plan "$TMP_DIR/plan.json" \
  --hub-candidate "$TMP_DIR/candidate.md" \
  --evidence "$TMP_DIR/evidence.json" >"$TMP_DIR/bundle.json"

python3 -c 'import json,sys; p=json.load(open(sys.argv[1])); assert p["projection"] == "adk-cross-repo-release-bundle-v1"; assert len(p["repositories"]) == 4; assert p["repositories"][0]["dirty"] is True; assert len(p["repositories"][0]["worktree_fingerprint"]) == 64; assert p["codex_plan"]["schema_version"] == 3; assert p["release_authorized"] is False; assert p["privacy"]["raw_diff_stored"] is False; assert "diff" not in p["repositories"][0]' "$TMP_DIR/bundle.json"

cd /tmp
bash "$ROOT/scripts/cross-repo-release-bundle.sh" --help >/dev/null
echo "cross-repo release bundle tests passed"
