#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${ROOT}/scripts/check-oss-approval-queue.sh" "${ROOT}" --summary-json >/dev/null
"${ROOT}/scripts/generate-oss-intake-approval-queue.sh" "${ROOT}" --out-json "${TMP_DIR}/queue.json" --out-md "${TMP_DIR}/queue.md" >/dev/null
"${ROOT}/scripts/check-oss-approval-queue.sh" "${ROOT}" --queue "${TMP_DIR}/queue.json" --summary-json >/dev/null
"${ROOT}/scripts/oss-intake.sh" queue --out-json "${TMP_DIR}/queue-via-wrapper.json" --out-md "${TMP_DIR}/queue-via-wrapper.md" >/dev/null

"${ROOT}/scripts/discover-oss-repos.sh" "${ROOT}" --dry-run --repo https://gitee.com/gitee-example/queue-review --out "${TMP_DIR}/gitee-ledger.jsonl" >/dev/null
"${ROOT}/scripts/generate-oss-intake-approval-queue.sh" "${ROOT}" --ledger "${TMP_DIR}/gitee-ledger.jsonl" --out-json "${TMP_DIR}/gitee-queue.json" --out-md "${TMP_DIR}/gitee-queue.md" >/dev/null
"${ROOT}/scripts/check-oss-approval-queue.sh" "${ROOT}" --queue "${TMP_DIR}/gitee-queue.json" --summary-json >/dev/null

python3 - "${TMP_DIR}/gitee-queue.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    queue = json.load(handle)

items = {item["id"]: item for item in queue["items"]}
item = items["candidate-review-gitee-example-queue-review"]
assert item["type"] == "candidate-review"
assert item["approval_level"] == "L1-plan-review"
assert item["status"] == "pending-approval"
assert "metadata enrichment" in item["reason"]
assert "candidate registration apply" in item["blocked_auto_actions"]
assert "ADK absorption" in item["blocked_auto_actions"]
PY

echo "[PASS] oss approval queue tests passed"
