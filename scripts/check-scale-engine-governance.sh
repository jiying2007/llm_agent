#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST="${ROOT}/manifests/scale_engine_governance_contracts.json"
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
matrix_text = ""
if os.path.isfile(matrix_path):
    with open(matrix_path, "r", encoding="utf-8") as handle:
        matrix_text = handle.read()
else:
    fail(f"missing file: {rel(matrix_path)}")

scale_commit = "60f38279b76030056738cc9eac7bc8b9cc6173c2"
scale_report = "reports/oss-governance-contracts-hongmaple-scale-engine-2026-06-25.md"
required_modes = ["minimal", "standard", "expanded", "critical"]
required_signals = {
    "docs_only_low_risk",
    "normal_engineering_work",
    "cross_module_scope",
    "interactive_or_visual_flow",
    "public_interface_change",
    "critical_risk_domain",
    "critical_file_path",
    "resource_lifecycle",
}
required_resource_types = {
    "canonical-doc",
    "decision-record",
    "contract",
    "reusable-script",
    "task-artifact",
    "evidence-report",
    "generated-media",
    "temporary",
}
required_rules = [
    "contract_must_be_report_only",
    "contract_must_not_execute_scale_runtime",
    "contract_must_not_install_dependencies",
    "contract_must_not_patch_hooks",
    "contract_must_not_start_daemons",
    "contract_must_not_create_scale_runtime_state",
    "progressive_mode_must_not_lower_detected_risk",
    "resource_runtime_outputs_must_not_be_promoted_without_review",
    "source_mapping_requires_report",
    "source_mapping_requires_adoption_matrix_evidence",
    "source_mapping_requires_lifecycle_evidence",
]

if manifest:
    if manifest.get("status") != "report-only":
        fail("scale_engine_governance_contracts.json status must be report-only")
    if manifest.get("default_mode") != "report-only":
        fail("scale_engine_governance_contracts.json default_mode must be report-only")
    source = manifest.get("source_mapping") or {}
    if source.get("source_repo") != "scale-engine":
        fail("source_mapping.source_repo must be scale-engine")
    if source.get("source_commit") != scale_commit:
        fail("source_mapping.source_commit drift")
    if source.get("runtime_enabled") is not False:
        fail("source_mapping.runtime_enabled must be false")
    if source.get("report") != scale_report:
        fail("source_mapping.report mismatch")
    if len(source.get("source_files") or []) < 5:
        fail("source_mapping.source_files must include the reviewed governance sources")

    progressive = manifest.get("progressive_governance") or {}
    if progressive.get("modes") != required_modes:
        fail("progressive_governance.modes must preserve minimal->critical order")
    signals = {item.get("id") for item in progressive.get("signals") or [] if isinstance(item, dict)}
    missing_signals = required_signals - signals
    if missing_signals:
        fail(f"progressive_governance missing signals: {', '.join(sorted(missing_signals))}")
    behaviors = progressive.get("required_behaviors") or {}
    for mode in required_modes:
        if not isinstance(behaviors.get(mode), list) or not behaviors.get(mode):
            fail(f"progressive_governance.required_behaviors.{mode} must be non-empty")

    resources = manifest.get("resource_lifecycle") or {}
    resource_types = {item.get("id") for item in resources.get("types") or [] if isinstance(item, dict)}
    missing_types = required_resource_types - resource_types
    if missing_types:
        fail(f"resource_lifecycle missing types: {', '.join(sorted(missing_types))}")
    for item in resources.get("types") or []:
        if not item.get("git_policy") or not item.get("lifecycle"):
            fail(f"resource_lifecycle type missing git_policy/lifecycle: {item.get('id')}")

    rules = manifest.get("rules") or {}
    for rule in required_rules:
        if rules.get(rule) is not True:
            fail(f"scale_engine_governance_contracts.json rules.{rule} must be true")

report_path = os.path.join(root, scale_report)
if not os.path.isfile(report_path):
    fail(f"missing report: {scale_report}")
else:
    with open(report_path, "r", encoding="utf-8") as handle:
        report_text = handle.read()
    for token in (
        "ProgressiveGovernance.ts",
        "RESOURCE_GOVERNANCE.md",
        "TOOL_ORCHESTRATION.md",
        "runtime-disabled",
        "Progressive Governance Contract",
        "Resource Lifecycle Contract",
        "critical",
        "task-artifact",
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
                fail("scale-engine lifecycle evidence missing governance contracts report")
            if (scale_entry.get("source") or {}).get("commit") != scale_commit:
                fail("scale-engine lifecycle source.commit drift")
            if scale_entry.get("automation_eligible") is not False:
                fail("scale-engine lifecycle automation_eligible must be false")

for token in (
    "scale-engine",
    "progressive governance",
    "resource lifecycle",
    scale_report,
    "manifests/scale_engine_governance_contracts.json",
    "scripts/check-scale-engine-governance.sh",
):
    if token not in matrix_text:
        fail(f"adoption-matrix.md missing token: {token}")

if failures:
    for message in failures:
        print(f"[FAIL] {message}", file=sys.stderr)
    sys.exit(1)

print("[PASS] scale-engine governance contract checks passed")
PY
