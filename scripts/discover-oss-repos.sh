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
GITHUB_QUERIES=()
GITHUB_MAX_RESULTS=30
GITHUB_API_URL="https://api.github.com"
GITHUB_TOKEN_ENV="GITHUB_TOKEN"
GITHUB_RESPONSE_FIXTURE=""
GITHUB_RATE_LIMIT_OUT=""

usage() {
  cat <<USAGE
usage: scripts/discover-oss-repos.sh [root] --dry-run [--out FILE] [--source FILE_OR_DIR] [--repo owner/name|URL] [--domain-fit DOMAIN]
       [--github-query QUERY] [--github-max-results N] [--github-token-env ENV] [--github-rate-limit-out FILE]

Generates a report-only OSS discovery candidate JSONL ledger.
Local discovery is offline by default. GitHub REST metadata search runs only when --github-query is passed.
It does not clone repositories, register subrepos, absorb into ADK, or execute external code.
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
        echo "[FAIL] --repo requires owner/name or a supported repository URL" >&2
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
    --github-query)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --github-query requires a query string" >&2
        exit 1
      }
      GITHUB_QUERIES+=("$2")
      shift 2
      ;;
    --github-max-results)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --github-max-results requires a number" >&2
        exit 1
      }
      GITHUB_MAX_RESULTS="$2"
      shift 2
      ;;
    --github-api-url)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --github-api-url requires a URL" >&2
        exit 1
      }
      GITHUB_API_URL="$2"
      shift 2
      ;;
    --github-token-env)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --github-token-env requires an environment variable name" >&2
        exit 1
      }
      GITHUB_TOKEN_ENV="$2"
      shift 2
      ;;
    --github-response-fixture)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --github-response-fixture requires a file" >&2
        exit 1
      }
      GITHUB_RESPONSE_FIXTURE="$2"
      shift 2
      ;;
    --github-rate-limit-out)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --github-rate-limit-out requires a file" >&2
        exit 1
      }
      GITHUB_RATE_LIMIT_OUT="$2"
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
GITHUB_RATE_LIMIT_OUT="${GITHUB_RATE_LIMIT_OUT:-${ROOT}/reports/oss-discovery-rate-limit-${DATE}.json}"

python3 - "$ROOT" "$OUT" "$DATE" "$DOMAIN_FIT" "$GITHUB_MAX_RESULTS" "$GITHUB_API_URL" "$GITHUB_TOKEN_ENV" "$GITHUB_RESPONSE_FIXTURE" "$GITHUB_RATE_LIMIT_OUT" "${#SOURCES[@]}" "${SOURCES[@]}" "${#REPOS[@]}" "${REPOS[@]}" "${#GITHUB_QUERIES[@]}" "${GITHUB_QUERIES[@]}" <<'PY'
import datetime as dt
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

root = os.path.abspath(sys.argv[1])
out = os.path.abspath(sys.argv[2])
date = sys.argv[3]
domain_fit = sys.argv[4]
try:
    github_max_results = int(sys.argv[5])
except ValueError:
    raise SystemExit("[FAIL] --github-max-results must be an integer")
github_api_url = sys.argv[6].rstrip("/")
github_token_env = sys.argv[7]
github_response_fixture = sys.argv[8]
github_rate_limit_out = os.path.abspath(sys.argv[9])
source_count = int(sys.argv[10])
sources = sys.argv[11:11 + source_count]
repo_count_index = 11 + source_count
repo_count = int(sys.argv[repo_count_index])
repos = sys.argv[repo_count_index + 1:repo_count_index + 1 + repo_count]
github_count_index = repo_count_index + 1 + repo_count
github_query_count = int(sys.argv[github_count_index])
github_queries = sys.argv[github_count_index + 1:github_count_index + 1 + github_query_count]

if github_max_results < 1 or github_max_results > 100:
    raise SystemExit("[FAIL] --github-max-results must be in 1..100")

domain_fits = {"workflow-core", "agent-ecosystem", "tooling", "knowledge", "runtime-policy"}
score_weights = {
    "relevance": 30,
    "maintenance": 20,
    "engineering_quality": 15,
    "security_supply_chain": 15,
    "uniqueness": 10,
    "adoption_cost_inverse": 10,
}
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
if github_queries and "github-search" not in enabled_source_ids:
    raise SystemExit("[FAIL] github-search source must be enabled for GitHub discovery")

registry_path = os.path.join(root, "subrepos/registry.csv")
registered = set()
if os.path.isfile(registry_path):
    with open(registry_path, "r", encoding="utf-8") as handle:
        for line in handle.read().splitlines()[1:]:
            if line.strip():
                registered.add(line.split(",", 1)[0])

historical = set()
reports_dir = os.path.join(root, "reports")
if os.path.isdir(reports_dir):
    for name in os.listdir(reports_dir):
        path = os.path.join(reports_dir, name)
        if os.path.abspath(path) == out:
            continue
        if not re.fullmatch(r"oss-discovery-candidates-\d{4}-\d{2}-\d{2}\.jsonl", name):
            continue
        with open(path, "r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                try:
                    repo = json.loads(line).get("repo")
                except Exception:
                    continue
                if isinstance(repo, str):
                    historical.add(repo)

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
    if "runtime" in lower or "policy" in lower or "security" in lower or "sandbox" in lower:
        return "runtime-policy"
    if "skill" in lower or "agent" in lower or "mcp" in lower or "multi-agent" in lower:
        return "agent-ecosystem"
    if "workflow" in lower or "sdd" in lower or "spec" in lower or "orchestration" in lower:
        return "workflow-core"
    if "guide" in lower or "knowledge" in lower or "docs" in lower or "documentation" in lower:
        return "knowledge"
    return domain_fit

found = {}

def parse_repo_input(value):
    value = value.strip()
    url = None
    url_match = re.fullmatch(r"https://(github\.com|gitee\.com)/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?:\.git)?/?", value)
    if url_match:
        host = url_match.group(1)
        repo = url_match.group(2)
        url = f"https://{host}/{repo}"
        return repo, url
    return value, url

def normalize_repo(repo):
    if not re.fullmatch(r"[^/\s]+/[^/\s]+", repo):
        return None
    owner, name = repo.split("/", 1)
    if owner.lower() in {"github.com", "gitee.com", "http:", "https:"}:
        return None
    if name.endswith(".git"):
        name = name[:-4]
        repo = f"{owner}/{name}"
    return repo

def append_unique(items, value):
    if value and value not in items:
        items.append(value)

def append_reject(candidate, code):
    append_unique(candidate["hard_rejects"], code)

def date_only(value):
    if not isinstance(value, str) or not value:
        return date
    match = re.match(r"(\d{4}-\d{2}-\d{2})", value)
    return match.group(1) if match else date

def is_stale(pushed_at):
    try:
        pushed = dt.date.fromisoformat(date_only(pushed_at))
        current = dt.date.fromisoformat(date)
    except ValueError:
        return False
    return (current - pushed).days >= 365

def add_candidate(repo, source_id, evidence, text="", metadata=None):
    repo, url_override = parse_repo_input(repo)
    repo = normalize_repo(repo)
    if not repo:
        return
    metadata = metadata or {}
    owner, name = repo.split("/", 1)
    local_name = name
    if local_name in registered or repo in registered:
        return
    if repo not in found:
        license_value = metadata.get("license") or "unknown"
        pushed_at = date_only(metadata.get("pushed_at", date))
        found[repo] = {
            "repo": repo,
            "url": metadata.get("url") or url_override or f"https://github.com/{repo}",
            "source": source_id,
            "topics": metadata.get("topics", []),
            "stars": metadata.get("stars", 0),
            "forks": metadata.get("forks", 0),
            "pushed_at": pushed_at,
            "license": license_value,
            "archived": metadata.get("archived", False),
            "domain_fit": infer_domain(f"{repo} {text}"),
            "score": None,
            "score_breakdown": None,
            "hard_rejects": [],
            "decision": "discovered",
            "reason": metadata.get("reason", "discovered from local evidence; metadata enrichment required before scoring"),
            "evidence": [],
        }
    elif metadata:
        candidate = found[repo]
        candidate["topics"] = metadata.get("topics", candidate["topics"])
        candidate["stars"] = metadata.get("stars", candidate["stars"])
        candidate["forks"] = metadata.get("forks", candidate["forks"])
        candidate["pushed_at"] = date_only(metadata.get("pushed_at", candidate["pushed_at"]))
        candidate["license"] = metadata.get("license", candidate["license"]) or "unknown"
        candidate["archived"] = metadata.get("archived", candidate["archived"])
        candidate["reason"] = metadata.get("reason", candidate["reason"])
    if evidence not in found[repo]["evidence"]:
        found[repo]["evidence"].append(evidence)
    candidate = found[repo]
    if repo in historical:
        append_reject(candidate, "duplicate-without-advantage")
    reject_reasons = []
    if metadata and candidate["license"] in {"unknown", "NOASSERTION"}:
        append_reject(candidate, "missing-license")
        reject_reasons.append(f"license={candidate['license']}")
    if metadata and candidate["archived"] is True:
        append_reject(candidate, "archived")
        reject_reasons.append("archived=true")
    if metadata and is_stale(candidate["pushed_at"]):
        append_reject(candidate, "stale-maintenance")
        reject_reasons.append(f"pushed_at={candidate['pushed_at']}")
    if candidate["hard_rejects"]:
        candidate["score"] = 0
        candidate["score_breakdown"] = {key: 0 for key in score_weights}
        candidate["decision"] = "rejected"
        detail = f"; details={','.join(reject_reasons)}" if reject_reasons else ""
        candidate["reason"] = f"{candidate['reason']}; hard_rejects={','.join(candidate['hard_rejects'])}{detail}"

for repo in repos:
    add_candidate(repo, "user-provided-url", "manual --repo argument", repo)

if not sources and not github_queries and not repos:
    sources = [os.path.join(root, "reports")]

url_pattern = re.compile(r"https://(?:github\.com|gitee\.com)/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?")
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
            add_candidate(match.group(0), "local-reports", evidence, text[max(0, match.start() - 120):match.end() + 120])
        for match in shorthand_pattern.finditer(text):
            add_candidate(match.group(1), "local-reports", evidence, text[max(0, match.start() - 120):match.end() + 120])

def read_github_response(query):
    if github_response_fixture:
        with open(github_response_fixture, "r", encoding="utf-8") as handle:
            payload = json.load(handle)
        return payload, {
            "source": rel(os.path.abspath(github_response_fixture)),
            "limit": None,
            "remaining": None,
            "used": None,
            "reset": None,
            "resource": "search",
        }

    token = os.environ.get(github_token_env, "")
    params = urllib.parse.urlencode({
        "q": query,
        "sort": "updated",
        "order": "desc",
        "per_page": github_max_results,
    })
    url = f"{github_api_url}/search/repositories?{params}"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "llm-agent-oss-discovery",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
            headers = response.headers
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:500]
        raise SystemExit(f"[FAIL] GitHub search failed HTTP {exc.code}: {body}")
    except urllib.error.URLError as exc:
        raise SystemExit(f"[FAIL] GitHub search failed: {exc}")
    return payload, {
        "source": github_api_url,
        "limit": headers.get("x-ratelimit-limit"),
        "remaining": headers.get("x-ratelimit-remaining"),
        "used": headers.get("x-ratelimit-used"),
        "reset": headers.get("x-ratelimit-reset"),
        "resource": headers.get("x-ratelimit-resource"),
    }

def license_id(item):
    license_info = item.get("license")
    if isinstance(license_info, dict):
        value = license_info.get("spdx_id") or license_info.get("key") or license_info.get("name")
        return value or "unknown"
    return "unknown"

rate_limit_records = []
for query in github_queries:
    payload, rate = read_github_response(query)
    items = payload.get("items", []) if isinstance(payload, dict) else payload
    if not isinstance(items, list):
        raise SystemExit("[FAIL] GitHub search response must contain an items array")
    count = 0
    for item in items[:github_max_results]:
        if not isinstance(item, dict):
            continue
        full_name = item.get("full_name")
        if not isinstance(full_name, str):
            continue
        count += 1
        topics = [topic for topic in item.get("topics", []) if isinstance(topic, str)]
        description = item.get("description") if isinstance(item.get("description"), str) else ""
        language = item.get("language") if isinstance(item.get("language"), str) else ""
        search_text = " ".join([full_name, description, language, " ".join(topics)])
        metadata = {
            "topics": topics,
            "stars": int(item.get("stargazers_count") or 0),
            "forks": int(item.get("forks_count") or 0),
            "pushed_at": date_only(item.get("pushed_at", date)),
            "license": license_id(item),
            "archived": bool(item.get("archived", False)),
            "reason": "discovered from GitHub REST search metadata; human review required before scoring",
        }
        add_candidate(full_name, "github-search", f"github-search query: {query}", search_text, metadata)
    rate_limit_records.append({
        "query": query,
        "result_count": count,
        "total_count": payload.get("total_count") if isinstance(payload, dict) else None,
        "rate_limit": rate,
    })

if rate_limit_records:
    os.makedirs(os.path.dirname(github_rate_limit_out), exist_ok=True)
    with open(github_rate_limit_out, "w", encoding="utf-8") as handle:
        json.dump({
            "schema_version": 1,
            "mode": "metadata-only",
            "source": "github-search",
            "retrieved_at": date,
            "api_url": github_api_url,
            "token_env": github_token_env,
            "token_used": bool(os.environ.get(github_token_env, "")),
            "queries": rate_limit_records,
        }, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")

if not found:
    raise SystemExit("[FAIL] no OSS candidates discovered; pass --repo owner/name|URL or --source with GitHub/Gitee URLs")

os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as handle:
    for repo in sorted(found):
        handle.write(json.dumps(found[repo], ensure_ascii=False, sort_keys=True))
        handle.write("\n")

rate_limit_msg = f" rate_limit={rel(github_rate_limit_out)}" if rate_limit_records else ""
print(f"[PASS] discovery ledger written: {rel(out)} candidates={len(found)} mode=dry-run{rate_limit_msg}")
PY

"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${OUT}" >/dev/null
