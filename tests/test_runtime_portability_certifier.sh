#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FIXTURE="$TMP/root"
mkdir -p "$FIXTURE/manifests" "$FIXTURE/reports/promotion/agent-dev-kit" "$FIXTURE/reports/portability"

cp "$ROOT/manifests/digital_worker_runtime_pilot.json" "$FIXTURE/manifests/"
cp "$ROOT/manifests/adk_interface.lock.json" "$FIXTURE/manifests/"
cp "$ROOT/reports/promotion/agent-dev-kit/promotion-evidence.json" "$FIXTURE/reports/promotion/agent-dev-kit/"

# Missing real comparison evidence is a BLOCKED external-evidence state, never PASS.
set +e
python3 -m tools.control_plane.runtime_portability --root "$FIXTURE" --summary-json >"$TMP/missing.json"
rc=$?
set -e
[[ "$rc" -eq 2 ]]
python3 - "$TMP/missing.json" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "blocked", value
assert value["qualification"] == "LTA-02", value
assert "real comparison evidence is not available" in value["reason"], value
PY

# Build a self-test-only two-runtime fixture. It proves certifier semantics only;
# it is never copied into reports/long-term-assets and cannot by itself qualify LTA-02.
python3 - "$FIXTURE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
contract_path = root / "manifests/digital_worker_runtime_pilot.json"
contract = json.loads(contract_path.read_text(encoding="utf-8"))
selftest_binding_commits = {
    "codex": "1" * 40,
    "claude-code": "2" * 40,
}
for item in contract["candidate_runtime_bindings"]:
    runtime = item["runtime"]
    item["binding_commit"] = selftest_binding_commits[runtime]
    if runtime == "claude-code":
        item.update({
            "repository": "jiying2007/claude-code-binding",
            "source_identity_mode": "exact-release-source-blobs",
            "status": "source-set-bound",
        })
for runtime, commit in selftest_binding_commits.items():
    contract["execution_plane_evidence"][runtime]["frozen_binding_commit"] = commit
    contract["execution_plane_evidence"][runtime]["execution_plane_commit"] = commit
contract_path.write_text(json.dumps(contract, indent=2) + "\n", encoding="utf-8")

interface = json.loads((root / "manifests/adk_interface.lock.json").read_text(encoding="utf-8"))
promotion = json.loads((root / "reports/promotion/agent-dev-kit/promotion-evidence.json").read_text(encoding="utf-8"))

def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()

def digest_obj(value):
    return hashlib.sha256(canonical(value)).hexdigest()

def digest_file(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")

controlled = {
    "work_item_id": "selftest-work-item",
    "run_id": "selftest-comparison-run",
    "task_type": "code-change",
    "workflow_mode": "controlled-real-task",
    "repo_root": "digital-worker",
    "exact_base_commit": "3" * 40,
    "dirty_baseline": False,
    "digital_worker_governance_identity_ref": "sha256:" + "d" * 64,
    "material_manifest": {"digest": "material-selftest"},
    "knowledge_context_fingerprint": "knowledge-selftest",
    "engineering_task_package": {"digest": "task-package-selftest"},
    "acceptance_criteria": ["same acceptance"],
    "required_verification": ["same verification"],
    "adk_release_identity_ref": "manifests/adk_interface.lock.json",
    "adk_asset_profile": "core",
    "runtime_source_set_identity_ref": "comparison-source-set-selftest",
}
frozen = digest_obj(controlled)

runs = []
receipts = {}
for runtime, repository, commit, target, provider in (
    ("codex", "https://github.com/jiying2007/codex.git", "1" * 40, "codex-cli", "openai"),
    ("claude-code", "jiying2007/claude-code-binding", "2" * 40, "claude-code", "anthropic"),
):
    identity = {
        "runtime_binding_repository": repository,
        "runtime_binding_commit": commit,
        "runtime_target": target,
        "runtime_profile": "controlled-selftest",
        "runtime_host": "local-terminal",
        "runtime_provider": provider,
        "runtime_version": "selftest-1",
        "runtime_source_set_identity_ref": f"{runtime}-source-set-selftest",
        "runtime_distribution_identity_ref": f"{runtime}-distribution-selftest",
    }
    receipt_ref = f"reports/portability/{runtime}-receipt.json"
    receipt = {
        "schema": "runtime-binding-execution-receipt/selftest-v1",
        "status": "completed",
        "runtime": runtime,
        "frozen_inputs_sha256": frozen,
        "verification_pass_claimed": False,
        "runtime_identity": identity,
    }
    receipt_path = root / receipt_ref
    write(receipt_path, receipt)
    receipt_digest = digest_file(receipt_path)
    receipts[runtime] = receipt_digest
    runs.append({
        "runtime": runtime,
        "healthy": True,
        **identity,
        "execution_receipt_ref": receipt_ref,
        "execution_receipt_sha256": receipt_digest,
    })

provider_execution_evidence = {
    "codex": {
        "execution_venue": "local-terminal",
        "runtime_home_mode": "shared-user-home",
        "credential_state_in_evidence": False,
        "runtime_binding_commit": "1" * 40,
    },
    "claude-code": {
        "execution_venue": "local-terminal",
        "runtime_home_mode": "shared-user-home",
        "credential_state_in_evidence": False,
        "runtime_binding_commit": "2" * 40,
    },
}
common_result = {
    "status": "pass",
    "comparison_id": "selftest-comparison",
    "frozen_inputs_sha256": frozen,
    "standard_id": "same-verifier-review-standard-v1",
    "source_repository": "jiying2007/digital-worker",
    "source_commit": "4" * 40,
    "verification_tool_commit": "5" * 40,
    "execution_receipts": receipts,
    "provider_execution_evidence": provider_execution_evidence,
    "verification_pass_claimed_by_runtime": False,
}
verification_ref = "reports/portability/domain-verification.json"
review_ref = "reports/portability/independent-review.json"
write(root / verification_ref, {
    "schema": "digital-worker-domain-verification/selftest-v1",
    **common_result,
    "verification_execution_venue": "local-terminal",
    "github_provider_credentials_required": False,
    "independent_review_status": "pending",
})
write(root / review_ref, {
    "schema": "digital-worker-independent-review/selftest-v1",
    **common_result,
    "independent": True,
    "release_ready_claimed": False,
    "r2_qualified": False,
})

evidence = {
    "schema": "llm-agent-runtime-portability-evidence/v1",
    "evidence_level": "R2-real-provider-substitution",
    "comparison_id": "selftest-comparison",
    "controlled_task": controlled,
    "frozen_inputs_sha256": frozen,
    "adk_release_identity": {
        "version": interface["version"],
        "commit": interface["commit"],
        "tree": interface["tree"],
        "manifest_blob": interface["manifest_blob"],
        "artifact_sha256": promotion["release"]["artifact_sha256"],
    },
    "runtime_runs": runs,
    "verification_standard_id": "same-verifier-review-standard-v1",
    "domain_verification_ref": verification_ref,
    "domain_verification_sha256": digest_file(root / verification_ref),
    "independent_review_ref": review_ref,
    "independent_review_sha256": digest_file(root / review_ref),
}
write(root / "reports/portability/comparison.json", evidence)
PY

python3 -m tools.control_plane.runtime_portability \
  --root "$FIXTURE" \
  --evidence "$FIXTURE/reports/portability/comparison.json" \
  --summary-json >"$TMP/pass.json"
python3 - "$TMP/pass.json" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "pass", value
assert value["qualification"] == "LTA-02", value
assert value["evidence_level"] == "R2-real-provider-substitution", value
assert value["digital_worker_governance_identity_ref"].startswith("sha256:"), value
assert value["runtimes"] == ["claude-code", "codex"], value
assert set(value["execution_receipts"]) == {"codex", "claude-code"}, value
assert value["digital_worker_commit"] == "4" * 40, value
PY

# A runtime receipt cannot drift away from the exact frozen local adapter/binding identity.
python3 - "$FIXTURE/reports/portability/comparison.json" "$FIXTURE/reports/portability/wrong-binding.json" <<'PY'
import json, sys
from pathlib import Path
comparison = json.loads(Path(sys.argv[1]).read_text())
comparison["runtime_runs"][0]["runtime_binding_commit"] = "9" * 40
Path(sys.argv[2]).write_text(json.dumps(comparison, indent=2, sort_keys=True) + "\n")
PY
set +e
python3 -m tools.control_plane.runtime_portability --root "$FIXTURE" --evidence "$FIXTURE/reports/portability/wrong-binding.json" --summary-json >"$TMP/wrong-binding-result.json"
rc=$?
set -e
[[ "$rc" -eq 1 ]]
python3 - "$TMP/wrong-binding-result.json" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "fail", value
assert "does not match the frozen canonical binding" in value["error"], value
PY

# R1 binding conformance must never qualify terminal portability.
python3 - "$FIXTURE/reports/portability/comparison.json" "$FIXTURE/reports/portability/r1.json" <<'PY'
import json, sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text())
value["evidence_level"] = "R1-binding-conformance"
Path(sys.argv[2]).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
PY
set +e
python3 -m tools.control_plane.runtime_portability --root "$FIXTURE" --evidence "$FIXTURE/reports/portability/r1.json" --summary-json >"$TMP/r1.json"
rc=$?
set -e
[[ "$rc" -eq 2 ]]
python3 - "$TMP/r1.json" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "blocked", value
assert "requires R2-real-provider-substitution" in value["reason"], value
PY

# A real evidence file cannot pass while a compared binding remains future-only.
# Keep the synthetic frozen identity intact so this case isolates binding readiness,
# rather than failing earlier on an unrelated exact-identity mismatch.
cp "$ROOT/manifests/digital_worker_runtime_pilot.json" "$FIXTURE/manifests/digital_worker_runtime_pilot.json"
python3 - "$FIXTURE/manifests/digital_worker_runtime_pilot.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1]); value = json.loads(path.read_text())
commits = {"codex": "1" * 40, "claude-code": "2" * 40}
for item in value["candidate_runtime_bindings"]:
    runtime = item["runtime"]
    item["binding_commit"] = commits[runtime]
    item["status"] = "source-set-bound"
    if runtime == "claude-code":
        item["repository"] = "jiying2007/claude-code-binding"
        item["status"] = "binding-candidate-blocked"
        item["blocker_ref"] = "selftest://future-only"
        item["blocker"] = "selftest-future-only"
for runtime, commit in commits.items():
    value["execution_plane_evidence"][runtime]["frozen_binding_commit"] = commit
    value["execution_plane_evidence"][runtime]["execution_plane_commit"] = commit
path.write_text(json.dumps(value, indent=2) + "\n")
PY
set +e
python3 -m tools.control_plane.runtime_portability --root "$FIXTURE" --evidence "$FIXTURE/reports/portability/comparison.json" --summary-json >"$TMP/future.json"
rc=$?
set -e
[[ "$rc" -eq 2 ]]
python3 - "$TMP/future.json" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "blocked", value
assert "runtime binding is not source-set-bound/ready: claude-code" in value["reason"], value
PY

# Restore the self-test frozen identities for malformed-evidence negative cases.
python3 - "$FIXTURE/manifests/digital_worker_runtime_pilot.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1]); value = json.loads(path.read_text())
commits = {"codex": "1" * 40, "claude-code": "2" * 40}
for item in value["candidate_runtime_bindings"]:
    runtime = item["runtime"]
    item["binding_commit"] = commits[runtime]
    item["status"] = "source-set-bound"
    if runtime == "claude-code":
        item["repository"] = "jiying2007/claude-code-binding"
        item.pop("blocker_ref", None)
        item.pop("blocker", None)
for runtime, commit in commits.items():
    value["execution_plane_evidence"][runtime]["frozen_binding_commit"] = commit
    value["execution_plane_evidence"][runtime]["execution_plane_commit"] = commit
path.write_text(json.dumps(value, indent=2) + "\n")
PY

# One runtime is an external evidence gap, not a qualifying comparison.
python3 - "$FIXTURE/reports/portability/comparison.json" "$TMP/one-runtime.json" <<'PY'
import json, sys
from pathlib import Path
value = json.loads(Path(sys.argv[1]).read_text()); value["runtime_runs"] = value["runtime_runs"][:1]
Path(sys.argv[2]).write_text(json.dumps(value, indent=2) + "\n")
PY
cp "$TMP/one-runtime.json" "$FIXTURE/reports/portability/one-runtime.json"
set +e
python3 -m tools.control_plane.runtime_portability --root "$FIXTURE" --evidence "$FIXTURE/reports/portability/one-runtime.json" --summary-json >"$TMP/one-result.json"
rc=$?
set -e
[[ "$rc" -eq 2 ]]

# Execution receipts must never self-assert domain verification PASS.
python3 - "$FIXTURE" <<'PY'
import hashlib, json
from pathlib import Path
root = Path(__import__('sys').argv[1])
evidence_path = root / "reports/portability/comparison.json"
evidence = json.loads(evidence_path.read_text())
receipt_path = root / evidence["runtime_runs"][0]["execution_receipt_ref"]
receipt = json.loads(receipt_path.read_text()); receipt["verification_status"] = "pass"
receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
evidence["runtime_runs"][0]["execution_receipt_sha256"] = hashlib.sha256(receipt_path.read_bytes()).hexdigest()
evidence_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
PY
set +e
python3 -m tools.control_plane.runtime_portability --root "$FIXTURE" --evidence "$FIXTURE/reports/portability/comparison.json" --summary-json >"$TMP/claim.json"
rc=$?
set -e
[[ "$rc" -eq 1 ]]
python3 - "$TMP/claim.json" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
assert value["status"] == "fail", value
assert "forbidden verification PASS claim" in value["error"], value
PY

echo "[PASS] LTA-02 certifier requires exact local-terminal runtime adapter identity, digest-bound R2 evidence, local Digital Worker verification/review provenance, and keeps missing real provider evidence BLOCKED"
