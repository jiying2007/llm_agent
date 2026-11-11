#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHONPATH="$ROOT" python3 -m tools.control_plane.adk_interface --source-pin --root "$ROOT" --summary-json \
  | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["status"]=="pass",p; assert p["signature_verified"] is False'


# A changed ADK gitlink must take the same protected CI path as the native signer check.
python3 - "$ROOT/.github/workflows/ci.yml" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1]).read_text(encoding="utf-8")
for must in (
    "Verify native immutable ADK Release on exact gitlink changes",
    "git/trees/$base_sha",
    "git -C agent-dev-kit fetch origin",
    "sha256sum --check",
    "--source-pin --root .",
    "--release-archive",
    "--release-contract",
    "--release-json",
    "/tmp/adk-native-release-receipt.json",
):
    assert must in workflow, must
assert "git fetch --no-tags origin \"$base_sha\"" not in workflow
PY

python3 - "$ROOT" <<'PY'
import datetime as dt
import hashlib
import json
import subprocess
import tempfile
from unittest.mock import patch
from pathlib import Path

from tools.control_plane.adk_interface import (
    check_claims, source_pin, materialize_lock_projection, verify_native_release_contract, verify_native_release_attestation,
)

def git(cwd, *args):
    p = subprocess.run(["git", "-C", str(cwd), *args], check=True,
                       text=True, capture_output=True)
    return p.stdout.strip()

def expect_fail(fn, reason):
    try:
        fn()
    except ValueError:
        return
    raise AssertionError("negative case unexpectedly succeeded: " + reason)

with tempfile.TemporaryDirectory(prefix="adk-single-pin-") as tmp:
    root = Path(tmp)
    adk = root / "agent-dev-kit"
    adk.mkdir()
    git(adk, "init", "-q")
    git(adk, "config", "user.name", "Fixture")
    git(adk, "config", "user.email", "fixture@example.invalid")
    (adk / "manifest.json").write_text('{\n  "version": "9.2.1"\n}\n', encoding="utf-8")
    git(adk, "add", "manifest.json")
    git(adk, "commit", "-qm", "fixture adk")
    commit = git(adk, "rev-parse", "HEAD")

    git(root, "init", "-q")
    git(root, "config", "user.name", "Fixture")
    git(root, "config", "user.email", "fixture@example.invalid")
    git(root, "update-index", "--add", "--cacheinfo", "160000," + commit + ",agent-dev-kit")
    git(root, "commit", "-qm", "pin fixture adk")
    identity = source_pin(root)
    assert identity["commit"] == commit and identity["version"] == "9.2.1"

    cache = root / "adk.lock"
    derived = materialize_lock_projection(root)
    assert derived == identity and cache.is_file() and not cache.is_symlink()
    lines = dict(line.split("=",1) for line in cache.read_text().splitlines())
    assert lines["schema"] == "llm-agent-adk-lock/v2"
    assert lines["agent-dev-kit.commit"] == commit and lines["agent-dev-kit.version"] == identity["version"]
    assert git(root, "ls-files", "adk.lock") == "", "derived cache must not be tracked"
    original_cache = cache.read_bytes()
    assert materialize_lock_projection(root) == identity
    assert cache.read_bytes() == original_cache
    cache.write_bytes(original_cache + b"\nforged=value\n")
    expect_fail(lambda: materialize_lock_projection(root), "divergent cache must fail closed")
    cache.write_bytes(original_cache)
    cache.unlink()
    unsafe = root / "outside.json"
    unsafe.write_text("sentinel", encoding="utf-8")
    cache.symlink_to(unsafe)
    expect_fail(lambda: materialize_lock_projection(root), "symlinked cache must fail closed")
    assert unsafe.read_text() == "sentinel"
    cache.unlink()
    materialize_lock_projection(root)

    issued = (dt.datetime.now(dt.UTC) - dt.timedelta(days=366)).isoformat().replace("+00:00", "Z")
    evidence = {
        "schema": "adk-promotion-evidence/v2",
        "issued_at": issued,
        "source": {
            **identity, "repository": "jiying2007/agent-dev-kit",
            "ref": "refs/heads/main", "event": "push",
            "workflow": "agent-dev-kit-ci", "workflow_sha": commit,
            "workflow_ref": "jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main",
            "run_id": 1234,
        },
        "ci": {
            "contract_matrix": {"python": ["3.12"], "status": "success"},
            "regression_matrix": {"python": ["3.12"], "status": "success"},
            "static_security": "success", "deterministic_eval_package": "success",
        },
        "release": {"release_eligible": True, "artifact_sha256": "f" * 64},
        "provenance": {"subject": "promotion-evidence.json", "format": "sigstore-bundle/v1"},
    }
    run = {"id": 1234, "head_sha": commit, "event": "push", "conclusion": "success"}
    release = {
        "tag_name": "v9.2.1", "draft": False, "prerelease": False,
        "assets": [{"name": "agent-dev-kit-9.2.1.tar.gz", "digest": "sha256:" + "f" * 64}],
    }
    result = check_claims(identity, evidence, run, release)
    assert result["status"] == "pass"
    assert result["evidence_age_policy"] == "no-arbitrary-expiration"
    assert result["device_qualified"] is False and result["runtime_qualified"] is False

    mutated = json.loads(json.dumps(evidence))
    mutated["source"]["tree"] = "0" * 40
    expect_fail(lambda: check_claims(identity, mutated, run, release), "mismatched tree")
    mutated = json.loads(json.dumps(evidence))
    mutated["source"]["ref"] = "refs/pull/1/head"
    expect_fail(lambda: check_claims(identity, mutated, run, release), "untrusted PR CI")
    mutated = json.loads(json.dumps(evidence))
    mutated["ci"]["regression_matrix"]["status"] = "failure"
    expect_fail(lambda: check_claims(identity, mutated, run, release), "failed regression")
    mutated = json.loads(json.dumps(evidence))
    mutated["issued_at"] = (dt.datetime.now(dt.UTC) + dt.timedelta(days=1)).isoformat().replace("+00:00", "Z")
    expect_fail(lambda: check_claims(identity, mutated, run, release), "future dated")
    mutated_release = json.loads(json.dumps(release))
    mutated_release["assets"][0]["digest"] = "sha256:" + "0" * 64
    expect_fail(lambda: check_claims(identity, evidence, run, mutated_release), "wrong release digest")
    expect_fail(lambda: check_claims(identity, evidence, {**run, "conclusion": "failure"}, release), "failed main CI")


    # Native immutable Release proof survives short CI artifact retention.
    archive = root / "agent-dev-kit-9.2.1.tar.gz"
    archive.write_bytes(b"fixture immutable release archive")
    artifact_sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    manifest_source = (adk / "manifest.json").read_bytes()
    manifest_data = json.loads(manifest_source.decode("utf-8"))
    manifest_sha = hashlib.sha256(
        (json.dumps(manifest_data, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    ).hexdigest()
    assert manifest_sha != hashlib.sha256(manifest_source).hexdigest(), "fixture must distinguish canonical from raw hash"
    contract = {
        "schema": "adk-release-artifact-contract-set/v1", "status": "pass",
        "artifacts": [{
            "schema": "adk-release-artifact-contract/v1",
            "status": "pass", "artifact": archive.name, "version": "9.2.1",
            "artifact_sha256": artifact_sha, "manifest_sha256": manifest_sha,
            "release_eligible": True,
        }],
    }
    released = {
        "tag_name": "v9.2.1", "immutable": True, "draft": False, "prerelease": False,
        "assets": [{"name": archive.name, "digest": "sha256:" + artifact_sha,
                    "size": archive.stat().st_size}],
    }
    native = verify_native_release_contract(root, identity, archive, contract, released)
    assert native["status"] == "pass" and native["source_authority"] == "git-submodule-index"
    assert native["signature_verified"] is False
    invalid = json.loads(json.dumps(released))
    invalid["immutable"] = False
    expect_fail(lambda: verify_native_release_contract(root, identity, archive, contract, invalid), "mutable Release")
    invalid = json.loads(json.dumps(released))
    invalid["assets"][0]["digest"] = "sha256:" + "0" * 64
    expect_fail(lambda: verify_native_release_contract(root, identity, archive, contract, invalid), "wrong artifact digest")
    invalid = json.loads(json.dumps(contract))
    invalid["artifacts"][0]["manifest_sha256"] = "0" * 64
    expect_fail(lambda: verify_native_release_contract(root, identity, archive, invalid, released), "wrong manifest hash")
    invalid = json.loads(json.dumps(contract))
    invalid["artifacts"][0]["manifest_sha256"] = hashlib.sha256(manifest_source).hexdigest()
    expect_fail(lambda: verify_native_release_contract(root, identity, archive, invalid, released), "raw hash is not canonical")
    invalid = json.loads(json.dumps(contract))
    invalid["artifacts"][0]["release_eligible"] = False
    expect_fail(lambda: verify_native_release_contract(root, identity, archive, invalid, released), "ineligible artifact")
    archive.write_bytes(b"tampered archive payload")
    expect_fail(lambda: verify_native_release_contract(root, identity, archive, contract, released), "tampered archive")
    archive.write_bytes(b"fixture immutable release archive")

    valid_gh = subprocess.CompletedProcess(args=[], returncode=0,
                                          stdout='[{"attestation":{},"verificationResult":{}}]', stderr="")
    with patch("tools.control_plane.adk_interface.subprocess.run", return_value=valid_gh) as command:
        assert verify_native_release_attestation(archive, identity) == 1
        called = command.call_args.args[0]
        assert "--signer-workflow" in called and "jiying2007/agent-dev-kit/.github/workflows/release.yml" in called
        assert "--source-digest" in called and commit in called
        assert "--source-ref" in called and "refs/heads/main" in called
    with patch("tools.control_plane.adk_interface.subprocess.run", return_value=subprocess.CompletedProcess(
        args=[], returncode=1, stdout="", stderr="untrusted signer",
    )):
        expect_fail(lambda: verify_native_release_attestation(archive, identity), "untrusted signature")
    with patch("tools.control_plane.adk_interface.subprocess.run", return_value=subprocess.CompletedProcess(
        args=[], returncode=0, stdout="[]", stderr="",
    )):
        expect_fail(lambda: verify_native_release_attestation(archive, identity), "empty attestation")

    (adk / "manifest.json").write_text('{"version":"9.2.2"}\n', encoding="utf-8")
    expect_fail(lambda: source_pin(root), "dirty manifest")
    git(adk, "checkout", "--", "manifest.json")
    # A real, distinct commit is needed: Git refuses all-zero gitlink SHA.
    (adk / "fixture-drift.txt").write_text("second valid commit\n", encoding="utf-8")
    git(adk, "add", "fixture-drift.txt")
    git(adk, "commit", "-qm", "second valid ADK fixture")
    second_commit = git(adk, "rev-parse", "HEAD")
    git(root, "update-index", "--cacheinfo", "160000," + commit + ",agent-dev-kit")
    assert second_commit != commit
    expect_fail(lambda: source_pin(root), "gitlink differs from worktree")

print("[PASS] single Git pin and signed-claim boundaries; stale authentic evidence is not arbitrarily expired")
PY
