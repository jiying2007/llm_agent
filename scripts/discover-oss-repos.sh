#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DRY_RUN=0
OUT=""
DATE="${OSS_INTAKE_DATE:-$(date '+%Y-%m-%d')}"
DOMAIN_FIT="tooling"
SOURCES=()
REPOS=()

usage() {
  cat <<USAGE
usage: scripts/discover-oss-repos.sh [root] --dry-run [--out FILE] [--source FILE_OR_DIR] [--repo owner/name] [--domain-fit DOMAIN]

Generates a report-only OSS discovery candidate JSONL ledger from local evidence.
It does not use network access, clone repositories, register subrepos, absorb into ADK, or execute external code.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --out)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --out requires a file" >&2
        exit 1
      }
      OUT="$2"
      shift 2
      ;;
    --source)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --source requires a file or directory" >&2
        exit 1
      }
      SOURCES+=("$2")
      shift 2
      ;;
    --repo)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --repo requires owner/name" >&2
        exit 1
      }
      REPOS+=("$2")
      shift 2
      ;;
    --domain-fit)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --domain-fit requires a value" >&2
        exit 1
      }
      DOMAIN_FIT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
    *)
      ROOT="$1"
      shift
      ;;
  esac
done

if [[ "${DRY_RUN}" -ne 1 ]]; then
  echo "[FAIL] discovery currently requires --dry-run" >&2
  exit 1
fi

OUT="${OUT:-${ROOT}/reports/oss-discovery-candidates-${DATE}.jsonl}"

python3 - "$ROOT" "$OUT" "$DATE" "$DOMAIN_FIT" "${#SOURCES[@]}" "${SOURCES[@]}" "${#REPOS[@]}" "${REPOS[@]}" <<'PY'
import json
import os
import re
import sys

root = os.path.abspath(sys.argv[1])
out = os.path.abspath(sys.argv[2])
date = sys.argv[3]
domain_fit = sys.argv[4]
source_count = int(sys.argv[5])
sources = sys.argv[6:6 + source_count]
repo_count_index = 6 + source_count
repo_count = int(sys.argv[repo_count_index])
repos = sys.argv[repo_count_index + 1:repo_count_index + 1 + repo_count]

domain_fits = {"workflow-core", "agent-ecosystem", "tooling", "knowledge", "runtime-policy"}
if domain_fit not in domain_fits:
    raise SystemExit(f"[FAIL] invalid --domain-fit: {domain_fit}")

manifest_path = os.path.join(root, "manifests/oss_discovery_sources.json")
with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

if manifest.get("status") != "report-only":
    raise SystemExit("[FAIL] oss_discovery_sources.json must be report-only")
rules = manifest.get("rules", {})
for key in (
    "discovery_must_not_clone",
    "discovery_must_not_register",
    "discovery_must_not_absorb",
    "discovery_must_not_execute_external_code",
):
    if rules.get(key) is not True:
        raise SystemExit(f"[FAIL] discovery rule must be true: {key}")

enabled_source_ids = {item.get("id") for item in manifest.get("sources", []) if item.get("enabled")}
if "local-reports" not in enabled_source_ids:
    raise SystemExit("[FAIL] local-reports source must be enabled for offline discovery")

registry_path = os.path.join(root, "subrepos/registry.csv")
registered = set()
if os.path.isfile(registry_path):
    with open(registry_path, "r", encoding="utf-8") as handle:
        for line in handle.read().splitlines()[1:]:
            if line.strip():
                registered.add(line.split(",", 1)[0])

def rel(path):
    try:
        return os.path.relpath(path, root)
    except ValueError:
        return path

def iter_files(path):
    abs_path = os.path.abspath(path)
    if os.path.isdir(abs_path):
        for dirpath, _, filenames in os.walk(abs_path):
            for name in filenames:
                if name.endswith((".md", ".txt", ".json", ".jsonl", ".csv")):
                    yield os.path.join(dirpath, name)
    elif os.path.isfile(abs_path):
        yield abs_path

def infer_domain(text):
    lower = text.lower()
    if "runtime" in lower or "policy" in lower or "security" in lower:
        return "runtime-policy"
    if "skill" in lower or "agent" in lower or "mcp" in lower:
        return "agent-ecosystem"
    if "workflow" in lower or "sdd" in lower or "spec" in lower:
        return "workflow-core"
    if "guide" in lower or "knowledge" in lower or "docs" in lower:
        return "knowledge"
    return domain_fit

found = {}

def add_candidate(repo, source_id, evidence, text=""):
    if not re.fullmatch(r"[^/\s]+/[^/\s]+", repo):
        return
    owner, name = repo.split("/", 1)
    if owner.lower() in {"github.com", "http:", "https:"}:
        return
    if name.endswith(".git"):
        name = name[:-4]
        repo = f"{owner}/{name}"
    local_name = name
    if local_name in registered or repo in registered:
        return
    if repo not in found:
        found[repo] = {
            "repo": repo,
            "url": f"https://github.com/{repo}",
            "source": source_id,
            "topics": [],
            "stars": 0,
            "forks": 0,
            "pushed_at": date,
            "license": "unknown",
            "archived": False,
            "domain_fit": infer_domain(f"{repo} {text}"),
            "score": None,
            "score_breakdown": None,
            "hard_rejects": [],
            "decision": "discovered",
            "reason": "discovered from local evidence; metadata enrichment required before scoring",
            "evidence": [],
        }
    if evidence not in found[repo]["evidence"]:
        found[repo]["evidence"].append(evidence)

for repo in repos:
    add_candidate(repo, "user-provided-url", "manual --repo argument", repo)

if not sources:
    sources = [os.path.join(root, "reports")]

url_pattern = re.compile(r"https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?:\.git)?")
shorthand_pattern = re.compile(r"\bgithub:([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)\b")
for source in sources:
    for path in iter_files(source):
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as handle:
                text = handle.read()
        except Exception:
            continue
        evidence = rel(path)
        for match in url_pattern.finditer(text):
            add_candidate(match.group(1), "local-reports", evidence, text[max(0, match.start() - 120):match.end() + 120])
        for match in shorthand_pattern.finditer(text):
            add_candidate(match.group(1), "local-reports", evidence, text[max(0, match.start() - 120):match.end() + 120])

if not found:
    raise SystemExit("[FAIL] no OSS candidates discovered; pass --repo owner/name or --source with GitHub URLs")

os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as handle:
    for repo in sorted(found):
        handle.write(json.dumps(found[repo], ensure_ascii=False, sort_keys=True))
        handle.write("\n")

print(f"[PASS] discovery ledger written: {rel(out)} candidates={len(found)} mode=dry-run")
PY

"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${OUT}" >/dev/null
