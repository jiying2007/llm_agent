#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT" <<'PY'
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
policy = json.loads((root / "manifests/software_m5_policy.json").read_text(encoding="utf-8"))
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text(encoding="utf-8"))
task_pack = json.loads((root / "manifests/product_maturity_task_pack.json").read_text(encoding="utf-8"))
status = (root / "reports/current-status.md").read_text(encoding="utf-8")

assert policy["schema"] == "llm-agent-software-m5-policy/v3", policy
assert policy["definition"] == "production-qualified", policy
assert policy["release"]["candidate_release_eligible"] is True, policy
assert policy["release"]["candidate_commit"] == "251edf2b6654cf8719ad1d8a1b7c81ffd64ffe1c", policy
assert policy["runtime_qualification"]["minimum_measured_runtimes"] == 1, policy
assert policy["field_qualification"]["minimum_real_repositories"] == 1, policy
assert policy["field_qualification"]["minimum_independent_repositories"] == 1, policy
assert policy["field_qualification"]["minimum_human_operators"] == 1, policy
assert policy["field_qualification"]["minimum_calendar_days"] == 0, policy
assert policy["field_qualification"]["required_event_types"] == ["pilot_started"], policy
assert policy["operational_advisories"]["recommended_observation_days"] >= 30, policy
assert policy["operational_advisories"]["second_human_operator"] is True, policy
assert policy["operational_advisories"]["multi_runtime_campaign"] is True, policy
assert all(policy["rules"].values()), policy

assert scorecard["schema"] == "llm-agent-product-maturity-scorecard/v1", scorecard
assert scorecard["overall"]["level"] == "M5", scorecard
assert scorecard["overall"]["status"] == "production-qualified", scorecard
assert scorecard["overall"]["terminal_mature"] is True, scorecard
assert scorecard["overall"]["field_status"] == "production_qualified", scorecard
assert scorecard["software_m5"]["readiness_status"] == "m5-ready", scorecard
assert scorecard["software_m5"]["eligibility_status"] == "release-qualified", scorecard
assert scorecard["software_m5"]["certification_status"] == "pass", scorecard
assert scorecard["software_m5"]["certified"] is True, scorecard
assert scorecard["software_m5"]["blocking_gates"] == [], scorecard
assert len(scorecard["dimensions"]) == 12, scorecard
assert [item["id"] for item in scorecard["dimensions"]] == [f"D{i:02d}" for i in range(1, 13)]
for dimension in scorecard["dimensions"]:
    assert dimension["implementation_level"] == "M5", dimension
    assert dimension["evidence_level"] == "M5", dimension
    assert dimension["effective_level"] == "M5", dimension
    assert dimension["status"] == "verified", dimension
    assert len(dimension["evidence"]) >= 2, dimension
    for relative in dimension["evidence"]:
        assert (root / relative).exists(), (dimension["id"], relative)

assert task_pack["schema"] == "llm-agent-product-maturity-task-pack/v1", task_pack
assert len(task_pack["tasks"]) == 14, task_pack
assert all(task_pack["rules"].values()), task_pack
by_id = {item["id"]: item for item in task_pack["tasks"]}
assert by_id["PM-09"]["status"] == "implemented", by_id["PM-09"]
assert by_id["PM-14"]["status"] == "not_required", by_id["PM-14"]
assert not any(item["status"] in {"blocked_external", "in_progress", "pending_approval"} for item in task_pack["tasks"]), task_pack

assert "- current_product_maturity: M5" in status, status
assert "- current_software_m5_certified: true" in status, status
assert "- release_evidence_relation: current" in status, status
assert "- release_authorized: true" in status, status

completed = subprocess.run(
    ["bash", str(root / "scripts/software-m5.sh"), "certify", "--summary-json"],
    cwd=root,
    check=False,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
assert completed.returncode == 0, completed.stderr + completed.stdout
cert = json.loads(completed.stdout)
assert cert["software_m5_certified"] is True and cert["declaration_status"] == "pass", cert
PY

echo "[PASS] product maturity contracts declare and machine-verify production-qualified M5"
