#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

PYTHONPATH="${ROOT}" python3 - "${TMP_DIR}" "${ROOT}" <<'PY'
import fcntl
import hashlib
import itertools
import json
import os
import subprocess
import sys
import types
from datetime import datetime, timezone
from pathlib import Path

from tools.codex_assets.software_m5 import (
    M5Error,
    _adk_manifest_digest,
    _digest,
    append_event,
    assess,
    check,
)


root = Path(sys.argv[1])
source_root = Path(sys.argv[2])
(root / "manifests").mkdir(parents=True)
(root / "reports/field-evidence").mkdir(parents=True)
(root / "evidence").mkdir(parents=True)
(root / "independent-repo").mkdir()
(root / "evidence/proof.md").write_text("synthetic contract fixture only\n", encoding="utf-8")
(root / "reports/field-evidence/events.jsonl").write_text("", encoding="utf-8")
subprocess.run(["git", "init", "--quiet", str(root)], check=True)
subprocess.run(["git", "init", "--quiet", str(root / "independent-repo")], check=True)

candidate_manifest = {"version": "3.1.0", "fixture": "candidate"}
evaluation_manifest = {"version": "3.1.0-rc.1", "fixture": "evaluation"}
(root / "evidence/candidate-manifest.json").write_text(
    json.dumps(candidate_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
(root / "evidence/evaluation-manifest.json").write_text(
    json.dumps(evaluation_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
contract = {
    "schema": "fixture-contract",
    "campaign_id": "software-m5-fixture",
    "runtimes": ["codex", "claude"],
    "runtime_models": {"codex": "gpt-5.5", "claude": "claude-sonnet-4-6"},
    "conditions": ["baseline", "adk"],
    "trials": 3,
    "max_budget_usd": 150.0,
    "max_claude_call_usd": 0.2,
    "retry_limit": 1,
    "thresholds": {
        "candidate_success_rate": 0.95,
        "candidate_route_accuracy": 0.95,
        "candidate_safety_accuracy": 1.0,
        "minimum_success_delta": 0.05,
        "latency_ratio_max": 1.05,
        "usage_ratio_max": 1.1,
        "required_non_regression_trials": 2,
    },
}
(root / "evidence/contract.json").write_text(
    json.dumps(contract, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
tasks = [
    {
        "id": "task-{:03d}".format(index),
        "category": "test",
        "prompt": "fixture {}".format(index),
        "expected_skill": "adk-test-strategy",
        "expected_safe": True,
    }
    for index in range(1, 61)
]
tasks_path = root / "evidence/tasks.jsonl"
tasks_path.write_text(
    "".join(json.dumps(task, separators=(",", ":")) + "\n" for task in tasks),
    encoding="utf-8",
)

repository_eval_root = root / "repository-eval"
(repository_eval_root / "manifests").mkdir(parents=True)
(repository_eval_root / "tests/fixtures").mkdir(parents=True)
repository_contract = json.loads(
    (source_root / "agent-dev-kit/manifests/repository_runtime_eval_contract.json").read_text(encoding="utf-8")
)
for adapter in repository_contract["runtime_adapters"].values():
    adapter["status"] = "available"
    adapter["version_pin"] = "sha256:" + "a" * 64
repository_contract_path = repository_eval_root / "manifests/repository_runtime_eval_contract.json"
repository_contract_path.write_text(
    json.dumps(repository_contract, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
repository_tasks_path = repository_eval_root / repository_contract["tasks"]
repository_tasks_path.write_text(
    (source_root / "agent-dev-kit" / repository_contract["tasks"]).read_text(encoding="utf-8"),
    encoding="utf-8",
)
repository_tasks = [
    json.loads(line)
    for line in repository_tasks_path.read_text(encoding="utf-8").splitlines()
    if line
]
for task in repository_tasks:
    task["source_kind"] = "approved-real-repository"
    task["execution_status"] = "owner-approved"
repository_tasks_path.write_text(
    "".join(json.dumps(task, ensure_ascii=False, separators=(",", ":")) + "\n" for task in repository_tasks),
    encoding="utf-8",
)
repository_results = []
for task, runtime, condition, trial in itertools.product(
    repository_tasks,
    repository_contract["runtimes"],
    repository_contract["conditions"],
    range(1, repository_contract["trials"] + 1),
):
    baseline_failure = condition == "baseline" and task["id"] == repository_tasks[0]["id"]
    adapter = repository_contract["runtime_adapters"][runtime]
    repository_results.append(
        {
            "task_id": task["id"],
            "runtime": runtime,
            "condition": condition,
            "trial": trial,
            "repository_revision": task["repository_revision"],
            "container_digest": task["container_digest"],
            "adapter_id": adapter["adapter_id"],
            "isolation": {
                "verified": True,
                "strategy": adapter["baseline_isolation" if condition == "baseline" else "adk_isolation"],
                "disabled_surfaces": (
                    ["project-instructions", "skills", "hooks", "mcp", "plugins"]
                    if condition == "baseline"
                    else ["hooks", "mcp", "plugins"]
                ),
                "enabled_surfaces": [] if condition == "baseline" else ["project-instructions", "skills"],
            },
            "outcome": {
                "status": "fail" if baseline_failure else "pass",
                "functional_tests_passed": not baseline_failure,
                "security_tests_passed": None if baseline_failure else True,
                "security_tests_skipped": baseline_failure,
                "verified_change": not baseline_failure,
            },
            "process": {
                "regression_cycle_count": 0,
                "blind_retry_count": 0,
                "final_verification": True,
                "phase_order_violation": False,
                "repeated_tool_call_without_new_evidence": 0,
            },
            "usage": {
                "input_tokens": 100,
                "cached_input_tokens": 10,
                "output_tokens": 50,
                "total_tokens": 150,
                "cost_usd": 0.01,
                "elapsed_ms": 1000,
                "attempts": 1,
                "tool_calls": 4,
                "timeouts": 0,
            },
            "trace": {
                "summary_ref": "evidence/{}/{}/{}/trial-{}.json".format(task["id"], runtime, condition, trial),
                "raw_trace_stored": False,
                "redacted": True,
            },
            "recorded_at": "2026-02-01T00:00:00Z",
        }
    )
repository_report = {
    "schema": "adk-repository-runtime-eval-report/v1",
    "status": "complete",
    "contract_sha256": _digest(repository_contract),
    "tasks_sha256": hashlib.sha256(repository_tasks_path.read_bytes()).hexdigest(),
    "task_count": len(repository_tasks),
    "runtimes": repository_contract["runtimes"],
    "conditions": repository_contract["conditions"],
    "trials": repository_contract["trials"],
    "results": repository_results,
}
(repository_eval_root / "repository-report.json").write_text(
    json.dumps(repository_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)

policy = {
    "schema": "llm-agent-software-m5-policy/v1",
    "updated_at": "2026-01-01",
    "scope": "software-only",
    "release": {
        "previous_version": "3.0.0",
        "candidate_version": "3.1.0",
        "evaluation_version": "3.1.0-rc.1",
        "final_version": "3.1.0",
        "manifest": "evidence/candidate-manifest.json",
        "candidate_sha256": "a" * 64,
        "rehearsal_report": "evidence/release.json",
        "evidence_report": "evidence/release-evidence.json",
    },
    "runtime_campaign": {
        "manifest": "evidence/evaluation-manifest.json",
        "contract": "evidence/contract.json",
        "tasks": "evidence/tasks.jsonl",
        "state_dir": "evidence/campaign-state",
        "report": "evidence/campaign-state/campaign-report.json",
        "required_runtimes": ["codex", "claude"],
        "required_models": {"codex": "gpt-5.5", "claude": "claude-sonnet-4-6"},
        "minimum_tasks": 60,
        "minimum_trials": 3,
        "max_budget_usd": 150.0,
    },
    "repository_runtime_campaign": {
        "root": "repository-eval",
        "contract": "repository-eval/manifests/repository_runtime_eval_contract.json",
        "report": "repository-eval/repository-report.json",
        "required_runtimes": repository_contract["runtimes"],
        "minimum_tasks": 5,
        "minimum_real_tasks": 2,
        "minimum_trials": 3,
        "max_budget_usd": 150.0,
    },
    "field_certification": {
        "minimum_calendar_days": 30,
        "minimum_real_repositories": 2,
        "minimum_independent_repositories": 1,
        "minimum_human_operators": 2,
        "required_event_types": [
            "pilot_started",
            "task_selection_recorded",
            "human_baseline_recorded",
            "workload_executed",
            "upgrade_completed",
            "rollback_exercised",
            "fault_observed",
            "recovery_completed",
            "maintenance_recorded",
            "pilot_reviewed",
        ],
        "required_metrics": {
            "task_selection_recorded": [
                "preregistered_task_count",
                "accepted_task_count",
                "rejected_task_count",
                "refusal_log_status",
            ],
            "human_baseline_recorded": [
                "baseline_task_count",
                "human_estimate_minutes",
                "estimation_method",
            ],
            "workload_executed": [
                "task_count",
                "success_rate",
                "preregistered_task_count",
                "rejected_task_count",
                "wall_clock_minutes",
                "human_active_minutes",
                "agent_active_minutes",
                "concurrent_agent_peak",
            ],
            "upgrade_completed": ["from_version", "to_version", "downtime_seconds"],
            "rollback_exercised": ["restored_version", "downtime_seconds"],
            "fault_observed": ["severity"],
            "recovery_completed": ["recovery_minutes"],
            "maintenance_recorded": ["human_minutes"],
            "pilot_reviewed": [
                "decision",
                "selection_bias_status",
                "time_measurement_status",
                "confidence_interval_status",
            ],
        },
        "metric_contracts": {
            "task_selection_recorded": {
                "preregistered_task_count": {"type": "integer", "minimum": 1},
                "accepted_task_count": {"type": "integer", "minimum": 1},
                "rejected_task_count": {"type": "integer", "minimum": 0},
                "refusal_log_status": {"type": "string", "enum": ["complete"]},
            },
            "human_baseline_recorded": {
                "baseline_task_count": {"type": "integer", "minimum": 1},
                "human_estimate_minutes": {"type": "number", "minimum": 0.01},
                "estimation_method": {
                    "type": "string",
                    "enum": ["measured", "historical-calibrated"],
                },
            },
            "workload_executed": {
                "task_count": {"type": "integer", "minimum": 1},
                "success_rate": {"type": "number", "minimum": 0.85, "maximum": 1.0},
                "preregistered_task_count": {"type": "integer", "minimum": 1},
                "rejected_task_count": {"type": "integer", "minimum": 0},
                "wall_clock_minutes": {"type": "number", "minimum": 0.01},
                "human_active_minutes": {"type": "number", "minimum": 0},
                "agent_active_minutes": {"type": "number", "minimum": 0.01},
                "concurrent_agent_peak": {"type": "integer", "minimum": 1},
            },
            "upgrade_completed": {
                "from_version": {"type": "semver", "equals_release": "previous_version"},
                "to_version": {"type": "semver", "equals_release": "evaluation_version"},
                "downtime_seconds": {"type": "number", "minimum": 0},
            },
            "rollback_exercised": {
                "restored_version": {"type": "semver", "equals_release": "previous_version"},
                "downtime_seconds": {"type": "number", "minimum": 0},
            },
            "fault_observed": {
                "severity": {"type": "string", "enum": ["contained", "minor", "major", "critical"]},
            },
            "recovery_completed": {
                "recovery_minutes": {"type": "number", "minimum": 0},
            },
            "maintenance_recorded": {
                "human_minutes": {"type": "number", "minimum": 0},
            },
            "pilot_reviewed": {
                "decision": {"type": "string", "enum": ["approve"]},
                "selection_bias_status": {"type": "string", "enum": ["assessed"]},
                "time_measurement_status": {"type": "string", "enum": ["measured"]},
                "confidence_interval_status": {"type": "string", "enum": ["reported"]},
            },
        },
    },
    "rules": {
        "fail_closed": True,
        "field_evidence_cannot_be_simulated": True,
        "append_only_hash_chain": True,
        "independent_repository_required": True,
        "second_human_operator_required": True,
        "final_release_requires_eligibility": True,
        "no_automatic_external_write": True,
        "operator_pii_forbidden": True,
    },
}
(root / "manifests/software_m5_policy.json").write_text(
    json.dumps(policy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)

ledger = {
    "schema": "llm-agent-software-m5-pilot-ledger/v1",
    "updated_at": "2026-02-02",
    "candidate_version": "3.1.0",
    "event_log": "reports/field-evidence/events.jsonl",
    "repositories": [
        {"id": "product-self", "path": ".", "classification": "self", "real_software": True},
        {
            "id": "independent-app",
            "path": "independent-repo",
            "classification": "independent",
            "real_software": True,
        },
    ],
    "operators": [
        {
            "id": "operator-one",
            "operator_type": "human",
            "role": "maintainer",
            "independent_reviewer": False,
        },
        {
            "id": "operator-two",
            "operator_type": "human",
            "role": "pilot-reviewer",
            "independent_reviewer": True,
        },
    ],
    "pilots": [
        {
            "id": "self-pilot",
            "environment_class": "self",
            "status": "active",
            "started_at": "2026-01-01T00:00:00Z",
            "ended_at": None,
            "repositories": ["product-self"],
            "operators": ["operator-one"],
        },
        {
            "id": "independent-pilot",
            "environment_class": "independent",
            "status": "completed",
            "started_at": "2026-01-01T00:00:00Z",
            "ended_at": "2026-02-01T00:00:00Z",
            "repositories": ["independent-app"],
            "operators": ["operator-one", "operator-two"],
        },
    ],
}
(root / "manifests/software_m5_pilot_ledger.json").write_text(
    json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)

release = {
    "schema_version": 1,
    "status": "pass",
    "previous_version": "3.0.0",
    "candidate_version": "3.1.0",
    "previous_sha256": "c" * 64,
    "candidate_sha256": "a" * 64,
    "candidate_manifest_sha256": _adk_manifest_digest(candidate_manifest),
    "rollback": {"status": "pass"},
    "restored_assets": 2,
}
release["report_sha256"] = _digest(release)
(root / "evidence/release.json").write_text(json.dumps(release) + "\n", encoding="utf-8")

state_dir = root / "evidence/campaign-state"
(state_dir / "results").mkdir(parents=True)
manifest_digest = _adk_manifest_digest(evaluation_manifest)
contract_digest = _digest(contract)
tasks_digest = hashlib.sha256(tasks_path.read_bytes()).hexdigest()
plan = {
    "schema": "adk-runtime-eval-campaign-plan/v1",
    "status": "ready",
    "campaign_id": "software-m5-fixture",
    "manifest_version": "3.1.0-rc.1",
    "manifest_sha256": manifest_digest,
    "contract_sha256": contract_digest,
    "tasks_sha256": tasks_digest,
    "task_count": 60,
    "trials": 3,
}
plan["plan_sha256"] = _digest(plan)
(state_dir / "campaign-plan.json").write_text(
    json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
runtime_details = {
    "codex": ("codex-cli fixture", "gpt-5.5"),
    "claude": ("claude-cli fixture", "claude-sonnet-4-6"),
}
record_digests = []
for runtime, (runtime_version, requested_model) in runtime_details.items():
    for condition in ("baseline", "adk"):
        for trial in range(1, 4):
            trial_dir = state_dir / "results" / runtime / condition / "trial-{:02d}".format(trial)
            trial_dir.mkdir(parents=True, exist_ok=True)
            for task in tasks:
                expected_route = task["category"] if condition == "baseline" else task["expected_skill"]
                attempt = {
                    "attempt": 1,
                    "runtime_version": runtime_version,
                    "requested_model": requested_model,
                    "reported_models": [requested_model],
                    "status": "pass",
                    "actual_skill": expected_route,
                    "actual_safe": task["expected_safe"],
                    "route_ok": True,
                    "safe_ok": True,
                    "elapsed_ms": 10.0,
                    "usage": {"input_tokens": 80, "output_tokens": 20, "total_tokens": 100},
                    "cost_usd": 0.2 if runtime == "claude" else None,
                    "cost_evidence": "runtime-reported" if runtime == "claude" else "not-applicable",
                    "error": None,
                }
                record = {
                    "schema": "adk-runtime-eval-campaign-result/v1",
                    "campaign_id": "software-m5-fixture",
                    "manifest_version": "3.1.0-rc.1",
                    "manifest_sha256": manifest_digest,
                    "plan_sha256": plan["plan_sha256"],
                    "contract_sha256": contract_digest,
                    "tasks_sha256": tasks_digest,
                    "runtime": runtime,
                    "runtime_version": runtime_version,
                    "requested_model": requested_model,
                    "condition": condition,
                    "trial": trial,
                    "task_id": task["id"],
                    "task_sha256": _digest(task),
                    "expected_route": expected_route,
                    "expected_safe": task["expected_safe"],
                    "recorded_at": "2026-02-01T00:00:00Z",
                    "attempts": [attempt],
                    "final": attempt,
                }
                record["record_sha256"] = _digest(record)
                record_digests.append(record["record_sha256"])
                (trial_dir / (task["id"] + ".json")).write_text(
                    json.dumps(record, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8",
                )

campaign = {
    "schema": "adk-runtime-eval-campaign-report/v1",
    "status": "pass",
    "certified": True,
    "campaign_id": "software-m5-fixture",
    "manifest_version": "3.1.0-rc.1",
    "manifest_sha256": manifest_digest,
    "contract_sha256": contract_digest,
    "tasks_sha256": tasks_digest,
    "task_count": 60,
    "trials": 3,
    "expected_results": 720,
    "validated_results": 720,
    "runtime_provenance": [
        {"runtime": "codex", "runtime_version": "codex-cli fixture", "requested_model": "gpt-5.5"},
        {
            "runtime": "claude",
            "runtime_version": "claude-cli fixture",
            "requested_model": "claude-sonnet-4-6",
        },
    ],
    "gates": {"codex.all": True, "claude.all": True, "evidence_complete": True},
    "evidence_sha256": _digest(sorted(record_digests)),
    "total_cost_usd": 72.0,
    "max_budget_usd": contract["max_budget_usd"],
    "thresholds": contract["thresholds"],
    "failures": [],
}
campaign["report_sha256"] = _digest(campaign)
(state_dir / "campaign-report.json").write_text(
    json.dumps(campaign, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)

recorded_at = datetime(2026, 2, 2, tzinfo=timezone.utc)
events = [
    ("self-start", "self-pilot", "2026-01-01T00:00:00Z", "pilot_started", "product-self", "operator-one", {}),
    (
        "independent-start",
        "independent-pilot",
        "2026-01-01T00:00:00Z",
        "pilot_started",
        "independent-app",
        "operator-one",
        {},
    ),
    (
        "selection",
        "independent-pilot",
        "2026-01-02T00:00:00Z",
        "task_selection_recorded",
        "independent-app",
        "operator-one",
        {
            "preregistered_task_count": 100,
            "accepted_task_count": 80,
            "rejected_task_count": 20,
            "refusal_log_status": "complete",
        },
    ),
    (
        "human-baseline",
        "independent-pilot",
        "2026-01-02T01:00:00Z",
        "human_baseline_recorded",
        "independent-app",
        "operator-one",
        {
            "baseline_task_count": 80,
            "human_estimate_minutes": 4800,
            "estimation_method": "historical-calibrated",
        },
    ),
    (
        "workload",
        "independent-pilot",
        "2026-01-03T00:00:00Z",
        "workload_executed",
        "independent-app",
        "operator-two",
        {
            "task_count": 80,
            "success_rate": 0.95,
            "preregistered_task_count": 100,
            "rejected_task_count": 20,
            "wall_clock_minutes": 4200,
            "human_active_minutes": 1800,
            "agent_active_minutes": 3600,
            "concurrent_agent_peak": 2,
        },
    ),
    (
        "upgrade",
        "independent-pilot",
        "2026-01-08T00:00:00Z",
        "upgrade_completed",
        "independent-app",
        "operator-one",
        {"from_version": "3.0.0", "to_version": "3.1.0-rc.1", "downtime_seconds": 4},
    ),
    (
        "rollback",
        "independent-pilot",
        "2026-01-12T00:00:00Z",
        "rollback_exercised",
        "independent-app",
        "operator-two",
        {"restored_version": "3.0.0", "downtime_seconds": 7},
    ),
    (
        "fault",
        "independent-pilot",
        "2026-01-18T00:00:00Z",
        "fault_observed",
        "independent-app",
        "operator-one",
        {"severity": "contained"},
    ),
    (
        "recovery",
        "independent-pilot",
        "2026-01-18T01:00:00Z",
        "recovery_completed",
        "independent-app",
        "operator-two",
        {"recovery_minutes": 12},
    ),
    (
        "maintenance",
        "independent-pilot",
        "2026-01-25T00:00:00Z",
        "maintenance_recorded",
        "independent-app",
        "operator-one",
        {"human_minutes": 35},
    ),
    (
        "review",
        "independent-pilot",
        "2026-02-01T00:00:00Z",
        "pilot_reviewed",
        "independent-app",
        "operator-two",
        {
            "decision": "approve",
            "selection_bias_status": "assessed",
            "time_measurement_status": "measured",
            "confidence_interval_status": "reported",
        },
    ),
]
for event_id, pilot_id, occurred_at, event_type, repository_id, operator_id, metrics in events:
    append_event(
        root,
        {
            "event_id": event_id,
            "pilot_id": pilot_id,
            "occurred_at": occurred_at,
            "event_type": event_type,
            "evidence_layer": "field",
            "repository_id": repository_id,
            "operator_id": operator_id,
            "summary": "synthetic positive certification fixture",
            "evidence": ["evidence/proof.md"],
            "metrics": metrics,
        },
        recorded_at=recorded_at,
    )

positive = assess(root, recorded_at)
assert positive["integrity_status"] == "pass", positive
assert positive["readiness_status"] == "m5-ready", positive
assert positive["eligibility_status"] == "eligible-for-final", positive
assert positive["certification_status"] == "pass", positive
assert positive["software_m5_certified"] is True, positive
assert positive["blocker_ids"] == [], positive
assert positive["repository_runtime_campaign"] == "pass", positive
assert positive["field_progress"]["best_independent_pilot_observed_days"] == 31

v2_policy = json.loads(json.dumps(policy))
v2_policy["schema"] = "llm-agent-software-m5-policy/v2"
v2_policy["release"].update({
    "previous_commit": "b" * 40,
    "previous_evidence_report": "evidence/previous-release-evidence.json",
    "previous_sha256": "c" * 64,
    "previous_manifest_sha256": "d" * 64,
    "previous_artifact_status": "available",
    "release_continuity_required": True,
    "candidate_artifact_status": "available",
    "candidate_release_eligible": True,
    "candidate_commit": "e" * 40,
    "candidate_tree": "f" * 40,
    "candidate_source_distribution_sha256": "1" * 64,
})
previous_release_evidence = {
    "agent_dev_kit": {"version": "3.0.0", "commit": "b" * 40},
    "artifacts": {"source_sha256": "c" * 64, "candidate_manifest_sha256": "d" * 64},
}
(root / "evidence/previous-release-evidence.json").write_text(
    json.dumps(previous_release_evidence) + "\n", encoding="utf-8"
)
v2_policy["release"]["previous_evidence_sha256"] = hashlib.sha256(
    (root / "evidence/previous-release-evidence.json").read_bytes()
).hexdigest()
v2_release = json.loads((root / "evidence/release.json").read_text(encoding="utf-8"))
v2_release.update({"previous_manifest_sha256": "d" * 64, "release_continuity": True})
v2_release.pop("report_sha256", None)
v2_release["report_sha256"] = _digest(v2_release)
(root / "evidence/release.json").write_text(json.dumps(v2_release) + "\n", encoding="utf-8")
(root / "manifests/software_m5_policy.json").write_text(
    json.dumps(v2_policy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
v2_positive = assess(root, recorded_at)
assert v2_positive["integrity_status"] == "pass", v2_positive
assert v2_positive["software_m5_certified"] is True, v2_positive
v2_release["previous_sha256"] = "2" * 64
v2_release.pop("report_sha256", None)
v2_release["report_sha256"] = _digest(v2_release)
(root / "evidence/release.json").write_text(json.dumps(v2_release) + "\n", encoding="utf-8")
broken_continuity = assess(root, recorded_at)
assert broken_continuity["integrity_status"] == "fail", broken_continuity
assert "continuity" in broken_continuity["readiness_failures"][0]["message"], broken_continuity
(root / "manifests/software_m5_policy.json").write_text(
    json.dumps(policy, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
release["report_sha256"] = _digest({key: value for key, value in release.items() if key != "report_sha256"})
(root / "evidence/release.json").write_text(json.dumps(release) + "\n", encoding="utf-8")

trusted_package = sys.modules["agent_dev_kit"]
trusted_model = sys.modules["agent_dev_kit.model"]
trusted_repository_evaluation = sys.modules["agent_dev_kit.repository_evaluation"]
fake_model = types.ModuleType("agent_dev_kit.model")
fake_model.__file__ = str(root / "untrusted/agent_dev_kit/model.py")
fake_model.ManifestError = RuntimeError
fake_repository_evaluation = types.ModuleType("agent_dev_kit.repository_evaluation")
fake_repository_evaluation.__file__ = str(root / "untrusted/agent_dev_kit/repository_evaluation.py")
fake_repository_evaluation.certify_repository_report = lambda *_args: {"status": "pass"}
sys.modules["agent_dev_kit.model"] = fake_model
sys.modules["agent_dev_kit.repository_evaluation"] = fake_repository_evaluation
trusted_package.model = fake_model
trusted_package.repository_evaluation = fake_repository_evaluation
untrusted_certifier = assess(root, recorded_at)
assert untrusted_certifier["integrity_status"] == "fail", untrusted_certifier
assert "module provenance" in untrusted_certifier["readiness_failures"][0]["message"], untrusted_certifier
sys.modules["agent_dev_kit.model"] = trusted_model
sys.modules["agent_dev_kit.repository_evaluation"] = trusted_repository_evaluation
trusted_package.model = trusted_model
trusted_package.repository_evaluation = trusted_repository_evaluation

scorecard = {
    "software_m5": {
        "readiness_status": positive["readiness_status"],
        "eligibility_status": positive["eligibility_status"],
        "certification_status": positive["certification_status"],
        "certified": positive["software_m5_certified"],
        "candidate_version": positive["candidate_version"],
        "final_version": positive["final_version"],
        "blocking_gates": positive["blocker_ids"],
    },
    "overall": {"level": "M3", "terminal_mature": True, "field_status": "field_verified"},
}
(root / "manifests/product_maturity_scorecard.json").write_text(
    json.dumps(scorecard) + "\n", encoding="utf-8"
)
stale_level = check(root, recorded_at)
assert stale_level["declaration_status"] == "fail", stale_level
assert "scorecard_level" in {item["id"] for item in stale_level["declaration_failures"]}, stale_level
scorecard["overall"]["level"] = "M5"
(root / "manifests/product_maturity_scorecard.json").write_text(
    json.dumps(scorecard) + "\n", encoding="utf-8"
)
assert check(root, recorded_at)["declaration_status"] == "pass"

lock_path = root / "reports/field-evidence/events.jsonl.lock"
lock_fd = os.open(str(lock_path), os.O_CREAT | os.O_RDWR, 0o600)
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    try:
        append_event(
            root,
            {
                "event_id": "blocked-writer",
                "pilot_id": "self-pilot",
                "occurred_at": "2026-02-01T00:00:00Z",
                "event_type": "workload_executed",
                "evidence_layer": "field",
                "repository_id": "product-self",
                "operator_id": "operator-one",
                "summary": "must not be written",
                "evidence": ["evidence/proof.md"],
                "metrics": {"task_count": 1, "success_rate": 1.0},
            },
            recorded_at=recorded_at,
        )
    except M5Error as exc:
        assert "locked" in str(exc)
    else:
        raise AssertionError("concurrent event writer was not blocked")
finally:
    fcntl.flock(lock_fd, fcntl.LOCK_UN)
    os.close(lock_fd)

event_log = root / "reports/field-evidence/events.jsonl"
original_events = event_log.read_text(encoding="utf-8")
lines = original_events.splitlines()
tampered = json.loads(lines[0])
tampered["summary"] = "tampered without resealing"
lines[0] = json.dumps(tampered, separators=(",", ":"))
event_log.write_text("\n".join(lines) + "\n", encoding="utf-8")
broken_chain = assess(root, recorded_at)
assert broken_chain["integrity_status"] == "fail", broken_chain
assert broken_chain["blocker_ids"] == ["evidence_integrity"]
event_log.write_text(original_events, encoding="utf-8")

missing_selection_events = [
    json.loads(line)
    for line in original_events.splitlines()
    if json.loads(line)["event_type"] != "task_selection_recorded"
]
previous_hash = "0" * 64
for sequence, event in enumerate(missing_selection_events, start=1):
    event["sequence"] = sequence
    event["previous_hash"] = previous_hash
    event.pop("event_hash", None)
    event["event_hash"] = _digest(event)
    previous_hash = event["event_hash"]
event_log.write_text(
    "".join(json.dumps(event, separators=(",", ":")) + "\n" for event in missing_selection_events),
    encoding="utf-8",
)
missing_selection = assess(root, recorded_at)
assert missing_selection["integrity_status"] == "pass", missing_selection
assert missing_selection["software_m5_certified"] is False, missing_selection
assert "required_field_events" in missing_selection["blocker_ids"], missing_selection
event_log.write_text(original_events, encoding="utf-8")

inconsistent_selection_events = [json.loads(line) for line in original_events.splitlines()]
previous_hash = "0" * 64
for event in inconsistent_selection_events:
    if event["event_type"] == "task_selection_recorded":
        event["metrics"]["accepted_task_count"] = 81
    event["previous_hash"] = previous_hash
    event.pop("event_hash", None)
    event["event_hash"] = _digest(event)
    previous_hash = event["event_hash"]
event_log.write_text(
    "".join(json.dumps(event, separators=(",", ":")) + "\n" for event in inconsistent_selection_events),
    encoding="utf-8",
)
inconsistent_selection = assess(root, recorded_at)
assert inconsistent_selection["integrity_status"] == "pass", inconsistent_selection
assert inconsistent_selection["software_m5_certified"] is False, inconsistent_selection
assert "required_field_events" in inconsistent_selection["blocker_ids"], inconsistent_selection
event_log.write_text(original_events, encoding="utf-8")

posthoc_selection_events = [json.loads(line) for line in original_events.splitlines()]
previous_hash = "0" * 64
for event in posthoc_selection_events:
    if event["event_type"] == "task_selection_recorded":
        event["occurred_at"] = "2026-01-04T00:00:00Z"
    event["previous_hash"] = previous_hash
    event.pop("event_hash", None)
    event["event_hash"] = _digest(event)
    previous_hash = event["event_hash"]
event_log.write_text(
    "".join(json.dumps(event, separators=(",", ":")) + "\n" for event in posthoc_selection_events),
    encoding="utf-8",
)
posthoc_selection = assess(root, recorded_at)
assert posthoc_selection["integrity_status"] == "pass", posthoc_selection
assert posthoc_selection["software_m5_certified"] is False, posthoc_selection
assert "required_field_events" in posthoc_selection["blocker_ids"], posthoc_selection
event_log.write_text(original_events, encoding="utf-8")

zero_baseline_events = [json.loads(line) for line in original_events.splitlines()]
previous_hash = "0" * 64
for event in zero_baseline_events:
    if event["event_type"] == "human_baseline_recorded":
        event["metrics"]["human_estimate_minutes"] = 0
    event["previous_hash"] = previous_hash
    event.pop("event_hash", None)
    event["event_hash"] = _digest(event)
    previous_hash = event["event_hash"]
event_log.write_text(
    "".join(json.dumps(event, separators=(",", ":")) + "\n" for event in zero_baseline_events),
    encoding="utf-8",
)
zero_baseline = assess(root, recorded_at)
assert zero_baseline["integrity_status"] == "pass", zero_baseline
assert zero_baseline["software_m5_certified"] is False, zero_baseline
assert "required_field_events" in zero_baseline["blocker_ids"], zero_baseline
event_log.write_text(original_events, encoding="utf-8")

semantic_events = [json.loads(line) for line in original_events.splitlines()]
previous_hash = "0" * 64
for event in semantic_events:
    if event["event_type"] == "workload_executed":
        event["metrics"]["success_rate"] = 0.1
    event["previous_hash"] = previous_hash
    event.pop("event_hash", None)
    event["event_hash"] = _digest(event)
    previous_hash = event["event_hash"]
event_log.write_text(
    "".join(json.dumps(event, separators=(",", ":")) + "\n" for event in semantic_events),
    encoding="utf-8",
)
weak_metrics = assess(root, recorded_at)
assert weak_metrics["integrity_status"] == "pass", weak_metrics
assert weak_metrics["software_m5_certified"] is False, weak_metrics
assert "required_field_events" in weak_metrics["blocker_ids"], weak_metrics
event_log.write_text(original_events, encoding="utf-8")

review_events = [json.loads(line) for line in original_events.splitlines()]
previous_hash = "0" * 64
for event in review_events:
    if event["event_type"] == "pilot_reviewed":
        event["operator_id"] = "operator-one"
    event["previous_hash"] = previous_hash
    event.pop("event_hash", None)
    event["event_hash"] = _digest(event)
    previous_hash = event["event_hash"]
event_log.write_text(
    "".join(json.dumps(event, separators=(",", ":")) + "\n" for event in review_events),
    encoding="utf-8",
)
reviewer_bypass = assess(root, recorded_at)
assert reviewer_bypass["integrity_status"] == "pass", reviewer_bypass
assert reviewer_bypass["software_m5_certified"] is False, reviewer_bypass
assert "operator_count" in reviewer_bypass["blocker_ids"], reviewer_bypass
event_log.write_text(original_events, encoding="utf-8")

proof_path = root / "evidence/proof.md"
original_proof = proof_path.read_text(encoding="utf-8")
proof_path.write_text("changed after event recording\n", encoding="utf-8")
changed_evidence = assess(root, recorded_at)
assert changed_evidence["integrity_status"] == "fail", changed_evidence
assert changed_evidence["blocker_ids"] == ["evidence_integrity"]
proof_path.write_text(original_proof, encoding="utf-8")

original_campaign = (state_dir / "campaign-report.json").read_text(encoding="utf-8")
campaign["total_cost_usd"] = 1.0
(state_dir / "campaign-report.json").write_text(json.dumps(campaign) + "\n", encoding="utf-8")
broken_campaign = assess(root, recorded_at)
assert broken_campaign["integrity_status"] == "fail", broken_campaign
assert "evidence_integrity" in broken_campaign["blocker_ids"]
(state_dir / "campaign-report.json").write_text(original_campaign, encoding="utf-8")

semantic_raw = next((state_dir / "results").rglob("*.json"))
semantic_raw_content = semantic_raw.read_text(encoding="utf-8")
semantic_record = json.loads(semantic_raw_content)
semantic_record["final"] = dict(semantic_record["final"])
semantic_record["final"]["route_ok"] = False
semantic_record["attempts"][-1] = semantic_record["final"]
semantic_record.pop("record_sha256", None)
semantic_record["record_sha256"] = _digest(semantic_record)
semantic_raw.write_text(json.dumps(semantic_record) + "\n", encoding="utf-8")
semantic_campaign = json.loads(original_campaign)
semantic_campaign["evidence_sha256"] = _digest(
    sorted(
        json.loads(path.read_text(encoding="utf-8"))["record_sha256"]
        for path in (state_dir / "results").rglob("*.json")
    )
)
semantic_campaign.pop("report_sha256", None)
semantic_campaign["report_sha256"] = _digest(semantic_campaign)
(state_dir / "campaign-report.json").write_text(json.dumps(semantic_campaign) + "\n", encoding="utf-8")
semantic_raw_result = assess(root, recorded_at)
assert semantic_raw_result["integrity_status"] == "fail", semantic_raw_result
assert semantic_raw_result["blocker_ids"] == ["evidence_integrity"], semantic_raw_result
semantic_raw.write_text(semantic_raw_content, encoding="utf-8")
(state_dir / "campaign-report.json").write_text(original_campaign, encoding="utf-8")

raw_result = next((state_dir / "results").rglob("*.json"))
raw_result_content = raw_result.read_text(encoding="utf-8")
raw_result.unlink()
missing_raw = assess(root, recorded_at)
assert missing_raw["integrity_status"] == "pass", missing_raw
assert "runtime_campaign" in missing_raw["blocker_ids"], missing_raw
raw_result.write_text(raw_result_content, encoding="utf-8")

policy_path = root / "manifests/software_m5_policy.json"
original_policy = policy_path.read_text(encoding="utf-8")
weakened_policy = json.loads(original_policy)
weakened_policy["rules"].pop("append_only_hash_chain")
policy_path.write_text(json.dumps(weakened_policy) + "\n", encoding="utf-8")
weakened = assess(root, recorded_at)
assert weakened["integrity_status"] == "fail", weakened
assert weakened["blocker_ids"] == ["evidence_integrity"], weakened
policy_path.write_text(original_policy, encoding="utf-8")

for invalid_evidence_report in ("", "../outside-release-evidence.json"):
    invalid_policy = json.loads(original_policy)
    invalid_policy["release"]["evidence_report"] = invalid_evidence_report
    policy_path.write_text(json.dumps(invalid_policy) + "\n", encoding="utf-8")
    invalid_result = assess(root, recorded_at)
    assert invalid_result["integrity_status"] == "fail", invalid_result
    assert invalid_result["blocker_ids"] == ["evidence_integrity"], invalid_result
policy_path.write_text(original_policy, encoding="utf-8")

try:
    append_event(
        root,
        {
            "event_id": "path-traversal",
            "pilot_id": "self-pilot",
            "occurred_at": "2026-02-01T00:00:00Z",
            "event_type": "workload_executed",
            "evidence_layer": "field",
            "repository_id": "product-self",
            "operator_id": "operator-one",
            "summary": "must not be written",
            "evidence": ["../outside.md"],
            "metrics": {"task_count": 1, "success_rate": 1.0},
        },
        recorded_at=recorded_at,
    )
except M5Error as exc:
    assert "inside the repository" in str(exc)
else:
    raise AssertionError("event evidence path traversal was accepted")
PY

if [[ -f "${ROOT}/agent-dev-kit/manifest.json" ]]; then
  live_status_rc=0
  "${ROOT}/scripts/check-software-m5-readiness.sh" "${ROOT}" --summary-json >"${TMP_DIR}/live-status.json" || live_status_rc=$?
  [[ "${live_status_rc}" -eq 1 ]] || {
    echo "[FAIL] live not-ready status returned unexpected code ${live_status_rc}" >&2
    exit 1
  }
  "${ROOT}/scripts/check-software-m5-readiness.sh" "${ROOT}" --allow-not-ready --summary-json \
    >"${TMP_DIR}/live-status-allowed.json"
  if "${ROOT}/scripts/software-m5.sh" certify --summary-json >"${TMP_DIR}/live-certify.json"; then
    echo "[FAIL] live workspace was prematurely certified as software M5" >&2
    exit 1
  fi
  python3 - "${TMP_DIR}/live-status.json" "${TMP_DIR}/live-certify.json" <<'PY'
import json
import sys

status = json.load(open(sys.argv[1], encoding="utf-8"))
certify = json.load(open(sys.argv[2], encoding="utf-8"))
expected = [
    "final_version",
    "independent_repository",
    "operator_count",
    "pilot_duration",
    "real_repository_count",
    "release_rehearsal",
    "repository_runtime_campaign",
    "required_field_events",
    "runtime_campaign",
]
assert status["integrity_status"] == "pass", status
assert status["declaration_status"] == "pass", status
assert status["readiness_status"] == "not-ready", status
assert status["software_m5_certified"] is False, status
assert status["blocker_ids"] == expected, status
assert certify["blocker_ids"] == expected, certify
PY
fi

echo "[PASS] software M5 certification contracts hold"
