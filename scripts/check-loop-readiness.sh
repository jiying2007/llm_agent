#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${ROOT}/manifests/loop_readiness_contracts.json"
LIFECYCLE="${ROOT}/manifests/subrepo_lifecycle.json"
MATRIX="${ROOT}/subrepos/adoption-matrix.md"

python3 - "$ROOT" "$MANIFEST" "$LIFECYCLE" "$MATRIX" <<'PY'
import json
import os
import sys

root, manifest_path, lifecycle_path, matrix_path = sys.argv[1:5]
failures = []


def fail(message):
    failures.append(message)


def rel(path):
    return os.path.relpath(path, root)


def read_json(path):
    if not os.path.isfile(path):
        fail(f"missing file: {rel(path)}")
        return None
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception as exc:
        fail(f"invalid JSON in {rel(path)}: {exc}")
        return None


manifest = read_json(manifest_path)
lifecycle = read_json(lifecycle_path)

if not os.path.isfile(matrix_path):
    fail(f"missing file: {rel(matrix_path)}")
    matrix_text = ""
else:
    with open(matrix_path, "r", encoding="utf-8") as handle:
        matrix_text = handle.read()

required_metrics = {
    "tool_execution_evidence",
    "loop_recovery_evidence",
    "guardrail_coverage",
    "budget_control_evidence",
    "handoff_or_delegation_evidence",
    "termination_evidence",
}
required_loop_shapes = {"diagnostic_loop", "tdd_slice_loop", "reconciliation_loop_vocabulary"}
required_rules = [
    "contract_must_be_report_only",
    "contract_must_not_execute_external_runtime",
    "contract_must_not_install_dependencies",
    "contract_must_not_patch_hooks",
    "contract_must_not_start_daemons",
    "source_mapping_requires_report",
    "source_mapping_requires_adoption_matrix_evidence",
    "source_mapping_requires_lifecycle_evidence",
]

scale_report = "reports/oss-loop-readiness-hongmaple-scale-engine-2026-06-25.md"
scale_commit = "60f38279b76030056738cc9eac7bc8b9cc6173c2"

if manifest:
    if manifest.get("status") != "report-only":
        fail("loop_readiness_contracts.json status must be report-only")
    if manifest.get("default_mode") != "report-only":
        fail("loop_readiness_contracts.json default_mode must be report-only")
    metrics = manifest.get("metrics")
    if not isinstance(metrics, list):
        fail("loop_readiness_contracts.json metrics must be an array")
    else:
        metric_ids = {item.get("id") for item in metrics if isinstance(item, dict)}
        if metric_ids != required_metrics:
            fail(f"loop readiness metrics mismatch: {sorted(metric_ids)}")
        for metric in metrics:
            if not isinstance(metric, dict) or metric.get("required") is not True:
                fail("every loop readiness metric must be required=true")
    loop_shapes = manifest.get("loop_shapes")
    if not isinstance(loop_shapes, list):
        fail("loop_readiness_contracts.json loop_shapes must be an array")
    else:
        loop_shape_ids = {item.get("id") for item in loop_shapes if isinstance(item, dict)}
        missing = required_loop_shapes - loop_shape_ids
        if missing:
            fail(f"loop_readiness_contracts.json missing loop shapes: {', '.join(sorted(missing))}")
        for item in loop_shapes:
            if isinstance(item, dict) and item.get("id") == "reconciliation_loop_vocabulary" and item.get("runtime_enabled") is not False:
                fail("reconciliation_loop_vocabulary runtime_enabled must be false")
    rules = manifest.get("rules")
    if not isinstance(rules, dict):
        fail("loop_readiness_contracts.json rules must be an object")
    else:
        for rule in required_rules:
            if rules.get(rule) is not True:
                fail(f"loop_readiness_contracts.json rules.{rule} must be true")
    mappings = manifest.get("source_mappings")
    if not isinstance(mappings, list):
        fail("loop_readiness_contracts.json source_mappings must be an array")
    else:
        scale = next((item for item in mappings if isinstance(item, dict) and item.get("source_repo") == "scale-engine"), None)
        if not scale:
            fail("loop_readiness_contracts.json missing scale-engine source mapping")
        else:
            if scale.get("source_commit") != scale_commit:
                fail("scale-engine loop readiness source_commit drift")
            if scale.get("runtime_enabled") is not False:
                fail("scale-engine loop readiness runtime_enabled must be false")
            if scale.get("report") != scale_report:
                fail("scale-engine loop readiness report path mismatch")
            rejected = set(scale.get("rejected_runtime_surfaces") or [])
            for required in ("scale_cli_execution", "shield_hook_compilation", "orchestrator_daemon", "cortex_session_injection"):
                if required not in rejected:
                    fail(f"scale-engine mapping missing rejected runtime surface: {required}")

report_path = os.path.join(root, scale_report)
if not os.path.isfile(report_path):
    fail(f"missing report: {scale_report}")
else:
    with open(report_path, "r", encoding="utf-8") as handle:
        report_text = handle.read()
    for token in (
        "SessionStartSequence",
        "DiagnosticLoop",
        "AgentLoopReadiness",
        "WORKFLOW_EVAL",
        "ORCHESTRATOR",
        "runtime-disabled",
        "tool_execution_evidence",
        "termination_evidence",
    ):
        if token not in report_text:
            fail(f"{scale_report} missing token: {token}")

if lifecycle:
    entries = lifecycle.get("entries")
    if not isinstance(entries, list):
        fail("subrepo_lifecycle.json entries must be an array")
    else:
        scale_entry = next((item for item in entries if isinstance(item, dict) and item.get("repo") == "scale-engine"), None)
        if not scale_entry:
            fail("subrepo_lifecycle.json missing scale-engine entry")
        else:
            evidence = "\n".join(scale_entry.get("evidence") or [])
            if scale_report not in evidence:
                fail("scale-engine lifecycle evidence missing loop readiness report")
            source = scale_entry.get("source") or {}
            if source.get("commit") != scale_commit:
                fail("scale-engine lifecycle source.commit drift")
            if scale_entry.get("automation_eligible") is not False:
                fail("scale-engine lifecycle automation_eligible must be false")

if scale_report not in matrix_text:
    fail("adoption-matrix.md missing scale-engine loop readiness report evidence")
if "manifests/loop_readiness_contracts.json" not in matrix_text:
    fail("adoption-matrix.md missing loop readiness manifest evidence")
if "scale-engine" not in matrix_text or "loop readiness" not in matrix_text:
    fail("adoption-matrix.md missing scale-engine loop readiness adoption row")

if failures:
    for message in failures:
        print(f"[FAIL] {message}", file=sys.stderr)
    sys.exit(1)

print("[PASS] loop readiness contract checks passed")
PY
