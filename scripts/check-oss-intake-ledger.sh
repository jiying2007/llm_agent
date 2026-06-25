#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SUMMARY_JSON=0
FIXTURES=1
LEDGERS=()

usage() {
  cat <<USAGE
usage: scripts/check-oss-intake-ledger.sh [root] [--fixture FILE] [--no-fixtures] [--summary-json]

Validates the report-only OSS intake P1 contract:
  - root manifests for discovery sources, scoring policy, and subrepo lifecycle
  - pass/fail JSONL fixtures under fixtures/oss-intake/
  - optional candidate ledger JSONL files

Default ledger discovery checks reports/oss-discovery-candidates-*.jsonl when present.
The check is offline and read-only: it does not search, clone, register, absorb, or remove repositories.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture)
      [[ $# -ge 2 ]] || {
        echo "[FAIL] --fixture requires a file path" >&2
        exit 1
      }
      LEDGERS+=("$2")
      FIXTURES=0
      shift 2
      ;;
    --no-fixtures)
      FIXTURES=0
      shift
      ;;
    --summary-json)
      SUMMARY_JSON=1
      shift
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

python3 - "$ROOT" "$SUMMARY_JSON" "$FIXTURES" "${LEDGERS[@]}" <<'PY'
import glob
import json
import os
import re
import subprocess
import sys

root = os.path.abspath(sys.argv[1])
summary_json = sys.argv[2] == "1"
check_fixtures = sys.argv[3] == "1"
explicit_ledgers = sys.argv[4:]

manifest_paths = {
    "discovery": "manifests/oss_discovery_sources.json",
    "scoring": "manifests/oss_candidate_scoring_policy.json",
    "lifecycle": "manifests/subrepo_lifecycle.json",
}

domain_fits = {"workflow-core", "agent-ecosystem", "tooling", "knowledge", "runtime-policy"}
decisions = {"discovered", "scored", "watch", "onboard-candidate", "archive-only", "rejected"}
hard_reject_codes = {
    "archived",
    "missing-license",
    "no-clear-license",
    "stale-maintenance",
    "stale-12mo",
    "unsafe-install-surface",
    "unsafe-install",
    "duplicate-without-advantage",
    "duplicate-no-advantage",
    "not-verifiable",
    "unverifiable-source",
    "private-or-hosted-dependency",
    "requires-unreviewable-credentials-or-hosted-infra",
}
score_weights = {
    "relevance": 30,
    "maintenance": 20,
    "engineering_quality": 15,
    "security_supply_chain": 15,
    "uniqueness": 10,
    "adoption_cost_inverse": 10,
}
required_candidate_keys = {
    "repo",
    "url",
    "source",
    "topics",
    "stars",
    "forks",
    "pushed_at",
    "license",
    "archived",
    "domain_fit",
    "score",
    "score_breakdown",
    "hard_rejects",
    "decision",
    "reason",
    "evidence",
}

failures = []
stats = {"manifests": 0, "ledgers": 0, "candidates": 0, "pass_fixtures": 0, "fail_fixtures": 0}


def rel(path):
    try:
        return os.path.relpath(path, root)
    except ValueError:
        return path


def fail(message):
    failures.append(message)


def read_json(rel_path):
    path = os.path.join(root, rel_path)
    if not os.path.isfile(path):
        fail(f"missing manifest: {rel_path}")
        return None
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except Exception as exc:
        fail(f"invalid JSON in {rel_path}: {exc}")
        return None
    stats["manifests"] += 1
    return data


def validate_manifests():
    discovery = read_json(manifest_paths["discovery"])
    scoring = read_json(manifest_paths["scoring"])
    lifecycle = read_json(manifest_paths["lifecycle"])

    allowed_sources = set()
    if discovery:
        if discovery.get("status") != "report-only":
            fail("oss_discovery_sources.json status must be report-only")
        rules = discovery.get("rules", {})
        for key in (
            "discovery_must_not_clone",
            "discovery_must_not_register",
            "discovery_must_not_absorb",
            "discovery_must_not_execute_external_code",
        ):
            if rules.get(key) is not True:
                fail(f"oss_discovery_sources.json rules.{key} must be true")
        sources = discovery.get("sources")
        if not isinstance(sources, list) or not sources:
            fail("oss_discovery_sources.json sources must be a non-empty array")
        else:
            for source in sources:
                source_id = source.get("id")
                if not source_id:
                    fail("discovery source missing id")
                else:
                    allowed_sources.add(source_id)
                if source.get("mode") not in {"metadata-only", "ledger-only"}:
                    fail(f"discovery source has invalid mode: {source_id}")

    if scoring:
        if scoring.get("status") != "report-only":
            fail("oss_candidate_scoring_policy.json status must be report-only")
        dimensions = scoring.get("dimensions")
        if not isinstance(dimensions, list):
            fail("oss_candidate_scoring_policy.json dimensions must be an array")
        else:
            got = {item.get("id"): item.get("weight") for item in dimensions}
            if got != score_weights:
                fail(f"scoring dimensions mismatch: {got}")
        if scoring.get("score_max") != 100:
            fail("oss_candidate_scoring_policy.json score_max must be 100")
        rule_ids = {item.get("id") for item in scoring.get("hard_reject_rules", [])}
        for required in ("archived", "missing-license", "stale-maintenance", "unsafe-install-surface"):
            if required not in rule_ids:
                fail(f"missing hard reject rule: {required}")

    if lifecycle:
        if lifecycle.get("status") != "report-only":
            fail("subrepo_lifecycle.json status must be report-only")
        states = lifecycle.get("states")
        expected_states = [
            "discovered",
            "scored",
            "quarantined",
            "analyzed",
            "watch",
            "onboard-candidate",
            "active-core",
            "active-reference",
            "archive-only",
            "disabled",
            "removed",
            "rejected",
        ]
        if states != expected_states:
            fail("subrepo_lifecycle.json states must match oss-intake lifecycle order")
        entries = lifecycle.get("entries")
        if not isinstance(entries, list):
            fail("subrepo_lifecycle.json entries must be an array")
        else:
            seen = set()
            for entry in entries:
                repo = entry.get("repo")
                state = entry.get("state")
                if not repo:
                    fail("lifecycle entry missing repo")
                elif repo in seen:
                    fail(f"duplicate lifecycle entry: {repo}")
                else:
                    seen.add(repo)
                if state not in expected_states:
                    fail(f"invalid lifecycle state for {repo}: {state}")
                if entry.get("automation_eligible") is not False:
                    fail(f"P1 lifecycle entry must remain automation_eligible=false: {repo}")
                evidence = entry.get("evidence")
                if not isinstance(evidence, list) or not evidence:
                    fail(f"lifecycle entry must include evidence: {repo}")
                materialization = entry.get("materialization")
                if materialization is not None and materialization not in {"root-local-reference"}:
                    fail(f"invalid lifecycle materialization for {repo}: {materialization}")
                if materialization == "root-local-reference":
                    source = entry.get("source")
                    if not isinstance(source, dict):
                        fail(f"root-local reference missing source object: {repo}")
                    else:
                        source_url = source.get("url")
                        provider = source.get("provider")
                        branch = source.get("branch")
                        commit = source.get("commit")
                        retrieved_at = source.get("retrieved_at")
                        if not isinstance(source_url, str) or not re.fullmatch(r"https://(github\.com|gitee\.com)/[^/\s]+/[^/\s]+(?:\.git)?/?", source_url):
                            fail(f"root-local reference has invalid source.url: {repo}")
                        if provider not in {"github", "gitee"}:
                            fail(f"root-local reference has invalid source.provider: {repo}")
                        if not isinstance(branch, str) or not branch:
                            fail(f"root-local reference missing source.branch: {repo}")
                        if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
                            fail(f"root-local reference has invalid source.commit: {repo}")
                        if not isinstance(retrieved_at, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", retrieved_at):
                            fail(f"root-local reference has invalid source.retrieved_at: {repo}")
                        repo_path = os.path.join(root, repo or "")
                        if repo and os.path.isdir(repo_path):
                            try:
                                actual_commit = subprocess.check_output(
                                    ["git", "-C", repo_path, "rev-parse", "HEAD"],
                                    text=True,
                                    stderr=subprocess.DEVNULL,
                                ).strip()
                            except Exception:
                                actual_commit = ""
                            if commit and actual_commit and actual_commit != commit:
                                fail(f"root-local reference commit drift for {repo}: {actual_commit} != {commit}")
                        else:
                            fail(f"root-local reference directory missing: {repo}")
                    boundaries = entry.get("runtime_boundaries")
                    if not isinstance(boundaries, list) or not boundaries:
                        fail(f"root-local reference must include runtime_boundaries: {repo}")
                    elif not all(isinstance(item, str) and item for item in boundaries):
                        fail(f"root-local reference runtime_boundaries must be non-empty strings: {repo}")
                    evidence_text = "\n".join(evidence or [])
                    for report_kind in ("oss-analysis", "oss-absorption-plan", "oss-security-review", "oss-deep-assessment"):
                        pattern = rf"reports/{report_kind}-.*{re.escape(repo or '')}.*\.md"
                        if repo and not re.search(pattern, evidence_text):
                            fail(f"root-local reference missing {report_kind} evidence report: {repo}")
            registry_path = os.path.join(root, "subrepos/registry.csv")
            if os.path.isfile(registry_path):
                with open(registry_path, "r", encoding="utf-8") as handle:
                    registry_repos = [
                        line.split(",", 1)[0]
                        for line in handle.read().splitlines()[1:]
                        if line.strip()
                    ]
                missing = sorted(set(registry_repos) - seen)
                extra = sorted(seen - set(registry_repos))
                if missing:
                    fail(f"subrepo_lifecycle.json missing registry repos: {', '.join(missing)}")
                if extra:
                    fail(f"subrepo_lifecycle.json has entries not in registry: {', '.join(extra)}")

    return allowed_sources or {"github-search", "github-graphql", "openssf-scorecard", "user-provided-url", "local-reports"}


def is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def validate_candidate(candidate, path, line_no, allowed_sources, seen_repos):
    context = f"{rel(path)}:{line_no}"
    if not isinstance(candidate, dict):
        fail(f"{context}: row must be a JSON object")
        return

    missing = sorted(required_candidate_keys - set(candidate))
    if missing:
        fail(f"{context}: missing required keys: {', '.join(missing)}")
        return

    repo = candidate["repo"]
    url = candidate["url"]
    if not isinstance(repo, str) or not re.fullmatch(r"[^/\s]+/[^/\s]+", repo):
        fail(f"{context}: repo must be owner/name")
    if not isinstance(url, str):
        fail(f"{context}: url must be a string")
    else:
        url_match = re.fullmatch(r"https://(github\.com|gitee\.com)/([^/\s]+/[^/\s]+)(?:\.git)?/?", url)
        if not url_match or url_match.group(2) != repo:
            fail(f"{context}: url must match https://github.com/<repo> or https://gitee.com/<repo>")
    if repo in seen_repos:
        fail(f"{context}: duplicate repo in ledger: {repo}")
    seen_repos.add(repo)

    if candidate["source"] not in allowed_sources:
        fail(f"{context}: invalid source: {candidate['source']}")
    if not isinstance(candidate["topics"], list) or any(not isinstance(item, str) for item in candidate["topics"]):
        fail(f"{context}: topics must be an array of strings")
    for key in ("stars", "forks"):
        if not is_int(candidate[key]) or candidate[key] < 0:
            fail(f"{context}: {key} must be a non-negative integer")
    if not isinstance(candidate["pushed_at"], str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", candidate["pushed_at"]):
        fail(f"{context}: pushed_at must be YYYY-MM-DD")
    if not isinstance(candidate["license"], str) or candidate["license"] == "":
        fail(f"{context}: license must be a non-empty string")
    if not isinstance(candidate["archived"], bool):
        fail(f"{context}: archived must be boolean")
    if candidate["domain_fit"] not in domain_fits:
        fail(f"{context}: invalid domain_fit: {candidate['domain_fit']}")
    if candidate["decision"] not in decisions:
        fail(f"{context}: invalid decision: {candidate['decision']}")
    if not isinstance(candidate["reason"], str) or not candidate["reason"].strip():
        fail(f"{context}: reason must be a non-empty string")
    if not isinstance(candidate["evidence"], list) or any(not isinstance(item, str) for item in candidate["evidence"]):
        fail(f"{context}: evidence must be an array of strings")
    if not isinstance(candidate["hard_rejects"], list) or any(item not in hard_reject_codes for item in candidate["hard_rejects"]):
        fail(f"{context}: hard_rejects contains invalid codes")

    score = candidate["score"]
    breakdown = candidate["score_breakdown"]
    if score is None:
        if breakdown is not None:
            fail(f"{context}: score_breakdown must be null when score is null")
        if candidate["decision"] != "discovered":
            fail(f"{context}: score=null requires decision=discovered")
    else:
        if not is_int(score) or score < 0 or score > 100:
            fail(f"{context}: score must be an integer in 0..100")
        if not isinstance(breakdown, dict):
            fail(f"{context}: scored candidates require score_breakdown")
        else:
            if set(breakdown) != set(score_weights):
                fail(f"{context}: score_breakdown dimensions mismatch")
            total = 0
            for key, max_value in score_weights.items():
                value = breakdown.get(key)
                if not is_int(value) or value < 0 or value > max_value:
                    fail(f"{context}: score_breakdown.{key} must be 0..{max_value}")
                else:
                    total += value
            if is_int(score) and total != score:
                fail(f"{context}: score_breakdown total {total} != score {score}")
        if candidate["license"] in {"unknown", "none", "NONE", "NOASSERTION"} and "missing-license" not in candidate["hard_rejects"] and "no-clear-license" not in candidate["hard_rejects"]:
            fail(f"{context}: scored candidate with unclear license must hard reject")

    has_hard_reject = bool(candidate["hard_rejects"])
    if candidate["archived"] and "archived" not in candidate["hard_rejects"]:
        fail(f"{context}: archived=true requires hard_rejects to include archived")
    if has_hard_reject and candidate["decision"] != "rejected":
        fail(f"{context}: hard reject candidates must use decision=rejected")

    if isinstance(score, int) and not has_hard_reject:
        decision = candidate["decision"]
        if score >= 90 and decision != "onboard-candidate":
            fail(f"{context}: score >= 90 requires decision=onboard-candidate")
        elif 80 <= score <= 89 and decision != "watch":
            fail(f"{context}: score 80..89 requires decision=watch")
        elif 65 <= score <= 79 and decision not in {"archive-only", "watch"}:
            fail(f"{context}: score 65..79 requires decision=archive-only or watch")
        elif score < 65 and decision != "rejected":
            fail(f"{context}: score < 65 requires decision=rejected")
        if 65 <= score <= 79 and decision == "watch" and "owner" not in candidate["reason"].lower():
            fail(f"{context}: score 65..79 watch decision requires explicit owner reason")

    stats["candidates"] += 1


def validate_ledger(path, allowed_sources, expect_pass=True):
    if not os.path.isfile(path):
        fail(f"missing ledger: {rel(path)}")
        return False
    before = len(failures)
    seen_repos = set()
    with open(path, "r", encoding="utf-8") as handle:
        lines = handle.read().splitlines()
    if not lines:
        fail(f"{rel(path)}: ledger must not be empty")
    for line_no, line in enumerate(lines, 1):
        if not line.strip():
            fail(f"{rel(path)}:{line_no}: blank lines are not allowed")
            continue
        try:
            row = json.loads(line)
        except Exception as exc:
            fail(f"{rel(path)}:{line_no}: invalid JSON: {exc}")
            continue
        validate_candidate(row, path, line_no, allowed_sources, seen_repos)
    stats["ledgers"] += 1
    return len(failures) == before if expect_pass else len(failures) > before


allowed_sources = validate_manifests()

for ledger in explicit_ledgers:
    validate_ledger(os.path.abspath(ledger), allowed_sources, expect_pass=True)

if not explicit_ledgers:
    for path in sorted(glob.glob(os.path.join(root, "reports/oss-discovery-candidates-*.jsonl"))):
        validate_ledger(path, allowed_sources, expect_pass=True)

if check_fixtures:
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/pass/*.jsonl"))):
        before = len(failures)
        validate_ledger(path, allowed_sources, expect_pass=True)
        if len(failures) == before:
            stats["pass_fixtures"] += 1
    for path in sorted(glob.glob(os.path.join(root, "fixtures/oss-intake/fail/*.jsonl"))):
        before = len(failures)
        validate_ledger(path, allowed_sources, expect_pass=False)
        if len(failures) == before:
            fail(f"{rel(path)}: fail fixture unexpectedly passed")
        else:
            del failures[before:]
            stats["fail_fixtures"] += 1

if failures:
    if summary_json:
        print(json.dumps({"status": "fail", "failures": len(failures), **stats}, ensure_ascii=False))
    print("[FAIL] oss intake ledger checks failed", file=sys.stderr)
    for item in failures[:20]:
        print(f"  - {item}", file=sys.stderr)
    if len(failures) > 20:
        print(f"  - ... {len(failures) - 20} more", file=sys.stderr)
    sys.exit(2)

if summary_json:
    print(json.dumps({"status": "pass", "failures": 0, **stats}, ensure_ascii=False))
else:
    print(
        "[PASS] oss intake P1 report-only checks healthy: "
        f"manifests={stats['manifests']} ledgers={stats['ledgers']} "
        f"candidates={stats['candidates']} pass_fixtures={stats['pass_fixtures']} "
        f"fail_fixtures={stats['fail_fixtures']}"
    )
PY
