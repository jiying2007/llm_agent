#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${ROOT}/scripts/practice-intake.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
AS_OF="2026-07-19"

"${CLI}" check --kind policy --input "${ROOT}/manifests/external_practice_sources.json" >/dev/null
"${CLI}" check --kind plan --input "${ROOT}/fixtures/external-practice/cycle-plan.json" >/dev/null

python3 - "${ROOT}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
schema_dir = root / "schemas"
names = [
    "external-practice-candidate.schema.json",
    "external-practice-decision.schema.json",
    "external-practice-cycle-plan.schema.json",
    "external-practice-cycle-evidence.schema.json",
]
schemas = {name: json.loads((schema_dir / name).read_text(encoding="utf-8")) for name in names}
assert all(value["$schema"] == "https://json-schema.org/draft/2020-12/schema" for value in schemas.values())
provider_set = {"github", "gitlab", "gitee", "openai-official", "anthropic-official", "wechat", "manual"}
candidate_provider = set(schemas[names[0]]["properties"]["provider"]["enum"])
plan_provider = set(schemas[names[2]]["properties"]["jobs"]["items"]["properties"]["provider"]["enum"])
assert candidate_provider == provider_set == plan_provider
assert schemas[names[2]]["properties"]["jobs"]["contains"]["properties"]["enabled"]["const"] is True
job_schema = schemas[names[3]]["properties"]["jobs"]["items"]
assert job_schema["additionalProperties"] is False
assert schemas[names[3]]["properties"]["boundaries"]["additionalProperties"] is False
assert all(item["const"] is False for item in schemas[names[3]]["properties"]["boundaries"]["properties"].values())
PY

for provider in github gitlab gitee; do
  "${CLI}" collect \
    --provider "${provider}" \
    --query agent \
    --fixture "${ROOT}/fixtures/external-practice/providers/${provider}.json" \
    --as-of "${AS_OF}" \
    --out "${TMP_DIR}/${provider}.jsonl" \
    --evidence-out "${TMP_DIR}/${provider}-evidence.json" >/dev/null
  "${CLI}" check --kind candidate --input "${TMP_DIR}/${provider}.jsonl" >/dev/null
  "${CLI}" check --kind evidence --input "${TMP_DIR}/${provider}-evidence.json" >/dev/null
done

for provider in openai-official anthropic-official; do
  "${CLI}" collect \
    --provider "${provider}" \
    --input "${ROOT}/fixtures/external-practice/providers/official.json" \
    --as-of "${AS_OF}" \
    --out "${TMP_DIR}/${provider}.jsonl" \
    --evidence-out "${TMP_DIR}/${provider}-evidence.json" >/dev/null
  "${CLI}" check --kind candidate --input "${TMP_DIR}/${provider}.jsonl" >/dev/null
done

"${CLI}" collect \
  --provider wechat \
  --input "${ROOT}/fixtures/external-practice/providers/wechat.jsonl" \
  --as-of "${AS_OF}" \
  --out "${TMP_DIR}/wechat.jsonl" \
  --evidence-out "${TMP_DIR}/wechat-evidence.json" >/dev/null
"${CLI}" check --kind candidate --input "${TMP_DIR}/wechat.jsonl" >/dev/null

"${CLI}" collect \
  --provider manual \
  --input "${ROOT}/fixtures/external-practice/providers/manual.jsonl" \
  --url "https://github.com/example/manual-agent" \
  --as-of "${AS_OF}" \
  --out "${TMP_DIR}/manual.jsonl" \
  --evidence-out "${TMP_DIR}/manual-evidence.json" >/dev/null
"${CLI}" check --kind candidate --input "${TMP_DIR}/manual.jsonl" >/dev/null

if GITEE_TOKEN="fixture-secret-must-not-leak" "${CLI}" collect \
  --provider gitee \
  --query agent \
  --fixture "${ROOT}/fixtures/external-practice/providers/gitee-empty.json" \
  --as-of "${AS_OF}" \
  --out "${TMP_DIR}/gitee-empty.jsonl" \
  --evidence-out "${TMP_DIR}/gitee-empty-evidence.json" >/dev/null; then
  echo "[FAIL] degraded-empty Gitee collection returned a clean exit" >&2
  exit 1
fi

if "${CLI}" collect \
  --provider github \
  --query agent \
  --as-of "${AS_OF}" \
  --out "${TMP_DIR}/network-disabled.jsonl" \
  --evidence-out "${TMP_DIR}/network-disabled-evidence.json" >/dev/null; then
  echo "[FAIL] network-disabled collection returned a clean exit" >&2
  exit 1
fi

python3 - "${TMP_DIR}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
gitee = json.loads((root / "gitee.jsonl").read_text(encoding="utf-8").strip())
assert gitee["provider"] == "gitee"
assert gitee["canonical_url"] == "https://gitee.com/example/agent-skill-kit"
assert gitee["repository"]["host"] == "gitee.com"
assert gitee["license"] == "MulanPSL-2.0"
assert gitee["review_status"] == "review-required"
assert gitee["body_persisted"] is False
assert gitee["auto_actions"] == []

empty = json.loads((root / "gitee-empty-evidence.json").read_text(encoding="utf-8"))
assert empty["jobs"][0]["status"] == "degraded-empty"
assert (root / "gitee-empty.jsonl").read_text(encoding="utf-8") == ""
network_disabled = json.loads((root / "network-disabled-evidence.json").read_text(encoding="utf-8"))
assert network_disabled["status"] == "degraded"
assert network_disabled["jobs"][0]["status"] == "not-run-network-disabled"

for path in root.iterdir():
    if path.is_file():
        assert "fixture-secret-must-not-leak" not in path.read_text(encoding="utf-8", errors="ignore")
PY

"${CLI}" queue \
  --ledger "${TMP_DIR}/gitee-empty.jsonl" \
  --evidence "${TMP_DIR}/gitee-empty-evidence.json" \
  --as-of "${AS_OF}" \
  --out-json "${TMP_DIR}/empty-queue.json" \
  --out-md "${TMP_DIR}/empty-queue.md" >/dev/null

if "${CLI}" queue \
  --ledger "${TMP_DIR}/gitee.jsonl" \
  --evidence "${TMP_DIR}/gitee-empty-evidence.json" \
  --out-json "${TMP_DIR}/mismatched-queue.json" \
  --out-md "${TMP_DIR}/mismatched-queue.md" >/dev/null 2>&1; then
  echo "[FAIL] queue accepted evidence for a different candidate ledger" >&2
  exit 1
fi

"${CLI}" cycle \
  --plan "${ROOT}/fixtures/external-practice/cycle-plan.json" \
  --out-ledger "${TMP_DIR}/cycle-a.jsonl" \
  --out-queue "${TMP_DIR}/cycle-a-queue.json" \
  --out-evidence "${TMP_DIR}/cycle-a-evidence.json" \
  --out-md "${TMP_DIR}/cycle-a.md" >/dev/null
"${CLI}" cycle \
  --plan "${ROOT}/fixtures/external-practice/cycle-plan.json" \
  --out-ledger "${TMP_DIR}/cycle-b.jsonl" \
  --out-queue "${TMP_DIR}/cycle-b-queue.json" \
  --out-evidence "${TMP_DIR}/cycle-b-evidence.json" \
  --out-md "${TMP_DIR}/cycle-b.md" >/dev/null

"${CLI}" check --kind candidate --input "${TMP_DIR}/cycle-a.jsonl" >/dev/null
"${CLI}" check --kind queue --input "${TMP_DIR}/cycle-a-queue.json" >/dev/null
"${CLI}" check --kind evidence --input "${TMP_DIR}/cycle-a-evidence.json" >/dev/null
cmp "${TMP_DIR}/cycle-a.jsonl" "${TMP_DIR}/cycle-b.jsonl"

"${CLI}" recommend \
  --ledger "${TMP_DIR}/cycle-a.jsonl" \
  --out-json "${TMP_DIR}/recommendations.json" \
  --out-md "${TMP_DIR}/recommendations.md" >/dev/null

python3 - "${TMP_DIR}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
rows = [json.loads(line) for line in (root / "cycle-a.jsonl").read_text(encoding="utf-8").splitlines() if line]
providers = {row["provider"] for row in rows}
assert providers == {"github", "gitlab", "gitee", "openai-official", "anthropic-official", "wechat", "manual"}
assert len(rows) == 7
evidence = json.loads((root / "cycle-a-evidence.json").read_text(encoding="utf-8"))
assert evidence["status"] == "complete"
assert evidence["candidate_count"] == 7
assert evidence["auto_actions"] == []
queue = json.loads((root / "cycle-a-queue.json").read_text(encoding="utf-8"))
assert queue["status"] == "review-required"
assert len([item for item in queue["items"] if item["type"] == "candidate-review"]) == 7
empty_queue = json.loads((root / "empty-queue.json").read_text(encoding="utf-8"))
assert empty_queue["items"][0]["type"] == "provider-health"
assert empty_queue["items"][0]["status"] == "degraded-empty"
PY

for fixture in \
  "${ROOT}/fixtures/external-practice/negative/old-oss-candidate.jsonl" \
  "${ROOT}/fixtures/external-practice/negative/body-persisted.jsonl" \
  "${ROOT}/fixtures/external-practice/negative/auto-action.jsonl"; do
  if "${CLI}" check --kind candidate --input "${fixture}" >/dev/null 2>&1; then
    echo "[FAIL] invalid candidate fixture passed: ${fixture}" >&2
    exit 1
  fi
done

if "${CLI}" check --kind decision --input "${ROOT}/fixtures/external-practice/negative/decision-missing-owner.jsonl" >/dev/null 2>&1; then
  echo "[FAIL] ownerless decision passed" >&2
  exit 1
fi

if "${CLI}" check --kind plan --input "${ROOT}/fixtures/external-practice/negative/plan-unknown-provider.json" >/dev/null 2>&1; then
  echo "[FAIL] unknown provider plan passed" >&2
  exit 1
fi

if "${CLI}" collect --provider manual --url "http://github.com/example/insecure" --as-of "${AS_OF}" --out "${TMP_DIR}/http.jsonl" --evidence-out "${TMP_DIR}/http-evidence.json" >/dev/null 2>&1; then
  echo "[FAIL] HTTP manual URL passed" >&2
  exit 1
fi

if "${CLI}" collect --provider manual --url "https://untrusted.example/agent" --as-of "${AS_OF}" --out "${TMP_DIR}/host.jsonl" --evidence-out "${TMP_DIR}/host-evidence.json" >/dev/null 2>&1; then
  echo "[FAIL] untrusted manual host passed" >&2
  exit 1
fi

if "${CLI}" collect --provider github --query agent --input "${ROOT}/fixtures/external-practice/providers/manual.jsonl" --as-of "${AS_OF}" --out "${TMP_DIR}/ignored-input.jsonl" --evidence-out "${TMP_DIR}/ignored-input-evidence.json" >/dev/null 2>&1; then
  echo "[FAIL] provider-incompatible input was silently ignored" >&2
  exit 1
fi

ln -s "${ROOT}/fixtures/external-practice/providers/gitee.json" "${TMP_DIR}/gitee-symlink.json"
if "${CLI}" collect --provider gitee --query agent --fixture "${TMP_DIR}/gitee-symlink.json" --as-of "${AS_OF}" --out "${TMP_DIR}/symlink-input.jsonl" --evidence-out "${TMP_DIR}/symlink-input-evidence.json" >/dev/null 2>&1; then
  echo "[FAIL] symlink input passed" >&2
  exit 1
fi

python3 - "${TMP_DIR}/transaction-ledger.jsonl" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_text("sentinel\n", encoding="utf-8")
PY
ln -s "${TMP_DIR}/manual-evidence.json" "${TMP_DIR}/transaction-evidence.json"
if "${CLI}" collect \
  --provider manual \
  --url "https://developers.openai.com/codex?sig=fixture-secret#section" \
  --as-of "${AS_OF}" \
  --out "${TMP_DIR}/transaction-ledger.jsonl" \
  --evidence-out "${TMP_DIR}/transaction-evidence.json" >/dev/null 2>&1; then
  echo "[FAIL] symlink output passed" >&2
  exit 1
fi
if [[ "$(<"${TMP_DIR}/transaction-ledger.jsonl")" != "sentinel" ]]; then
  echo "[FAIL] rejected multi-output transaction partially replaced an earlier output" >&2
  exit 1
fi

"${CLI}" collect \
  --provider manual \
  --url "https://developers.openai.com/codex?sig=fixture-secret#section" \
  --as-of "${AS_OF}" \
  --out "${TMP_DIR}/query-redacted.jsonl" \
  --evidence-out "${TMP_DIR}/query-redacted-evidence.json" >/dev/null
if rg -q --fixed-strings "fixture-secret" "${TMP_DIR}/query-redacted.jsonl" "${TMP_DIR}/query-redacted-evidence.json"; then
  echo "[FAIL] opaque URL query value was persisted" >&2
  exit 1
fi

python3 - "${ROOT}/fixtures/external-practice/providers/wechat.jsonl" "${TMP_DIR}/wechat-unverified.jsonl" <<'PY'
import json
import pathlib
import sys
row = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
row["verification_status"] = "unreviewed"
pathlib.Path(sys.argv[2]).write_text(json.dumps(row, ensure_ascii=False) + "\n", encoding="utf-8")
PY
"${CLI}" collect \
  --provider wechat \
  --input "${TMP_DIR}/wechat-unverified.jsonl" \
  --as-of "${AS_OF}" \
  --out "${TMP_DIR}/wechat-unverified-candidate.jsonl" \
  --evidence-out "${TMP_DIR}/wechat-unverified-evidence.json" >/dev/null
python3 - "${TMP_DIR}/wechat-unverified-candidate.jsonl" <<'PY'
import json
import pathlib
import sys
row = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert row["trust_status"] == "unverified-metadata"
assert "verification-review-required" in row["risk_flags"]
PY

python3 - "${TMP_DIR}/cycle-a-evidence.json" "${TMP_DIR}/inconsistent-evidence.json" <<'PY'
import json
import pathlib
import sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
value["candidate_count"] += 1
pathlib.Path(sys.argv[2]).write_text(json.dumps(value), encoding="utf-8")
PY
if "${CLI}" check --kind evidence --input "${TMP_DIR}/inconsistent-evidence.json" >/dev/null 2>&1; then
  echo "[FAIL] inconsistent cycle evidence passed" >&2
  exit 1
fi

python3 - "${TMP_DIR}/cycle-a-queue.json" "${TMP_DIR}/inconsistent-queue.json" <<'PY'
import json
import pathlib
import sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
value["candidate_count"] += 1
pathlib.Path(sys.argv[2]).write_text(json.dumps(value), encoding="utf-8")
PY
if "${CLI}" check --kind queue --input "${TMP_DIR}/inconsistent-queue.json" >/dev/null 2>&1; then
  echo "[FAIL] inconsistent review queue passed" >&2
  exit 1
fi

python3 - "${ROOT}/fixtures/external-practice/cycle-plan.json" "${TMP_DIR}/disabled-plan.json" <<'PY'
import json
import pathlib
import sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for job in value["jobs"]:
    job["enabled"] = False
pathlib.Path(sys.argv[2]).write_text(json.dumps(value), encoding="utf-8")
PY
if "${CLI}" check --kind plan --input "${TMP_DIR}/disabled-plan.json" >/dev/null 2>&1; then
  echo "[FAIL] all-disabled cycle plan passed" >&2
  exit 1
fi

python3 - "${TMP_DIR}/oversized.json" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_text('[' + (' ' * 4194305) + ']', encoding='utf-8')
PY
if "${CLI}" collect --provider gitee --query agent --fixture "${TMP_DIR}/oversized.json" --as-of "${AS_OF}" --out "${TMP_DIR}/oversized.jsonl" --evidence-out "${TMP_DIR}/oversized-evidence.json" >/dev/null 2>&1; then
  echo "[FAIL] oversized fixture passed" >&2
  exit 1
fi

echo "[PASS] external practice intake contracts, providers, security and idempotence passed"
