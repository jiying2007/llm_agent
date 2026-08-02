#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/docs/product-maturity-model.md" ]] || {
  echo "[FAIL] product maturity model missing" >&2
  exit 1
}

[[ -f "$ROOT/manifests/product_maturity_scorecard.json" ]] || {
  echo "[FAIL] product maturity scorecard missing" >&2
  exit 1
}

[[ -f "$ROOT/manifests/product_maturity_task_pack.json" ]] || {
  echo "[FAIL] product maturity task pack missing" >&2
  exit 1
}

[[ -f "$ROOT/manifests/software_m5_policy.json" ]] || {
  echo "[FAIL] software M5 policy missing" >&2
  exit 1
}

[[ -f "$ROOT/manifests/software_m5_pilot_ledger.json" ]] || {
  echo "[FAIL] software M5 pilot ledger missing" >&2
  exit 1
}

[[ -f "$ROOT/manifests/report_registry.json" ]] || {
  echo "[FAIL] report registry missing" >&2
  exit 1
}

python3 - "$ROOT" <<'PY'
import json
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
policy = json.loads((root / "manifests/software_m5_policy.json").read_text(encoding="utf-8"))
release_policy = policy["release"]
candidate_version = release_policy["candidate_version"]
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text(encoding="utf-8"))
adk_initialized = (root / "agent-dev-kit/manifest.json").is_file()
assert scorecard["schema"] == "llm-agent-product-maturity-scorecard/v1", scorecard
assert len(scorecard["dimensions"]) == 12, scorecard
assert [item["id"] for item in scorecard["dimensions"]] == [f"D{i:02d}" for i in range(1, 13)]
assert len({item["name"] for item in scorecard["dimensions"]}) == 12, scorecard
assert scorecard["overall"]["terminal_mature"] is False
assert scorecard["overall"]["field_status"] == "self_pilot_active"
assert scorecard["release_gates"]["status"] == "conditional-pass", scorecard
software_m5 = scorecard["software_m5"]
assert software_m5 == {
    "readiness_status": "m5-ready",
    "eligibility_status": "blocked",
    "certification_status": "blocked",
    "certified": False,
    "candidate_version": candidate_version,
    "final_version": "3.1.0",
    "blocking_gates": [
        "final_version",
        "independent_repository",
        "operator_count",
        "pilot_duration",
        "real_repository_count",
        "repository_runtime_campaign",
        "required_field_events",
        "runtime_campaign",
    ],
}, software_m5
working_candidate = scorecard["working_candidate"]
assert working_candidate["version"] == candidate_version, working_candidate
assert working_candidate["overall_level"] == "M3", working_candidate
assert working_candidate["target_status"] == "experimental", working_candidate
assert working_candidate["status"] == "source-committed-pushed-local-rehearsed-live-applied", working_candidate
assert working_candidate["lock_state"] == "synchronized", working_candidate
assert working_candidate["runtime_certification"] == "not-run", working_candidate
levels = {f"M{i}" for i in range(6)}
assessment_model = scorecard["assessment_model"]
assert assessment_model["effective_level"].startswith("minimum of "), assessment_model
assert set(assessment_model["status_semantics"]) == {
    "verified",
    "verified_local",
    "partially_verified",
}, assessment_model
statuses = {
    "verified",
    "verified_local",
    "partially_verified",
    "implemented",
    "field_not_verified",
}
for dimension in scorecard["dimensions"]:
    assert dimension["priority"] in {"P0", "P1", "P2"}, dimension
    assert dimension["level"] in levels, dimension
    assert dimension["implementation_level"] in levels, dimension
    assert dimension["evidence_level"] in levels, dimension
    assert dimension["effective_level"] in levels, dimension
    assert int(dimension["evidence_level"][1:]) <= int(dimension["implementation_level"][1:]), dimension
    expected_effective = min(
        int(dimension["implementation_level"][1:]),
        int(dimension["evidence_level"][1:]),
    )
    assert dimension["effective_level"] == f"M{expected_effective}", dimension
    if dimension["implementation_level"] != dimension["evidence_level"]:
        assert dimension["status"] != "verified", dimension
    if dimension["status"] in {"verified_local", "partially_verified"}:
        assert isinstance(dimension.get("gap"), str) and dimension["gap"].strip(), dimension
    assert set(dimension["evidence_layers_present"]).issubset({"source", "test", "runtime", "field"}), dimension
    assert dimension["status"] in statuses, dimension
    evidence = dimension.get("evidence")
    assert isinstance(evidence, list) and len(evidence) >= 2, dimension
    for value in evidence:
        path = pathlib.PurePosixPath(value)
        assert not path.is_absolute() and ".." not in path.parts, (dimension, value)
        if path.parts[0] == "agent-dev-kit" and not adk_initialized:
            continue
        assert (root / path).exists(), (dimension, value)
    if dimension["status"] in {"verified", "verified_local"}:
        assert int(dimension["effective_level"][1:]) >= 3, dimension

task_pack = json.loads((root / "manifests/product_maturity_task_pack.json").read_text(encoding="utf-8"))
assert task_pack["schema"] == "llm-agent-product-maturity-task-pack/v1", task_pack
assert all(task_pack["rules"].values()), task_pack
assert [item["id"] for item in task_pack["tasks"]] == [f"PM-{i:02d}" for i in range(1, 15)]
task_statuses = {
    "implemented",
    "in_progress",
    "pending",
    "pending_approval",
    "field_not_verified",
    "blocked_external",
    "not_required",
    "ready",
}
for task in task_pack["tasks"]:
    assert task["status"] in task_statuses, task
    commands = task.get("verify", [])
    assert isinstance(commands, list), task
    assert all(isinstance(command, str) and command.startswith("rtk ") for command in commands), task
    if task["status"] == "implemented":
        assert commands, task
assert next(item for item in task_pack["tasks"] if item["id"] == "PM-09")["status"] == "in_progress"

assert policy["schema"] == "llm-agent-software-m5-policy/v1", policy
assert re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", policy["release"]["previous_version"]), policy
assert policy["release"]["previous_version"] != candidate_version, policy
assert policy["release"]["evaluation_version"] == candidate_version, policy
assert (root / policy["release"]["evidence_report"]).is_file(), policy
contract_path = root / policy["runtime_campaign"]["contract"]
contract = json.loads(contract_path.read_text(encoding="utf-8"))
assert contract["campaign_id"] == f"software-m5-{candidate_version}", contract
assert policy["release"]["final_version"] == "3.1.0", policy
assert policy["runtime_campaign"]["required_runtimes"] == ["codex", "claude"], policy
assert policy["runtime_campaign"]["minimum_tasks"] >= 60, policy
assert policy["runtime_campaign"]["minimum_trials"] >= 3, policy
assert policy["runtime_campaign"]["max_budget_usd"] <= 150, policy
assert policy["field_certification"]["minimum_calendar_days"] >= 30, policy
assert policy["field_certification"]["minimum_independent_repositories"] >= 1, policy
assert policy["field_certification"]["minimum_human_operators"] >= 2, policy
assert all(policy["rules"].values()), policy

ledger = json.loads((root / "manifests/software_m5_pilot_ledger.json").read_text(encoding="utf-8"))
assert ledger["schema"] == "llm-agent-software-m5-pilot-ledger/v1", ledger
assert ledger["candidate_version"] == policy["release"]["candidate_version"], ledger
assert (root / ledger["event_log"]).is_file(), ledger
assert any(item["status"] == "active" and item["environment_class"] == "self" for item in ledger["pilots"])
assert all(set(item) == {"id", "operator_type", "role", "independent_reviewer"} for item in ledger["operators"])

registry = json.loads((root / "manifests/report_registry.json").read_text(encoding="utf-8"))
assert registry["schema"] == "llm-agent-report-registry/v1", registry
current = [item for item in registry["reports"] if item["status"] == "current"]
assert len(current) == 1, registry
current_path = pathlib.PurePosixPath(current[0]["path"])
assert current_path.parts[:2] == ("reports", "architecture"), current
assert (root / current_path).is_file(), current
ids = {item["id"] for item in registry["reports"]}
for item in registry["reports"]:
    assert item["status"] in {"current", "superseded"}, item
    assert (root / item["path"]).is_file(), item
    if item["status"] == "superseded":
        assert item["superseded_by"] in ids, item
    else:
        assert item["superseded_by"] is None, item
assert registry["policy"]["machine_state_source"] == "manifests/product_maturity_scorecard.json"

github_ci = root / ".github/workflows/ci.yml"
assert github_ci.is_file(), "GitHub is the delivery remote but its blocking CI workflow is missing"
workflow = github_ci.read_text(encoding="utf-8")
assert re.search(r"(?m)^permissions:\n  contents: read$", workflow), workflow
assert "submodules: false" in workflow, workflow
assert "git submodule update --init agent-dev-kit" in workflow, workflow
assert "bash scripts/check-adk-lock.sh ." in workflow, workflow
assert "bash agent-dev-kit/scripts/devkit.sh validate --strict" in workflow, workflow
assert "bash agent-dev-kit/tests/run_all.sh --quick" in workflow, workflow
assert "bash tests/run_all.sh --fail-fast" in workflow, workflow
assert "python-version: '3.11'" in workflow, workflow
assert "bash scripts/check-doc-sync.sh ." in workflow, workflow
for action in re.findall(r"(?m)^\s*uses:\s*([^\s#]+)", workflow):
    if action.startswith("./"):
        continue
    assert re.fullmatch(r"[^@]+@[0-9a-f]{40}", action), action

index = subprocess.run(
    ["git", "-C", str(root), "ls-files", "-s", "agent-dev-kit"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip().split()
assert len(index) >= 2 and index[0] == "160000", index
lock = {}
for line in (root / "adk.lock").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value
assert lock.get("agent-dev-kit.commit") == index[1], (lock, index)
PY

if rg -q 'auto-absorb\.sh' "$ROOT/scripts/pipeline-subrepo-update.sh"; then
  echo "[FAIL] target pipeline still invokes legacy auto-absorb" >&2
  exit 1
fi

if rg -q '待 AI Agent 补充|待评' "$ROOT/scripts/analyze-repo.sh"; then
  echo "[FAIL] analyzer still emits placeholder completion claims" >&2
  exit 1
fi

if rg -q '^[[:space:]]*allow_failure:[[:space:]]*true' "$ROOT/.gitlab-ci.yml"; then
  echo "[FAIL] blocking CI jobs still allow failure" >&2
  exit 1
fi

[[ ! -e "$ROOT/scripts/auto-absorb.sh" ]] || {
  echo "[FAIL] legacy automatic absorption writer still exists" >&2
  exit 1
}

rg -q 'tools\.codex_assets\.intake_pipeline' "$ROOT/scripts/analyze-repo.sh" || {
  echo "[FAIL] analyzer is not routed through the structured intake core" >&2
  exit 1
}

rg -q 'tools\.codex_assets\.update_pipeline' "$ROOT/scripts/pipeline-subrepo-update.sh" || {
  echo "[FAIL] update pipeline is not routed through the fail-fast core" >&2
  exit 1
}

rg -q 'check-performance-budgets\.sh.*--strict.*--timing-json' "$ROOT/scripts/check-adk-performance-ops.sh" || {
  echo "[FAIL] adk performance wrapper does not enforce the declared strict timing budget" >&2
  exit 1
}

echo "[PASS] llm_agent product maturity contracts hold"
