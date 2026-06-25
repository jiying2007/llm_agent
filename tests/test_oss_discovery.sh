#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" --dry-run --repo example/manual-discovery --out "${TMP_DIR}/manual.jsonl" >/dev/null
"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${TMP_DIR}/manual.jsonl" --summary-json >/dev/null

"${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" --dry-run --repo https://gitee.com/gitee-example/manual-discovery --out "${TMP_DIR}/gitee.jsonl" >/dev/null
"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${TMP_DIR}/gitee.jsonl" --summary-json >/dev/null

"${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" --dry-run --source "${ROOT}/fixtures/oss-intake/discovery-source.md" --out "${TMP_DIR}/source.jsonl" >/dev/null
"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${TMP_DIR}/source.jsonl" --summary-json >/dev/null

python3 - "${TMP_DIR}/gitee.jsonl" "${TMP_DIR}/source.jsonl" <<'PY'
import json
import sys

gitee_path, source_path = sys.argv[1:3]
with open(gitee_path, "r", encoding="utf-8") as handle:
    rows = [json.loads(line) for line in handle if line.strip()]
assert rows[0]["repo"] == "gitee-example/manual-discovery"
assert rows[0]["url"] == "https://gitee.com/gitee-example/manual-discovery"
assert rows[0]["source"] == "user-provided-url"

with open(source_path, "r", encoding="utf-8") as handle:
    by_repo = {row["repo"]: row for row in (json.loads(line) for line in handle if line.strip())}
assert by_repo["gitee-example/source-agent-kit"]["url"] == "https://gitee.com/gitee-example/source-agent-kit"
PY


"${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" \
  --dry-run \
  --github-query "topic:agent archived:false" \
  --github-response-fixture "${ROOT}/fixtures/oss-intake/github-search-response.json" \
  --github-rate-limit-out "${TMP_DIR}/rate-limit.json" \
  --out "${TMP_DIR}/github.jsonl" >/dev/null
"${ROOT}/scripts/check-oss-intake-ledger.sh" "${ROOT}" --no-fixtures --fixture "${TMP_DIR}/github.jsonl" --summary-json >/dev/null

python3 - "${TMP_DIR}/github.jsonl" "${TMP_DIR}/rate-limit.json" <<'PY'
import json
import os
import sys

ledger_path, rate_limit_path = sys.argv[1:3]
with open(ledger_path, "r", encoding="utf-8") as handle:
    rows = [json.loads(line) for line in handle if line.strip()]
by_repo = {row["repo"]: row for row in rows}

assert by_repo["codex-candidates/fresh-agent-kit"]["source"] == "github-search"
assert by_repo["codex-candidates/fresh-agent-kit"]["stars"] == 2400
assert by_repo["codex-candidates/fresh-agent-kit"]["license"] == "MIT"
assert by_repo["codex-candidates/fresh-agent-kit"]["hard_rejects"] == []

stale = by_repo["codex-candidates/stale-no-license"]
assert "missing-license" in stale["hard_rejects"]
assert "stale-maintenance" in stale["hard_rejects"]

duplicate = by_repo["example/tooling-agent"]
assert "duplicate-without-advantage" in duplicate["hard_rejects"]

assert os.path.isfile(rate_limit_path)
with open(rate_limit_path, "r", encoding="utf-8") as handle:
    rate = json.load(handle)
assert rate["source"] == "github-search"
assert rate["mode"] == "metadata-only"
assert rate["queries"][0]["result_count"] == 3
assert rate["token_used"] is False
PY

"${ROOT}/scripts/oss-intake.sh" discover --dry-run --repo example/wrapper-discovery --out "${TMP_DIR}/wrapper.jsonl" >/dev/null
"${ROOT}/scripts/run-oss-intake-cycle.sh" "${ROOT}" \
  --discover-github \
  --github-query "topic:agent archived:false" \
  --github-response-fixture "${ROOT}/fixtures/oss-intake/github-search-response.json" \
  --discovery-out "${TMP_DIR}/cycle-github.jsonl" \
  --score-out "${TMP_DIR}/cycle-score.md" \
  --github-rate-limit-out "${TMP_DIR}/cycle-rate-limit.json" \
  --out-json "${TMP_DIR}/cycle.json" \
  --out-md "${TMP_DIR}/cycle.md" \
  --queue-json "${TMP_DIR}/queue.json" \
  --queue-md "${TMP_DIR}/queue.md" \
  --evidence-md "${TMP_DIR}/evidence.md" >/dev/null

python3 - "${TMP_DIR}/cycle.json" "${TMP_DIR}/queue.json" "${TMP_DIR}/cycle-score.md" "${TMP_DIR}/cycle-rate-limit.json" <<'PY'
import json
import os
import sys

cycle_path, queue_path, score_path, rate_limit_path = sys.argv[1:5]
with open(cycle_path, "r", encoding="utf-8") as handle:
    cycle = json.load(handle)
commands = {item["name"] for item in cycle["commands"]}
assert "discover-oss-repos" in commands
assert "score-oss-candidates" in commands
assert os.path.isfile(score_path)
assert os.path.isfile(rate_limit_path)

with open(queue_path, "r", encoding="utf-8") as handle:
    queue = json.load(handle)
review_items = [item for item in queue["items"] if item["type"] == "candidate-review"]
assert review_items
assert any(item["status"] == "blocked" and "hard_rejects" in item["reason"] for item in review_items)
assert any("cycle-rate-limit.json" in evidence for item in review_items for evidence in item["evidence"])
PY

echo "[PASS] oss discovery tests passed"
