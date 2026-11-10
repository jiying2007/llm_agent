"""Single-authority ADK source pin and independently verified upstream provenance.

The parent Git index gitlink is the sole version authority. Git tree/blob and
manifest version are derived from that commit, never accepted as parallel locks.
Historical signed evidence can be checked without copying it into Root.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Mapping

from tools.codex_assets.intake_io import IntakeError, read_json

SCHEMA = "llm-agent-adk-source-pin/v1"
EVIDENCE_SCHEMA = "adk-promotion-evidence/v2"
PRODUCER = "jiying2007/agent-dev-kit"
WORKFLOW = "jiying2007/agent-dev-kit/.github/workflows/ci.yml@refs/heads/main"
CERTIFICATE_IDENTITY = "https://github.com/" + WORKFLOW
CERTIFICATE_ISSUER = "https://token.actions.githubusercontent.com"
SHA40 = re.compile(r"^[a-f0-9]{40}$")
SHA64 = re.compile(r"^[a-f0-9]{64}$")
MAX_JSON = 1024 * 1024


def _git(root: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(root), *args], check=False, text=True, capture_output=True, timeout=30
    )
    if proc.returncode:
        raise ValueError("git source identity unavailable: " + proc.stderr.strip()[:500])
    return proc.stdout.strip()


def source_pin(root: Path) -> dict[str, str]:
    """Resolve identity strictly from the indexed gitlink and its exact checkout."""
    root = root.resolve()
    rows = _git(root, "ls-files", "-s", "--", "agent-dev-kit").splitlines()
    if len(rows) != 1:
        raise ValueError("exactly one tracked ADK gitlink is required")
    parts = rows[0].split()
    if len(parts) != 4 or parts[0] != "160000" or parts[2] != "0" or parts[3] != "agent-dev-kit":
        raise ValueError("ADK pin is not a stage-0 gitlink")
    commit = parts[1]
    if SHA40.fullmatch(commit) is None:
        raise ValueError("invalid ADK commit")
    adk = root / "agent-dev-kit"
    if not adk.is_dir() or adk.is_symlink() or not (adk / ".git").exists():
        raise ValueError("ADK pinned checkout must be initialized")
    if _git(adk, "rev-parse", "HEAD") != commit:
        raise ValueError("ADK worktree HEAD differs from indexed gitlink")
    tree = _git(adk, "rev-parse", "HEAD^{tree}")
    blob = _git(adk, "rev-parse", "HEAD:manifest.json")
    if SHA40.fullmatch(tree) is None or SHA40.fullmatch(blob) is None:
        raise ValueError("invalid ADK tree or manifest blob identity")
    if _git(adk, "hash-object", "--no-filters", "manifest.json") != blob:
        raise ValueError("ADK manifest worktree differs from the pinned blob")
    try:
        manifest = read_json(adk / "manifest.json", label="pinned ADK manifest", max_bytes=MAX_JSON)
    except IntakeError as exc:
        raise ValueError("pinned ADK manifest is unreadable or unsafe") from exc
    if not isinstance(manifest, dict):
        raise ValueError("pinned ADK manifest must be an object")
    version = manifest.get("version")
    if not isinstance(version, str) or re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version) is None:
        raise ValueError("pinned ADK version must be a stable SemVer")
    return {"version": version, "commit": commit, "tree": tree, "manifest_blob": blob}


def _object(value: Any, label: str) -> Mapping[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(label + " must be a JSON object")
    return value


def check_claims(
    identity: Mapping[str, str],
    evidence: Mapping[str, Any],
    run: Mapping[str, Any],
    release: Mapping[str, Any],
    *,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Validate exactly pinned signed-CI claims; no arbitrary evidence age expiry."""
    if evidence.get("schema") != EVIDENCE_SCHEMA:
        raise ValueError("unsupported signed ADK evidence schema")
    src = _object(evidence.get("source"), "source")
    ci = _object(evidence.get("ci"), "ci")
    eligible = _object(evidence.get("release"), "release")
    provenance = _object(evidence.get("provenance"), "provenance")
    for key in ("version", "commit", "tree", "manifest_blob"):
        if src.get(key) != identity[key]:
            raise ValueError("upstream source." + key + " differs from pinned ADK")
    if (
        src.get("repository") != PRODUCER or src.get("ref") != "refs/heads/main"
        or src.get("event") != "push" or src.get("workflow") != "agent-dev-kit-ci"
        or src.get("workflow_ref") != WORKFLOW or src.get("workflow_sha") != identity["commit"]
    ):
        raise ValueError("untrusted source workflow provenance")
    if provenance.get("subject") != "promotion-evidence.json" or provenance.get("format") != "sigstore-bundle/v1":
        raise ValueError("untrusted signed subject description")
    if (
        run.get("id") != src.get("run_id") or run.get("head_sha") != identity["commit"]
        or run.get("event") != "push" or run.get("conclusion") != "success"
    ):
        raise ValueError("upstream GitHub Actions run does not match signed source")
    for key in ("contract_matrix", "regression_matrix"):
        section = _object(ci.get(key), key)
        if section.get("status") != "success" or section.get("python") != ["3.12"]:
            raise ValueError("required ADK CI matrix is not successful: " + key)
    if ci.get("static_security") != "success" or ci.get("deterministic_eval_package") != "success":
        raise ValueError("required ADK quality check failed")
    if eligible.get("release_eligible") is not True:
        raise ValueError("ADK release eligibility is not true")
    digest = eligible.get("artifact_sha256")
    if not isinstance(digest, str) or SHA64.fullmatch(digest) is None:
        raise ValueError("invalid signed release digest")
    if (
        release.get("tag_name") != "v" + identity["version"]
        or release.get("draft") is not False or release.get("prerelease") is not False
    ):
        raise ValueError("ADK Release is unpublished or does not match the pinned version")
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise ValueError("ADK Release assets are missing")
    name = "agent-dev-kit-" + identity["version"] + ".tar.gz"
    if sum(1 for asset in assets if isinstance(asset, dict) and asset.get("name") == name
           and asset.get("digest") == "sha256:" + digest) != 1:
        raise ValueError("ADK Release asset digest does not match signed evidence")
    issued_text = evidence.get("issued_at")
    if not isinstance(issued_text, str) or not issued_text.endswith("Z"):
        raise ValueError("signed evidence issued_at must be UTC")
    try:
        issued = dt.datetime.fromisoformat(issued_text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError("invalid signed evidence issuance time") from exc
    current = now or dt.datetime.now(dt.UTC)
    if issued > current + dt.timedelta(minutes=5):
        raise ValueError("signed evidence is future-dated")
    return {
        "schema": SCHEMA,
        "status": "pass",
        "identity": dict(identity),
        "run_id": run["id"],
        "release_asset_sha256": digest,
        "evidence_age_policy": "no-arbitrary-expiration",
        "device_qualified": False,
        "runtime_qualified": False,
    }


def verify_sigstore(evidence_path: Path, bundle_path: Path) -> None:
    """Signature verification cannot be skipped by source-only attestations."""
    try:
        proc = subprocess.run(
            [
                "cosign", "verify-blob", "--bundle", str(bundle_path),
                "--certificate-identity", CERTIFICATE_IDENTITY,
                "--certificate-oidc-issuer", CERTIFICATE_ISSUER, str(evidence_path),
            ],
            check=False, capture_output=True, text=True, timeout=90,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        raise ValueError("Sigstore verification unavailable") from exc
    if proc.returncode != 0:
        raise ValueError("upstream Sigstore evidence failed verification: " + proc.stderr[-500:])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Verify ADK single Git pin and optional external signed evidence")
    parser.add_argument("--root", default=".")
    parser.add_argument("--evidence")
    parser.add_argument("--attestation")
    parser.add_argument("--run-json")
    parser.add_argument("--release-json")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    result: dict[str, Any]
    try:
        identity = source_pin(Path(args.root))
        paths = (args.evidence, args.attestation, args.run_json, args.release_json)
        if any(paths):
            if not all(paths):
                raise ValueError("signed evidence, Sigstore bundle, run and Release metadata must be supplied together")
            evidence = _object(read_json(Path(args.evidence), label="ADK signed evidence", max_bytes=MAX_JSON), "evidence")
            run = _object(read_json(Path(args.run_json), label="ADK CI run", max_bytes=MAX_JSON), "run")
            release = _object(read_json(Path(args.release_json), label="ADK Release", max_bytes=MAX_JSON), "release")
            verify_sigstore(Path(args.evidence), Path(args.attestation))
            result = check_claims(identity, evidence, run, release)
            result["signature_verified"] = True
        else:
            result = {"schema": SCHEMA, "status": "pass", "identity": identity,
                      "signature_verified": False, "evidence_layer": "source-only"}
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired, IntakeError) as exc:
        result = {"schema": SCHEMA, "status": "fail", "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True) if args.summary_json else
          json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
