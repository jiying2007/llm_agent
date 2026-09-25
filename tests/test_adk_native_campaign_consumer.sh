#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - "$ROOT" <<'PY'
import json
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1]).resolve()
adk = (root / "agent-dev-kit").resolve()
lock = {}
for line in (root / "adk.lock").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value
expected_version = lock["agent-dev-kit.version"]
expected_commit = lock["agent-dev-kit.commit"]
major, minor, patch = (int(item) for item in expected_version.split("."))
assert (major, minor, patch) >= (7, 4, 0), expected_version
assert expected_commit, lock

layouts = json.loads(
    (adk / "manifests" / "native_campaign_target_layouts.json").read_text(encoding="utf-8")
)
assert layouts["schema"] == "adk-native-campaign-target-layouts/v1", layouts
assert layouts["targets"]["claude-code"]["project_config_dir"] == ".claude", layouts
assert layouts["targets"]["opencode"]["project_config_dir"] == ".opencode", layouts

active_contract = adk / "manifests" / "target-contracts" / "claude-code.json"
active_before = active_contract.read_bytes()
runtime_reports = adk / "reports" / "runtime"
runtime_reports.mkdir(parents=True, exist_ok=True)
receipt_dir = Path(tempfile.mkdtemp(prefix="root-native-campaign-", dir=runtime_reports))
external = Path(tempfile.mkdtemp(prefix="root-native-campaign-"))
try:
    receipt = receipt_dir / "receipt.json"
    receipt_rel = receipt.relative_to(adk).as_posix()
    commands_path = external / "commands.json"
    plan = external / "plan.json"
    candidate = external / "candidate.json"
    evidence = external / "evidence.json"
    final_contract = external / "final-contract.json"

    version = platform.python_version()
    runtime = str(Path(sys.executable).resolve())
    sentinel = "root-native-campaign-raw-sentinel"

    def stage(stage_name: str, exit_code: int = 0) -> list[str]:
        code = (
            "import os,sys;"
            "from pathlib import Path;"
            "assert 'HOME' not in os.environ;"
            "assert os.environ['ADK_TARGET_SMOKE_STAGE']==sys.argv[1];"
            "project=Path(os.environ['ADK_TARGET_PROJECT_ROOT']).resolve();"
            "config=Path(os.environ['ADK_TARGET_ROOT']).resolve();"
            "assert Path.cwd().resolve()==project;"
            "assert config==project/'.claude';"
            "assert config.is_dir();"
            "assert list((config/'skills').glob('*/SKILL.md'));"
            f"print('{sentinel}-'+sys.argv[1]);"
            f"raise SystemExit({exit_code})"
        )
        return [runtime, "-c", code, stage_name]

    commands = {
        "version": [runtime, "--version"],
        "discovery": stage("discovery"),
        "load": stage("load"),
        "trigger": stage("trigger"),
    }
    commands_path.write_text(json.dumps(commands), encoding="utf-8")

    def invoke(args: list[str], expected: int = 0) -> dict:
        done = subprocess.run(
            [
                sys.executable,
                "-m",
                "agent_dev_kit.cli",
                "native-campaign",
                "--root",
                str(adk),
                *args,
                "--summary-json",
            ],
            cwd=root,
            text=True,
            capture_output=True,
            timeout=120,
        )
        assert done.returncode == expected, (args, done.returncode, done.stdout, done.stderr)
        return json.loads(done.stdout)

    prepared = invoke([
        "prepare",
        "--target", "claude-code",
        "--profile", "core",
        "--runtime-binary", runtime,
        "--runtime-version", version,
        "--authority-id", "ci-native-conformance",
        "--execution-authority", "ci-approved",
        "--verification-backend", "ci-provenance-verifier",
        "--auth-mode", "none",
        "--commands-json", str(commands_path),
        "--receipt-path", receipt_rel,
        "--plan-out", str(plan),
        "--candidate-contract-out", str(candidate),
    ])
    assert prepared["status"] == "ready", prepared
    assert prepared["release_authorized"] is False, prepared

    ran = invoke([
        "run",
        "--plan", str(plan),
        "--candidate-contract", str(candidate),
        "--commands-json", str(commands_path),
        "--runtime-binary", runtime,
        "--evidence-out", str(evidence),
    ])
    assert ran["status"] == "complete", ran
    assert ran["release_authorized"] is False, ran
    assert [item["status"] for item in ran["stages"]] == ["pass", "pass", "pass"], ran
    assert sentinel not in json.dumps(ran, ensure_ascii=False), ran

    finalized = invoke([
        "finalize",
        "--plan", str(plan),
        "--candidate-contract", str(candidate),
        "--evidence", str(evidence),
        "--receipt-out", str(receipt),
        "--final-contract-out", str(final_contract),
    ])
    assert finalized["status"] == "ready-for-signature-and-registry", finalized
    assert finalized["release_authorized"] is False, finalized
    assert finalized["lifecycle_authority"] == "none-candidate-only", finalized
    assert receipt.is_file() and final_contract.is_file()
    receipt_value = json.loads(receipt.read_text(encoding="utf-8"))
    candidate_value = json.loads(final_contract.read_text(encoding="utf-8"))
    assert receipt_value["schema"] == "adk-native-target-conformance-receipt/v1", receipt_value
    assert candidate_value["adapter"]["conformance"]["level"] == "runtime", candidate_value
    assert candidate_value["adapter"]["conformance_trust_policy"]["enabled"] is True, candidate_value
    assert active_contract.read_bytes() == active_before

    registry = json.loads(
        (adk / "manifests" / "native_conformance_trust_registry.json").read_text(encoding="utf-8")
    )
    assert registry["authorities"] == {}, registry

    failed_commands = dict(commands)
    failed_commands["load"] = stage("load", exit_code=7)
    failed_commands_path = external / "failed-commands.json"
    failed_commands_path.write_text(json.dumps(failed_commands), encoding="utf-8")
    failed_plan = external / "failed-plan.json"
    failed_candidate = external / "failed-candidate.json"
    failed_evidence = external / "failed-evidence.json"
    failed_receipt = receipt_dir / "failed-receipt.json"

    invoke([
        "prepare",
        "--target", "claude-code",
        "--profile", "core",
        "--runtime-binary", runtime,
        "--runtime-version", version,
        "--authority-id", "ci-native-conformance",
        "--execution-authority", "ci-approved",
        "--verification-backend", "ci-provenance-verifier",
        "--auth-mode", "none",
        "--commands-json", str(failed_commands_path),
        "--receipt-path", failed_receipt.relative_to(adk).as_posix(),
        "--plan-out", str(failed_plan),
        "--candidate-contract-out", str(failed_candidate),
    ])
    failed = invoke([
        "run",
        "--plan", str(failed_plan),
        "--candidate-contract", str(failed_candidate),
        "--commands-json", str(failed_commands_path),
        "--runtime-binary", runtime,
        "--evidence-out", str(failed_evidence),
    ], expected=2)
    assert failed["status"] == "failed", failed
    assert [item["status"] for item in failed["stages"]] == ["pass", "fail", "blocked"], failed
    assert failed_receipt.exists() is False

    rejected = invoke([
        "finalize",
        "--plan", str(failed_plan),
        "--candidate-contract", str(failed_candidate),
        "--evidence", str(failed_evidence),
        "--receipt-out", str(failed_receipt),
        "--final-contract-out", str(external / "should-not-exist.json"),
    ], expected=1)
    assert rejected["status"] == "fail", rejected
    assert failed_receipt.exists() is False
    assert active_contract.read_bytes() == active_before

    print(f"[PASS] Root consumes pinned ADK {expected_version} native campaign CLI without upgrading trust or target authority")
finally:
    shutil.rmtree(receipt_dir, ignore_errors=True)
    shutil.rmtree(external, ignore_errors=True)
PY
