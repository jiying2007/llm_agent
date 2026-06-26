#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADK_ROOT="${WORKSPACE_ROOT}/agent-dev-kit"
REPORT="${WORKSPACE_ROOT}/reports/harness-loop-engineering-adoption-candidates-2026-06-25.md"
MATRIX="${WORKSPACE_ROOT}/subrepos/adoption-matrix.md"
MANIFEST="${ADK_ROOT}/manifests/harness_loop_engineering_contracts.json"

if [[ ! -d "${ADK_ROOT}" ]]; then
  echo "[FAIL] agent-dev-kit not found: ${ADK_ROOT}" >&2
  exit 1
fi

rtk bash "${ADK_ROOT}/scripts/check-harness-loop-engineering-contracts.sh"

rtk python3 - "$WORKSPACE_ROOT" "$REPORT" "$MATRIX" "$MANIFEST" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
report = Path(sys.argv[2])
matrix = Path(sys.argv[3])
manifest_path = Path(sys.argv[4])
failures = []


def fail(message):
    failures.append(message)


def rel(path):
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return str(path)


if not report.is_file():
    fail(f"missing report: {rel(report)}")
    report_text = ""
else:
    report_text = report.read_text(encoding="utf-8")

if not matrix.is_file():
    fail(f"missing adoption matrix: {rel(matrix)}")
    matrix_text = ""
else:
    matrix_text = matrix.read_text(encoding="utf-8")

try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except Exception as exc:
    fail(f"invalid manifest: {exc}")
    manifest = {}

source_ids = [
    "google-adk-python",
    "langgraph",
    "swe-bench",
    "inspect-ai",
    "promptfoo",
    "openai-agents-python",
    "openhands",
    "swe-agent",
    "smolagents",
    "deepeval",
    "phoenix",
    "lm-evaluation-harness",
]
supplemental_source_ids = [
    "temporal",
    "pydantic-ai",
    "langfuse",
    "aider",
    "mastra",
    "semantic-kernel",
    "haystack",
    "ragas",
    "crewai",
    "continue",
]
supplemental_source_aliases = {
    "crewai": ["crewai", "CrewAI"],
}
contract_ids = [
    "repo-task-evaluation-harness-v1",
    "agent-eval-ci-gate-v1",
    "durable-agent-loop-v1",
    "coding-agent-loop-v1",
    "trace-observability-contract-v1",
    "guardrail-handoff-contract-v1",
]
supplemental_contract_ids = [
    "durable-execution-contract-v1",
    "typed-hitl-graph-contract-v1",
    "coding-repair-loop-v1",
    "trace-eval-evidence-bundle-v1",
]


def has_token(text, token):
    return any(alias in text for alias in supplemental_source_aliases.get(token, [token]))

for token in source_ids + contract_ids:
    if token not in report_text:
        fail(f"report missing token: {token}")

for token in (
    "runtime-disabled",
    "method-only",
    "failure_replay",
    "checkpoint_policy",
    "redaction_policy",
    "positive_cases",
    "negative_cases",
):
    if token not in report_text:
        fail(f"report missing boundary token: {token}")

for token in source_ids:
    if token not in matrix_text:
        fail(f"adoption matrix missing source: {token}")

for token in (
    "reports/harness-loop-engineering-adoption-candidates-2026-06-25.md",
    "agent-dev-kit/manifests/harness_loop_engineering_contracts.json",
    "agent-dev-kit/scripts/check-harness-loop-engineering-contracts.sh",
    "scripts/check-harness-loop-engineering.sh",
):
    if token not in matrix_text:
        fail(f"adoption matrix missing evidence: {token}")

if manifest.get("report") != "../reports/harness-loop-engineering-adoption-candidates-2026-06-25.md":
    fail("manifest report path mismatch")

supplemental_reports = manifest.get("supplemental_reports")
if not isinstance(supplemental_reports, list) or not supplemental_reports:
    fail("manifest missing supplemental_reports")
else:
    supplemental_text = ""
    for item in supplemental_reports:
        if not isinstance(item, str) or not item:
            fail("manifest supplemental_reports item must be a non-empty string")
            continue
        path = (manifest_path.parent.parent / item).resolve()
        if not path.is_file():
            fail(f"missing supplemental report: {rel(path)}")
            continue
        text = path.read_text(encoding="utf-8")
        supplemental_text += "\n" + text
        if item == "../reports/harness-loop-engineering-adoption-candidates-2026-06-26.md":
            for token in supplemental_source_ids + supplemental_contract_ids:
                if not has_token(text, token):
                    fail(f"supplemental report missing token: {token}")
            for token in (
                "method-only",
                "runtime_enabled=false",
                "replay",
                "idempotency",
                "redaction",
                "repair",
                "dataset",
                "regression",
            ):
                if token not in text:
                    fail(f"supplemental report missing boundary token: {token}")

    for token in supplemental_source_ids + supplemental_contract_ids:
        if token not in matrix_text:
            fail(f"adoption matrix missing supplemental token: {token}")
        if not has_token(supplemental_text, token):
            fail(f"supplemental reports missing token: {token}")

if failures:
    for failure in failures:
        print(f"[FAIL] {failure}", file=sys.stderr)
    sys.exit(1)

print("[PASS] harness/loop engineering workspace evidence")
PY
