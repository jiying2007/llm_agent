#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT/manifests/digital_worker_runtime_pilot.json" "$ROOT/manifests/long_term_asset_qualification.json" "$ROOT/tools/control_plane/cli.py" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
lta_path = Path(sys.argv[2])
cli_path = Path(sys.argv[3])
root = path.parent.parent
data = json.loads(path.read_text(encoding="utf-8"))
lta = json.loads(lta_path.read_text(encoding="utf-8"))
cli = cli_path.read_text(encoding="utf-8")

assert data["schema_version"] == 5, data
assert data["contract_version"] == "1.6", data
assert data["status"] == "report-only", data
assert data["terminal_replaceability_evidence_level"] == "R2-periodic-real-provider-substitution", data

assert "periodic_r2_qualification" in data["roles"]["digital-worker"], data
assert "independent_review" not in data["roles"]["digital-worker"], data
assert data["roles"]["llm_agent"] == [
    "runtime_target_health",
    "cross_runtime_comparison_observation",
    "loop_readiness_mapping",
    "adoption_recommendation",
], data

ownership = data["execution_ownership"]
assert ownership["r2_qualification_authority"] == "jiying2007/digital-worker", ownership
assert ownership["independent_verifier_actor_required"] is True, ownership
assert ownership["llm_agent_role"] == "optional-evolution-observer", ownership
assert "independent_review_must_be_distinct_from_all_runtime_executors_and_verifier" not in ownership

bindings = {item["runtime"]: item for item in data["candidate_runtime_bindings"]}
assert set(bindings) == {"codex", "claude-code"}, bindings
assert bindings["codex"]["binding_commit"] == "541c058731b5f5ee3ab7d5fdee29b64a76158085"
assert bindings["claude-code"]["binding_commit"] == "5614184bde6c4a1d1feab1a6cef5030ca4adf482"

planes = data["execution_plane_evidence"]
for runtime, expected in {
    "codex": ("jiying2007/codex", "scripts/runtime-r2-local.sh"),
    "claude-code": ("jiying2007/claude", "control/scripts/runtime-r2-local.sh"),
}.items():
    plane = planes[runtime]
    assert plane["repository"] == expected[0], plane
    assert plane["provider_execution_adapter"] == expected[1], plane
    assert plane["execution_venue"] == "local-terminal", plane
    assert plane["runtime_home_mode"] == "shared-user-home", plane
    assert plane["credential_state_in_evidence"] is False, plane
    assert plane["replay_postflight_required"] is True, plane

dw = planes["digital-worker"]
assert dw["repository"] == "jiying2007/digital-worker", dw
assert dw["combined_provider_workflow_present"] is False, dw
assert dw["local_verifier"] == "scripts/runtime_r2_local_verify.py", dw
assert dw["qualification_policy"] == "manifests/runtime-r2-qualification-policy.json", dw
assert dw["qualification_authority"] == "digital-worker-independent-verifier", dw
assert "independent_review_workflow" not in dw, dw

rules = data["hard_rules"]
for key in (
    "runtime_output_is_not_verification_pass",
    "runtime_local_conformance_is_not_domain_verification",
    "execution_receipt_must_not_contain_verification_pass",
    "r1_binding_conformance_is_not_r2_real_provider_substitution",
    "terminal_replaceability_requires_r2_real_provider_substitution",
    "provider_credentials_must_remain_runtime_owned",
    "digital_worker_must_not_hold_provider_credentials",
    "runtime_execution_must_be_separate_from_digital_worker_verification",
    "runtime_execution_evidence_ready_requires_replay_postflight",
    "replay_postflight_must_use_exported_git_free_result_tree",
    "replay_postflight_is_not_domain_verification",
    "r2_qualification_authority_must_be_digital_worker",
    "llm_agent_must_not_recertify_r2",
    "independent_verifier_must_be_distinct_from_provider_execution_actors",
):
    assert rules[key] is True, (key, data)
assert "same_verifier_and_reviewer_standard" not in rules

requirements = {item["id"]: item for item in lta["qualification_requirements"]}
lta02 = requirements["LTA-02"]
assert lta02["status"] == "delegated_nonblocking_observation", lta02
assert lta02["implementation_status"] == "observer-ready", lta02
assert lta02["required_evidence_level"] == "R2-periodic-real-provider-substitution", lta02
assert lta02["qualification_authority"] == "jiying2007/digital-worker", lta02
assert lta02["terminal_blocking"] is False, lta02
assert lta02["affects"] == ["runtime-portability-observation"], lta02
assert "certifier" not in lta02 and "certifier_command" not in lta02, lta02

assert '"runtime-portability": "tools.control_plane.runtime_portability"' not in cli
assert not (root / "tools/control_plane/runtime_portability.py").exists()

text = path.read_text(encoding="utf-8")
for retired in (
    "runtime-r2-provider-execution.yml",
    "runtime-r2-domain-verification.yml",
    "runtime-r2-independent-review.yml",
):
    assert retired not in text, retired
PY

echo '[PASS] llm_agent observes Digital Worker periodic R2 qualification without duplicate certifier authority'
