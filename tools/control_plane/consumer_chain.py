from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from tools.control_plane import runtime_chain

FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _repository_slug(url: str) -> str:
    if url.startswith("git@") and ":" in url:
        value = url.split(":", 1)[1]
    else:
        parsed = urlparse(url)
        if parsed.scheme not in {"http", "https", "ssh", "git"} or not parsed.path:
            raise RuntimeError("reference repository URL is invalid")
        value = parsed.path
    value = value.strip("/")
    if value.endswith(".git"):
        value = value[:-4]
    if "/" not in value:
        raise RuntimeError("reference repository URL must identify owner/repository")
    return value


def _digital_worker_pin(root: Path) -> dict[str, str]:
    registry = _json(root / "manifests/reference_pins.json")
    if registry.get("schema") != "llm-agent-reference-pins/v2":
        raise RuntimeError("consumer chain requires reference-pins/v2")
    policy = registry.get("policy", {})
    if policy.get("runtime_enablement") is not False or policy.get("pin_is_evidence_not_source") is not True:
        raise RuntimeError("reference pin policy must remain evidence-only")
    matches = [
        item for item in registry.get("pins", [])
        if isinstance(item, dict) and item.get("id") == "digital-worker"
    ]
    if len(matches) != 1:
        raise RuntimeError("digital-worker requires exactly one reference pin")
    pin = matches[0]
    if pin.get("kind") != "reference-repo" or pin.get("path") != "digital-worker":
        raise RuntimeError("digital-worker reference pin has invalid kind/path")
    commit = pin.get("commit")
    url = pin.get("url")
    if not isinstance(commit, str) or not FULL_SHA.fullmatch(commit):
        raise RuntimeError("digital-worker reference commit must be exact")
    if not isinstance(url, str):
        raise RuntimeError("digital-worker reference URL is missing")
    return {"id": "digital-worker", "path": "digital-worker", "commit": commit, "url": url, "repository": _repository_slug(url)}


def _pilot_binding(root: Path, pin: dict[str, str]) -> dict[str, str]:
    ledger = _json(root / "manifests/software_m5_pilot_ledger.json")
    repositories = {
        item.get("id"): item
        for item in ledger.get("repositories", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    repo = repositories.get("digital-worker")
    if not isinstance(repo, dict):
        raise RuntimeError("digital-worker is missing from Software-M5 pilot ledger")
    if repo.get("classification") != "independent" or repo.get("real_software") is not True:
        raise RuntimeError("digital-worker must remain an independent real-software pilot repository")
    if repo.get("path") != pin["path"] or repo.get("reference_pin") != pin["id"]:
        raise RuntimeError("Software-M5 ledger is not bound to the digital-worker reference pin")

    event_log = ledger.get("event_log")
    if not isinstance(event_log, str):
        raise RuntimeError("Software-M5 pilot ledger event log is missing")
    events: list[dict[str, Any]] = []
    for lineno, raw in enumerate((root / event_log).read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        value = json.loads(raw)
        if not isinstance(value, dict):
            raise RuntimeError(f"field event line {lineno} is not an object")
        events.append(value)

    candidates = [
        event for event in events
        if event.get("event_type") == "pilot_started"
        and event.get("repository_id") == "digital-worker"
        and event.get("evidence_layer") == "field"
    ]
    if len(candidates) != 1:
        raise RuntimeError("digital-worker requires exactly one canonical pilot_started field event")
    event = candidates[0]
    event_hash = event.get("event_hash")
    if not isinstance(event_hash, str) or not SHA256.fullmatch(event_hash):
        raise RuntimeError("digital-worker pilot event hash is invalid")

    evidence_paths = event.get("evidence")
    evidence_digests = event.get("evidence_sha256")
    if not isinstance(evidence_paths, list) or not isinstance(evidence_digests, dict):
        raise RuntimeError("digital-worker pilot event evidence binding is invalid")

    matched: list[str] = []
    for relative in evidence_paths:
        if not isinstance(relative, str):
            continue
        path = root / relative
        actual_sha256 = hashlib.sha256(path.read_bytes()).hexdigest()
        if evidence_digests.get(relative) != actual_sha256:
            raise RuntimeError(f"field evidence digest drift: {relative}")
        if path.suffix != ".json":
            continue
        evidence = _json(path)
        if evidence.get("schema") != "llm-agent-m5-independent-pilot-start/v1":
            continue
        pilot_repo = evidence.get("pilot_repository", {})
        if (
            pilot_repo.get("id") == pin["id"]
            and pilot_repo.get("path") == pin["path"]
            and pilot_repo.get("repository") == pin["repository"]
            and pilot_repo.get("commit") == pin["commit"]
            and pilot_repo.get("classification") == "independent"
            and pilot_repo.get("real_software") is True
        ):
            matched.append(relative)
    if len(matched) != 1:
        raise RuntimeError("digital-worker exact pin is not uniquely bound to pilot-start evidence")
    return {"event_id": str(event.get("event_id")), "event_hash": event_hash, "evidence": matched[0]}


def check(root: Path, *, require_codex_worktree: bool = False) -> dict[str, Any]:
    root = root.resolve()
    codex_lock = runtime_chain._pin_check(root)
    runtime_detail: dict[str, Any] = {}
    if require_codex_worktree:
        runtime_detail = runtime_chain._worktree_check(root, codex_lock)
    pin = _digital_worker_pin(root)
    pilot = _pilot_binding(root, pin)
    return {
        "schema": "llm-agent-consumer-chain-check/v1",
        "status": "pass",
        "chain": "agent-dev-kit release -> codex runtime distribution -> digital-worker independent consumer evidence",
        "mode": "worktree" if require_codex_worktree else "pin-only",
        "agent_dev_kit": {
            "version": codex_lock["agent-dev-kit.version"],
            "commit": codex_lock["agent-dev-kit.commit"],
            "release_artifact_sha256": codex_lock["agent-dev-kit.release_artifact_sha256"],
        },
        "codex": {
            "commit": codex_lock["codex.commit"],
            "tree": codex_lock["codex.tree"],
            **runtime_detail,
        },
        "digital_worker": {
            "repository": pin["repository"],
            "commit": pin["commit"],
            "pilot_event_id": pilot["event_id"],
            "pilot_event_hash": pilot["event_hash"],
            "pilot_evidence": pilot["evidence"],
            "runtime_enablement_from_reference_pin": False,
        },
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate ADK release -> Codex -> digital-worker consumer chain")
    parser.add_argument("--root", default=".")
    parser.add_argument("--require-codex-worktree", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = check(Path(args.root), require_codex_worktree=args.require_codex_worktree)
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        failure = {"schema": "llm-agent-consumer-chain-check/v1", "status": "fail", "error": str(exc)}
        if args.summary_json:
            print(json.dumps(failure, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print("[PASS] ADK release -> Codex -> digital-worker consumer chain is consistent")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
