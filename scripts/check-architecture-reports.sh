#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SUMMARY_JSON=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-architecture-reports.sh [root] [--summary-json]

Checks reports/architecture target architecture reports for required sections,
operating model, landing protocol, runtime delivery, knowledge promotion,
state reconciliation, status consistency, structured requirements,
optimization backlog, implementation tasks, evidence, rejection records,
and source-to-live boundary language.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

python3 - "$ROOT" "$SUMMARY_JSON" <<'PY'
import glob
import json
import os
import re
import sys

root, summary_json = sys.argv[1:3]
summary_json = summary_json == "1"
arch_dir = os.path.join(root, "reports", "architecture")
readme = os.path.join(arch_dir, "README.md")
optimization_manifest_path = os.path.join(root, "manifests", "comprehensive_optimization_backlog.json")
product_scorecard_path = os.path.join(root, "manifests", "product_maturity_scorecard.json")
report_registry_path = os.path.join(root, "manifests", "report_registry.json")
adk_template_path = os.path.join(root, "agent-dev-kit", "templates", "artifacts", "target-architecture-report-template.md")
failures = []


def rel(path):
    return os.path.relpath(path, root)


def fail(message):
    failures.append(message)


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


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


def has_heading(content, heading):
    return re.search(rf"^{re.escape(heading)}\s*$", content, re.MULTILINE) is not None


def section(content, heading):
    match = re.search(rf"^{re.escape(heading)}\s*$", content, re.MULTILINE)
    if not match:
        return ""
    start = match.end()
    next_heading = re.search(r"^##\s+", content[start:], re.MULTILINE)
    if next_heading:
        return content[start:start + next_heading.start()]
    return content[start:]


if not os.path.isdir(arch_dir):
    fail("reports/architecture directory missing")
if not os.path.isfile(readme):
    fail("reports/architecture/README.md missing")
else:
    readme_text = read(readme)
    for token in ("必填内容", "Evidence Index", "source-to-live", "~/.codex", "运行态交付", "知识提升", "状态对账", "状态一致性", "结构化需求审查", "全面优化 backlog", "manifests/comprehensive_optimization_backlog.json"):
        if token not in readme_text:
            fail(f"{rel(readme)} missing required token: {token}")

optimization_manifest = read_json(optimization_manifest_path)
optimization_items = []
optimization_source_report = ""
optimization_source_path = ""
if optimization_manifest:
    optimization_schema_version = optimization_manifest.get("schema_version")
    if optimization_schema_version not in {1, 2}:
        fail("comprehensive_optimization_backlog.json schema_version must be 1 or 2")
    allowed_statuses = {"landed-design"} if optimization_schema_version == 1 else {"active", "superseded"}
    if optimization_manifest.get("status") not in allowed_statuses:
        fail(
            "comprehensive_optimization_backlog.json status must be one of: "
            + ", ".join(sorted(allowed_statuses))
        )
    optimization_source_report = optimization_manifest.get("source_report")
    if not isinstance(optimization_source_report, str) or not optimization_source_report:
        fail("comprehensive_optimization_backlog.json source_report is required")
    else:
        source_relative = os.path.normpath(optimization_source_report)
        if os.path.isabs(optimization_source_report) or source_relative.startswith(".."):
            fail("comprehensive_optimization_backlog.json source_report must be repository-relative")
        else:
            source_candidate = os.path.join(root, source_relative)
            if not os.path.isfile(source_candidate):
                fail(
                    "comprehensive_optimization_backlog.json source_report is missing: "
                    + optimization_source_report
                )
            else:
                optimization_source_path = source_candidate
    rules = optimization_manifest.get("rules")
    if not isinstance(rules, dict):
        fail("comprehensive_optimization_backlog.json rules must be an object")
    else:
        required_rules = [
            "report_must_reference_manifest",
            "report_must_list_every_item_id",
            "items_must_have_verification",
            "items_must_keep_design_and_implementation_status_separate",
            "adk_template_must_carry_pattern",
            "implementation_requires_owner_approval",
            "no_live_apply_without_source_to_live_evidence",
        ]
        if optimization_schema_version == 2:
            required_rules.extend([
                "backlog_extensions_are_allowed",
                "item_ids_must_be_unique_and_sequential",
                "current_report_is_registry_driven",
                "blocked_items_require_blocking_condition",
            ])
        for rule in required_rules:
            if rules.get(rule) is not True:
                fail(f"comprehensive_optimization_backlog.json rules.{rule} must be true")
    if optimization_manifest.get("adk_template") != "agent-dev-kit/templates/artifacts/target-architecture-report-template.md":
        fail("comprehensive_optimization_backlog.json adk_template mismatch")
    raw_items = optimization_manifest.get("items")
    if not isinstance(raw_items, list):
        fail("comprehensive_optimization_backlog.json items must be an array")
    else:
        optimization_items = [item for item in raw_items if isinstance(item, dict)]
        actual_ids = [item.get("id") for item in optimization_items]
        expected_ids = [f"G{i}" for i in range(1, len(optimization_items) + 1)]
        if len(optimization_items) < 10:
            fail("comprehensive_optimization_backlog.json must preserve the G1-G10 baseline")
        if actual_ids != expected_ids:
            fail(
                "comprehensive_optimization_backlog.json item ids must be unique and sequential: "
                f"{expected_ids}"
            )
        required_areas = {
            "Goal and scope control",
            "Governance correctness",
            "Evidence integrity",
            "Functional coverage",
            "Performance and token cost",
            "Maintainability",
            "Extensibility",
            "Asset experience",
            "Knowledge retention",
            "Release and rollback clarity",
        }
        actual_areas = {item.get("optimization_area") for item in optimization_items}
        missing_areas = required_areas - actual_areas
        if missing_areas:
            fail(f"comprehensive_optimization_backlog.json missing optimization areas: {', '.join(sorted(missing_areas))}")
        for item in optimization_items:
            item_id = item.get("id") or "<missing>"
            if item.get("priority") not in {"P0", "P1", "P2"}:
                fail(f"comprehensive_optimization_backlog.json {item_id} priority must be P0/P1/P2")
            if item.get("design_status") != "landed":
                fail(f"comprehensive_optimization_backlog.json {item_id} design_status must be landed")
            if item.get("implementation_status") not in {"planned", "in_progress", "done", "blocked"}:
                fail(f"comprehensive_optimization_backlog.json {item_id} implementation_status is invalid")
            if not item.get("terminal_outcome"):
                fail(f"comprehensive_optimization_backlog.json {item_id} terminal_outcome is required")
            if not isinstance(item.get("implementation_targets"), list) or not item.get("implementation_targets"):
                fail(f"comprehensive_optimization_backlog.json {item_id} implementation_targets must be non-empty")
            verification = item.get("verification")
            if not isinstance(verification, list) or not verification:
                fail(f"comprehensive_optimization_backlog.json {item_id} verification must be non-empty")
            elif not all(isinstance(cmd, str) and cmd.startswith("rtk ") for cmd in verification):
                fail(f"comprehensive_optimization_backlog.json {item_id} verification commands must start with rtk")
            implementation_evidence = item.get("implementation_evidence")
            if not isinstance(implementation_evidence, list) or not implementation_evidence:
                fail(
                    f"comprehensive_optimization_backlog.json {item_id} "
                    "implementation_evidence must be non-empty"
                )
            else:
                for evidence_path in implementation_evidence:
                    if not isinstance(evidence_path, str) or not evidence_path:
                        fail(
                            f"comprehensive_optimization_backlog.json {item_id} "
                            "implementation_evidence paths must be non-empty strings"
                        )
                        continue
                    normalized = os.path.normpath(evidence_path)
                    if os.path.isabs(evidence_path) or normalized.startswith(".."):
                        fail(
                            f"comprehensive_optimization_backlog.json {item_id} "
                            f"implementation_evidence must be repository-relative: {evidence_path}"
                        )
                    elif not os.path.exists(os.path.join(root, normalized)):
                        fail(
                            f"comprehensive_optimization_backlog.json {item_id} "
                            f"implementation_evidence is missing: {evidence_path}"
                        )
            if (
                optimization_schema_version == 2
                and item.get("implementation_status") == "blocked"
                and not str(item.get("blocking_condition", "")).strip()
            ):
                fail(
                    f"comprehensive_optimization_backlog.json {item_id} "
                    "blocked item requires blocking_condition"
                )

if os.path.isfile(adk_template_path):
    adk_template_text = read(adk_template_path)
    for token in (
        "## Structured Requirements Review",
        "Confirmed Requirement",
        "Quality Dimensions",
        "## Comprehensive Optimization Backlog",
        "Machine-readable SSOT",
        "Goal and scope control",
        "Governance correctness",
        "Performance and token cost",
        "Release and rollback clarity",
        "设计状态和实现状态",
    ):
        if token not in adk_template_text:
            fail(f"{rel(adk_template_path)} missing target-architecture optimization token: {token}")
else:
    fail(f"missing file: {rel(adk_template_path)}")

reports = []
if os.path.isdir(arch_dir):
    reports = [
        path for path in sorted(glob.glob(os.path.join(arch_dir, "*.md")))
        if "target-architecture" in os.path.basename(path)
    ]
if not reports:
    fail("reports/architecture must contain at least one target architecture report")

required_headings = [
    "## Summary",
    "## Scope",
    "## Current Architecture Map",
    "## Target Architecture",
    "## Responsibility Boundary",
    "## Architecture Operating Model",
    "## SSOT Matrix",
    "## Issue Map",
    "## Structured Requirements Review",
    "## Landing Protocol",
    "## Runtime Delivery Contract",
    "## Knowledge Promotion Contract",
    "## State Reconciliation Contract",
    "## Status Consistency Gate",
    "## Phase Roadmap",
    "## Implementation Tasks",
    "## Comprehensive Optimization Backlog",
    "## Verification Gates",
    "## Rejected Options",
    "## Evidence Index",
    "## Goal Closure State",
]

required_goal_fields = [
    "goal_statement:",
    "completion_claim:",
    "required_evidence:",
    "claimant:",
    "verifier:",
    "open_items:",
    "retry_budget:",
    "staleness_threshold:",
    "heartbeat:",
    "stop_condition:",
]


def validate_optimization_section(content, label, require_all_items):
    optimization = section(content, "## Comprehensive Optimization Backlog")
    if "| ID | Priority | Optimization Area | Terminal Outcome | Implementation Target | Verification |" not in optimization:
        fail(f"{label} Comprehensive Optimization Backlog table header is missing or malformed")
    for token in (
        "Governance correctness",
        "Performance and token cost",
        "Maintainability",
        "Extensibility",
        "Asset experience",
    ):
        if token not in optimization:
            fail(f"{label} Comprehensive Optimization Backlog missing token: {token}")
    if "manifests/comprehensive_optimization_backlog.json" not in optimization:
        fail(
            f"{label} Comprehensive Optimization Backlog must reference "
            "manifests/comprehensive_optimization_backlog.json"
        )
    if require_all_items:
        for item in optimization_items:
            for key in ("id", "priority", "optimization_area"):
                value = str(item.get(key) or "")
                if value and value not in optimization:
                    fail(
                        f"{label} Comprehensive Optimization Backlog "
                        f"missing manifest {key}: {value}"
                    )


optimization_source_checked = False
for report in reports:
    content = read(report)
    label = rel(report)
    if not content.startswith("# "):
        fail(f"{label} must start with a level-1 title")
    for heading in required_headings:
        if not has_heading(content, heading):
            fail(f"{label} missing heading: {heading}")

    for token in ("llm_agent", "agent-dev-kit", "source-to-live", "~/.codex"):
        if token not in content:
            fail(f"{label} missing boundary token: {token}")

    for token in ("source-staged", "source-committed", "dry-run-verified", "live-applied", "knowledge-promoted"):
        if token not in content:
            fail(f"{label} missing landing protocol token: {token}")

    for token in ("Approval Boundary", "Dry-run Evidence", "Apply Evidence", "Health Gate"):
        if token not in content:
            fail(f"{label} missing runtime delivery token: {token}")

    for token in ("Sanitization", "Review Owner", "Promotion Mode", "Forbidden Action"):
        if token not in content:
            fail(f"{label} missing knowledge promotion token: {token}")

    for token in ("State Claim", "Source of Truth", "Stale Condition", "Repair Action"):
        if token not in content:
            fail(f"{label} missing state reconciliation token: {token}")

    for token in ("check-current-status-consistency.sh", "IN PROGRESS", "ADK commit mismatch", "active promotion claims"):
        if token not in content:
            fail(f"{label} missing status consistency token: {token}")

    for priority in ("P0", "P1", "P2"):
        if priority not in content:
            fail(f"{label} missing implementation priority: {priority}")

    issue_map = section(content, "## Issue Map")
    if "| ID | Severity | Finding | Evidence | Action |" not in issue_map:
        fail(f"{label} Issue Map table header is missing or malformed")

    structured_requirements = section(content, "## Structured Requirements Review")
    if "| Dimension | Confirmed Requirement | Success Criteria | Non-Goal / Boundary |" not in structured_requirements:
        fail(f"{label} Structured Requirements Review table header is missing or malformed")
    for token in ("Goal", "Deliverable", "Scope", "Quality Dimensions", "Long-term Asset"):
        if token not in structured_requirements:
            fail(f"{label} Structured Requirements Review missing token: {token}")

    tasks = section(content, "## Implementation Tasks")
    if "| ID | Priority | Task | Files | Stop Condition | Verification |" not in tasks:
        fail(f"{label} Implementation Tasks table header is missing or malformed")

    is_optimization_source = bool(
        optimization_source_path
        and os.path.normpath(report) == os.path.normpath(optimization_source_path)
    )
    validate_optimization_section(content, label, is_optimization_source)
    optimization_source_checked = optimization_source_checked or is_optimization_source

    rejected = section(content, "## Rejected Options")
    if "| Option | Decision | Reason |" not in rejected:
        fail(f"{label} Rejected Options table header is missing or malformed")
    if "reject" not in rejected.lower():
        fail(f"{label} Rejected Options must include at least one reject decision")

    evidence = section(content, "## Evidence Index")
    if "| Command | Exit Code | Result Summary | Layer |" not in evidence:
        fail(f"{label} Evidence Index table header is missing or malformed")
    if not re.search(r"^\|\s*`rtk\s+", evidence, re.MULTILINE):
        fail(f"{label} Evidence Index must include at least one rtk command")
    if not re.search(r"\|\s*0\s*\|", evidence):
        fail(f"{label} Evidence Index must include at least one passing command exit code")
    if not (re.search(r"\|\s*[1-9][0-9]*\s*\|", evidence) or "before fix" in evidence.lower()):
        fail(f"{label} Evidence Index must include a negative or before-fix evidence row")

    closure = section(content, "## Goal Closure State")
    for field in required_goal_fields:
        if field not in closure:
            fail(f"{label} Goal Closure State missing field: {field}")

if optimization_source_path and not optimization_source_checked:
    source_content = read(optimization_source_path)
    validate_optimization_section(
        source_content,
        rel(optimization_source_path),
        True,
    )

product_reports = sorted(glob.glob(os.path.join(arch_dir, "*product-maturity-audit*.md")))
if not product_reports:
    fail("reports/architecture must contain a product maturity audit")
else:
    maturity_headings = (
        "## 执行结论",
        "## 产品目标与边界",
        "## 架构对账",
        "## 功能成熟度",
        "## 性能与成本",
        "## 安全与供应链",
        "## 发布与兼容",
        "## 可维护性与长期资产",
        "## 外部实践对标",
        "## 风险与未完成项",
        "## 终态判断",
        "## Evidence Index",
    )
    for report in product_reports:
        content = read(report)
        label = rel(report)
        for heading in maturity_headings:
            if not has_heading(content, heading):
                fail(f"{label} missing product maturity heading: {heading}")
        for token in (
            "manifests/product_maturity_scorecard.json",
            "manifests/product_maturity_task_pack.json",
            "field_not_verified",
            "terminal_mature",
            "source-to-live",
            "baseline/adk",
        ):
            if token not in content:
                fail(f"{label} missing maturity token: {token}")

product_scorecard = read_json(product_scorecard_path)
if product_scorecard:
    assessment_model = product_scorecard.get("assessment_model")
    if not isinstance(assessment_model, dict):
        fail("product_maturity_scorecard.json assessment_model must be an object")
    else:
        effective_level_semantics = str(assessment_model.get("effective_level", ""))
        if not effective_level_semantics:
            fail("product_maturity_scorecard.json assessment_model.effective_level is required")
        if assessment_model.get("long_term_asset_model") != "separate qualification in manifests/long_term_asset_qualification.json":
            fail("product_maturity_scorecard.json must separate long-term asset qualification from Product M5")
        semantics = assessment_model.get("status_semantics")
        if not isinstance(semantics, dict) or set(semantics) != {
            "verified",
            "verified_local",
            "partially_verified",
        }:
            fail("product_maturity_scorecard.json must define status semantics")
    dimensions = product_scorecard.get("dimensions")
    if not isinstance(dimensions, list) or len(dimensions) != 12:
        fail("product_maturity_scorecard.json must contain exactly 12 dimensions")
    else:
        expected_ids = [f"D{i:02d}" for i in range(1, 13)]
        actual_ids = [item.get("id") for item in dimensions if isinstance(item, dict)]
        if actual_ids != expected_ids:
            fail(f"product_maturity_scorecard.json dimension ids must be {expected_ids}")
        for item in dimensions:
            if item.get("level") not in {"M0", "M1", "M2", "M3", "M4", "M5"}:
                fail(f"product maturity dimension {item.get('id')} has invalid level")
            implementation_level = item.get("implementation_level")
            evidence_level = item.get("evidence_level")
            effective_level = item.get("effective_level")
            if implementation_level not in {"M0", "M1", "M2", "M3", "M4", "M5"}:
                fail(f"product maturity dimension {item.get('id')} has invalid implementation_level")
            if evidence_level not in {"M0", "M1", "M2", "M3", "M4", "M5"}:
                fail(f"product maturity dimension {item.get('id')} has invalid evidence_level")
            if (
                implementation_level in {"M0", "M1", "M2", "M3", "M4", "M5"}
                and evidence_level in {"M0", "M1", "M2", "M3", "M4", "M5"}
            ):
                expected_effective = f"M{min(int(implementation_level[1:]), int(evidence_level[1:]))}"
                if effective_level != expected_effective:
                    fail(
                        f"product maturity dimension {item.get('id')} effective_level "
                        f"must be {expected_effective}"
                    )
                if implementation_level != evidence_level and item.get("status") == "verified":
                    fail(
                        f"product maturity dimension {item.get('id')} cannot be verified "
                        "while implementation and evidence levels differ"
                    )
            if item.get("status") in {"verified_local", "partially_verified"}:
                if not isinstance(item.get("gap"), str) or not item["gap"].strip():
                    fail(
                        f"product maturity dimension {item.get('id')} must document "
                        f"the gap for status={item.get('status')}"
                    )
            if not isinstance(item.get("evidence"), list) or not item.get("evidence"):
                fail(f"product maturity dimension {item.get('id')} must have evidence")
    overall = product_scorecard.get("overall")
    if not isinstance(overall, dict):
        fail("product_maturity_scorecard.json overall must be an object")
    else:
        if overall.get("level") != "M5" or overall.get("status") != "production-qualified":
            fail("current product scorecard must declare production-qualified Product M5")
        if overall.get("terminal_mature") is not True:
            fail("current product scorecard Product M5 terminal_mature must be true")
        if overall.get("terminal_scope") != "product_maturity_v5":
            fail("current product terminal scope must remain product_maturity_v5")
        if overall.get("field_status") != "production_qualified":
            fail("current product scorecard field_status must be production_qualified")
        if overall.get("long_term_asset_status") != "qualification_pending":
            fail("Product M5 must not imply long-term asset terminal qualification")
        if overall.get("long_term_asset_contract") != "manifests/long_term_asset_qualification.json":
            fail("Product M5 must bind the canonical long-term asset qualification contract")

report_registry = read_json(report_registry_path)
current_report_path = ""
if report_registry:
    entries = report_registry.get("reports")
    if not isinstance(entries, list):
        fail("report_registry.json reports must be an array")
    else:
        current = [item for item in entries if isinstance(item, dict) and item.get("status") == "current"]
        if len(current) != 1:
            fail("report_registry.json must declare exactly one current architecture report")
        else:
            current_report_path = str(current[0].get("path") or "")
            if (
                optimization_manifest
                and optimization_manifest.get("schema_version") == 2
                and optimization_manifest.get("rules", {}).get("current_report_is_registry_driven") is True
                and current_report_path != optimization_source_report
            ):
                fail(
                    "report_registry.json current report must match "
                    "comprehensive_optimization_backlog.json source_report"
                )
        for item in entries:
            if not isinstance(item, dict):
                continue
            registry_path = str(item.get("path") or "")
            normalized_registry_path = os.path.normpath(registry_path)
            if (
                not registry_path
                or os.path.isabs(registry_path)
                or normalized_registry_path.startswith("..")
            ):
                fail(
                    "report registry path must be repository-relative: "
                    f"{registry_path or '<missing>'}"
                )
                continue
            if normalized_registry_path.split(os.sep)[:2] != ["reports", "architecture"]:
                fail(f"report registry path must stay under reports/architecture: {registry_path}")
                continue
            report_path = os.path.join(root, normalized_registry_path)
            if not os.path.isfile(report_path):
                fail(f"report registry path missing: {registry_path}")

status = "pass" if not failures else "fail"
if summary_json:
    print(json.dumps({
        "status": status,
        "reports": len(reports) + len(product_reports),
        "backlog_items": len(optimization_items),
        "current_report": current_report_path,
        "failures": failures,
    }, ensure_ascii=False, separators=(",", ":")))
else:
    if failures:
        for item in failures:
            print(f"[FAIL] {item}", file=sys.stderr)
    else:
        print(f"[PASS] architecture reports ready: reports={len(reports) + len(product_reports)}")

if failures:
    sys.exit(1)
PY
