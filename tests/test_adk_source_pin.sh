#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYTHONPATH="$ROOT" python3 -m tools.control_plane.adk_interface --source-pin --root "$ROOT" --summary-json \
  | python3 -c 'import json,sys; p=json.load(sys.stdin); assert p["status"]=="pass",p; assert p["signature_verified"] is False'

python3 - "$ROOT" <<'PY'
import datetime as dt
import json
import subprocess
import tempfile
from pathlib import Path

from tools.control_plane.adk_interface import check_claims, source_pin

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
    (adk / "manifest.json").write_text('{"version":"9.2.1"}\n', encoding="utf-8")
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
