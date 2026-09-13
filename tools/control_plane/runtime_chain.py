from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _lock(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw or raw.startswith("#"):
            continue
        if "=" not in raw:
            raise RuntimeError(f"{path}:{lineno}: malformed lock line")
        key, value = raw.split("=", 1)
        if not key or key in result:
            raise RuntimeError(f"{path}:{lineno}: duplicate/empty key: {key!r}")
        result[key] = value
    return result


def _json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _git(root: Path, *args: str) -> str:
    completed = subprocess.run(["git", "-C", str(root), *args], check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout.strip()


def _expect(value: Any, expected: Any, label: str) -> None:
    if value != expected:
        raise RuntimeError(f"{label}: {value!r} != {expected!r}")


def _pin_check(root: Path) -> dict[str, str]:
    codex = _lock(root / "codex.lock")
    adk = _lock(root / "adk.lock")
    evidence = _json(root / "reports/promotion/agent-dev-kit/promotion-evidence.json")
    _expect(codex.get("schema"), "llm-agent-codex-lock/v1", "codex.lock schema")
    _expect(adk.get("schema"), "llm-agent-adk-lock/v2", "adk.lock schema")
    for key in ("codex.commit", "codex.tree", "codex.provider_lock_blob", "codex.runtime_control_blob", "codex.runtime_binding_blob", "codex.agents_blob", "codex.validator_blob", "codex.workflow_blob", "agent-dev-kit.commit", "agent-dev-kit.tree", "agent-dev-kit.manifest_blob"):
        if not FULL_SHA.fullmatch(codex.get(key, "")):
            raise RuntimeError(f"codex.lock {key} must be a full Git SHA")
    if not SHA256.fullmatch(codex.get("agent-dev-kit.release_artifact_sha256", "")):
        raise RuntimeError("codex.lock release artifact must be sha256 hex")
    for key in ("agent-dev-kit.version", "agent-dev-kit.commit", "agent-dev-kit.tree", "agent-dev-kit.manifest_blob"):
        _expect(codex.get(key), adk.get(key), f"cross-lock {key}")
    source = evidence.get("source", {})
    release = evidence.get("release", {})
    _expect(source.get("repository"), "jiying2007/agent-dev-kit", "promotion repository")
    _expect(source.get("version"), codex["agent-dev-kit.version"], "promotion version")
    _expect(source.get("commit"), codex["agent-dev-kit.commit"], "promotion commit")
    _expect(source.get("tree"), codex["agent-dev-kit.tree"], "promotion tree")
    _expect(source.get("manifest_blob"), codex["agent-dev-kit.manifest_blob"], "promotion manifest")
    _expect(release.get("artifact_sha256"), codex["agent-dev-kit.release_artifact_sha256"], "promotion artifact")
    _expect(release.get("release_eligible"), True, "promotion eligibility")
    return codex


def _worktree_check(root: Path, lock: dict[str, str]) -> dict[str, Any]:
    codex_root = root / "codex"
    if not codex_root.is_dir():
        raise RuntimeError("codex worktree unavailable")
    _expect(_git(codex_root, "rev-parse", "HEAD"), lock["codex.commit"], "Codex commit")
    _expect(_git(codex_root, "rev-parse", "HEAD^{tree}"), lock["codex.tree"], "Codex tree")
    blob_paths = {
        "codex.provider_lock_blob": "manifests/provider-locks/agent-dev-kit.json",
        "codex.runtime_control_blob": "manifests/runtime_control.json",
        "codex.runtime_binding_blob": "manifests/integrations/digital-worker-runtime-binding.json",
        "codex.agents_blob": "manifests/agents.json",
        "codex.validator_blob": "scripts/validate-runtime-binding.py",
        "codex.workflow_blob": ".github/workflows/runtime-binding-contract.yml",
    }
    for key, path in blob_paths.items():
        _expect(_git(codex_root, "rev-parse", f"HEAD:{path}"), lock[key], f"Codex blob {path}")
    provider = _json(codex_root / blob_paths["codex.provider_lock_blob"])
    _expect(provider.get("schema"), "codex-provider-lock/v3", "provider schema")
    _expect(provider.get("repository"), "jiying2007/agent-dev-kit", "provider repository")
    _expect(provider.get("version"), lock["agent-dev-kit.version"], "provider version")
    _expect(provider.get("provider_commit"), lock["agent-dev-kit.commit"], "provider commit")
    _expect(provider.get("provider_tree"), lock["agent-dev-kit.tree"], "provider tree")
    _expect(provider.get("manifest_blob"), lock["agent-dev-kit.manifest_blob"], "provider manifest")
    _expect(provider.get("release_artifact", {}).get("sha256"), lock["agent-dev-kit.release_artifact_sha256"], "provider artifact")
    _expect(provider.get("asset_profile"), "embedded-fullstack", "provider profile")
    _expect(provider.get("delivery_mode"), "exact-source-set", "provider delivery")
    _expect(provider.get("binding_status"), "source-set-bound", "provider binding")
    for rule in ("consumer_must_bind_exact_release_source", "consumer_must_bind_exact_source_blob_per_vendored_asset", "consumer_must_own_runtime_assembly", "consumer_must_not_use_legacy_nested_repo_identity", "consumer_must_not_relabel_historical_evidence"):
        _expect(provider.get("rules", {}).get(rule), True, f"provider rule {rule}")
    runtime = _json(codex_root / blob_paths["codex.runtime_control_blob"])
    _expect(runtime.get("schema_version"), 2, "runtime schema")
    engine = runtime.get("engine", {})
    _expect(engine.get("kind"), "codex-native", "runtime engine")
    _expect(engine.get("module"), "tools.codex_assets.runtime_kernel", "runtime module")
    baseline = engine.get("behavior_baseline", {})
    _expect(baseline.get("repository"), "jiying2007/agent-dev-kit", "runtime baseline repository")
    _expect(baseline.get("version"), lock["agent-dev-kit.version"], "runtime baseline version")
    _expect(baseline.get("commit"), lock["agent-dev-kit.commit"], "runtime baseline commit")
    binding = _json(codex_root / blob_paths["codex.runtime_binding_blob"])
    _expect(binding.get("schema_version"), 2, "binding schema")
    _expect(binding.get("status"), "active", "binding status")
    _expect(binding.get("role"), "codex-runtime-distribution-and-host-integration", "binding role")
    source_binding = binding.get("source_binding", {})
    _expect(source_binding.get("provider_repository"), "jiying2007/agent-dev-kit", "binding provider")
    _expect(source_binding.get("release_version"), lock["agent-dev-kit.version"], "binding version")
    _expect(source_binding.get("provider_commit"), lock["agent-dev-kit.commit"], "binding commit")
    _expect(source_binding.get("asset_profile"), "embedded-fullstack", "binding profile")
    _expect(source_binding.get("identity_mode"), "exact-release-source-blobs", "binding identity")
    _expect(binding.get("readiness"), "SOURCE_SET_BOUND", "binding readiness")
    _expect(binding.get("gate_semantics", {}).get("runtime_success_implies_domain_verification_pass"), False, "domain boundary")
    _expect(binding.get("gate_semantics", {}).get("runtime_release_gate_implies_product_release_readiness"), False, "product boundary")
    agents = _json(codex_root / blob_paths["codex.agents_blob"])
    vendored = [item for item in agents.get("agents", []) if isinstance(item, dict) and item.get("enabled") is True and "agent-dev-kit" in str(item.get("vendor_rel", ""))]
    if len(vendored) != 9:
        raise RuntimeError(f"expected 9 active ADK vendored agents, got {len(vendored)}")
    for item in vendored:
        name = item.get("name", "<unknown>")
        _expect(item.get("version"), lock["agent-dev-kit.version"], f"agent {name} version")
        _expect(item.get("source_repo"), "jiying2007/agent-dev-kit", f"agent {name} repo")
        _expect(item.get("source_ref"), lock["agent-dev-kit.commit"], f"agent {name} ref")
        if not FULL_SHA.fullmatch(str(item.get("source_blob", ""))):
            raise RuntimeError(f"agent {name} source_blob must be full SHA")
        if "/2.9.0/" in str(item.get("vendor_rel", "")):
            raise RuntimeError(f"agent {name} retains retired 2.9.0 vendor path")
    workflow = (codex_root / blob_paths["codex.workflow_blob"]).read_text(encoding="utf-8")
    if "ubuntu-latest" in workflow or "runs-on: ubuntu-24.04" not in workflow:
        raise RuntimeError("Codex workflow runner is not pinned")
    for lineno, line in enumerate(workflow.splitlines(), 1):
        match = re.search(r"\buses:\s*[^\s@]+@([^\s#]+)", line)
        if match and not FULL_SHA.fullmatch(match.group(1)):
            raise RuntimeError(f"Codex workflow action is not SHA-pinned at line {lineno}: {match.group(1)}")
    active_text = "\n".join((codex_root / path).read_text(encoding="utf-8") for path in (blob_paths["codex.provider_lock_blob"], blob_paths["codex.runtime_control_blob"], blob_paths["codex.runtime_binding_blob"], blob_paths["codex.agents_blob"]))
    for retired in ("BLOCKED_ASSET_BUNDLE_IDENTITY", '"asset_bundle_hash"', "5.0.0-rc.2", "llm_agent/agent-dev-kit", "agent_dev_kit-4.0.0"):
        if retired in active_text:
            raise RuntimeError(f"retired active compatibility token resurfaced: {retired}")
    return {"vendored_adk_agents": len(vendored), "codex_commit": lock["codex.commit"], "codex_tree": lock["codex.tree"]}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate terminal llm_agent -> ADK -> Codex identity chain")
    parser.add_argument("--root", default=".")
    parser.add_argument("--pin-only", action="store_true")
    parser.add_argument("--require-codex-worktree", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    try:
        codex = _pin_check(root)
        detail: dict[str, Any] = {}
        if args.pin_only:
            if args.require_codex_worktree:
                raise RuntimeError("--pin-only cannot be combined with --require-codex-worktree")
        else:
            detail = _worktree_check(root, codex)
        result = {"schema": "llm-agent-runtime-chain-check/v1", "status": "pass", "mode": "pin-only" if args.pin_only else "worktree", "chain": "llm_agent -> agent-dev-kit@v5.1.0 -> codex -> ~/.codex", **detail}
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        if args.summary_json:
            print(json.dumps({"schema": "llm-agent-runtime-chain-check/v1", "status": "fail", "error": str(exc)}, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print("[PASS] terminal llm_agent -> ADK -> Codex runtime chain is consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
