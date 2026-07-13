#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO="${2:-}"
FORMAT="json"
FIELD=""

usage() {
  cat <<USAGE
usage: scripts/classify-repo-worktree.sh [root] <repo> [--format json|tsv] [--field <name>]

Classifies a repository worktree without modifying it. The classification
separates mode, content, file-type, untracked, and staged changes.
USAGE
}

if [[ -z "${REPO}" ]]; then
  usage >&2
  exit 1
fi
shift 2 || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="${2:-}"
      shift 2
      ;;
    --field)
      FIELD="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

case "${FORMAT}" in
  json|tsv) ;;
  *)
    echo "[FAIL] unsupported format: ${FORMAT}" >&2
    exit 1
    ;;
esac

if [[ ! "${REPO}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "[FAIL] invalid repo name: ${REPO}" >&2
  exit 1
fi

ROOT="$(cd "${ROOT}" && pwd)"
REPO_PATH="${ROOT}/${REPO}"
if [[ ! -d "${REPO_PATH}" ]] || ! git -C "${REPO_PATH}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[FAIL] repository unavailable: ${REPO_PATH}" >&2
  exit 1
fi

python3 - "${REPO_PATH}" "${REPO}" "${FORMAT}" "${FIELD}" <<'PY'
import hashlib
import json
import os
import subprocess
import sys

repo_path, repo_name, output_format, field = sys.argv[1:5]


def git(*args, text=True, input_data=None):
    return subprocess.run(
        ["git", "-C", repo_path, *args],
        check=False,
        text=text,
        input=input_data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


status_v1 = git("status", "--porcelain", "--untracked-files=all")
if status_v1.returncode != 0:
    raise SystemExit(f"[FAIL] git status failed for {repo_name}: {status_v1.stderr.strip()}")
status_lines = status_v1.stdout.splitlines()
fingerprint_payload = status_v1.stdout

status_v2 = git("status", "--porcelain=v2", "-z", "--untracked-files=all")
if status_v2.returncode != 0:
    raise SystemExit(f"[FAIL] git status v2 failed for {repo_name}: {status_v2.stderr.strip()}")

mode_paths = set()
type_paths = set()
untracked_paths = set()
staged_paths = set()
tracked = []

for record in status_v2.stdout.split("\0"):
    if not record:
        continue
    tag = record[0]
    if tag == "1":
        parts = record.split(" ", 8)
        if len(parts) != 9:
            continue
        _, xy, _, _, index_mode, worktree_mode, _, index_hash, path = parts
        if xy[0] != ".":
            staged_paths.add(path)
        if index_mode != worktree_mode:
            if index_mode[:3] != worktree_mode[:3]:
                type_paths.add(path)
            else:
                mode_paths.add(path)
        tracked.append((path, index_hash))
    elif tag == "2":
        parts = record.split(" ", 9)
        if len(parts) >= 10:
            _, xy, _, _, index_mode, worktree_mode, _, index_hash, _, path = parts
            if xy[0] != ".":
                staged_paths.add(path)
            if index_mode != worktree_mode:
                if index_mode[:3] != worktree_mode[:3]:
                    type_paths.add(path)
                else:
                    mode_paths.add(path)
            tracked.append((path, index_hash))
    elif tag == "u":
        parts = record.split(" ", 10)
        if len(parts) == 11:
            staged_paths.add(parts[-1])
            tracked.append((parts[-1], ""))
    elif tag == "?":
        untracked_paths.add(record[2:])

existing = [(path, index_hash) for path, index_hash in tracked if os.path.lexists(os.path.join(repo_path, path))]
working_hashes = {}
if existing:
    path_input = "".join(path + "\n" for path, _ in existing)
    hash_proc = git("hash-object", "--stdin-paths", input_data=path_input)
    if hash_proc.returncode != 0:
        raise SystemExit(f"[FAIL] git hash-object failed for {repo_name}: {hash_proc.stderr.strip()}")
    hashes = hash_proc.stdout.splitlines()
    if len(hashes) != len(existing):
        raise SystemExit(f"[FAIL] git hash-object count mismatch for {repo_name}")
    working_hashes = {path: digest for (path, _), digest in zip(existing, hashes)}

content_paths = set()
for path, index_hash in tracked:
    working_hash = working_hashes.get(path)
    if not index_hash or working_hash != index_hash:
        content_paths.add(path)

categories = []
for category, paths in (
    ("mode", mode_paths),
    ("content", content_paths),
    ("type", type_paths),
    ("untracked", untracked_paths),
    ("staged", staged_paths),
):
    if paths:
        categories.append(category)

head = git("rev-parse", "HEAD")
branch = git("branch", "--show-current")
record = {
    "schema_version": 1,
    "repo": repo_name,
    "head": head.stdout.strip() if head.returncode == 0 else "",
    "branch": branch.stdout.strip() if branch.returncode == 0 else "",
    "dirty_count": len(status_lines),
    "classification": "+".join(categories) if categories else "clean",
    "categories": categories,
    "mode_changes": len(mode_paths),
    "content_changes": len(content_paths),
    "type_changes": len(type_paths),
    "untracked_changes": len(untracked_paths),
    "staged_changes": len(staged_paths),
    "status_fingerprint": hashlib.sha256(fingerprint_payload.encode("utf-8")).hexdigest(),
}

if field:
    if field not in record:
        raise SystemExit(f"[FAIL] unsupported field: {field}")
    value = record[field]
    if isinstance(value, (dict, list)):
        print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))
    else:
        print(value)
elif output_format == "tsv":
    print("\t".join(str(record[key]) for key in (
        "classification",
        "dirty_count",
        "mode_changes",
        "content_changes",
        "type_changes",
        "untracked_changes",
        "staged_changes",
        "status_fingerprint",
    )))
else:
    print(json.dumps(record, ensure_ascii=False, separators=(",", ":")))
PY
