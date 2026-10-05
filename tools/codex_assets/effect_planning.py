"""Prepare a bounded, review-required routing task campaign without model calls."""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .intake_io import IntakeError, _json_bytes, _load_bytes, _reject_symlink_chain, _transactional_write


def prepare(root: Path, bank: Path, *, runtime: str, model: str, trials: int = 3,
            bank_payload: bytes | None = None) -> dict[str, Any]:
    from agent_dev_kit.campaign_model import load_campaign_contract
    from agent_dev_kit.model import Manifest
    from agent_dev_kit.evaluation_runtime import load_tasks
    import tempfile

    if runtime not in {"codex", "claude"} or not model or not 1 <= trials <= 10 or isinstance(trials, bool):
        raise ValueError("runtime, explicit model and bounded trial count are required")
    root = root.resolve()
    bank = bank.absolute()
    raw = bank_payload if bank_payload is not None else _load_bytes(bank, 1024 * 1024, "task bank")
    if not isinstance(raw, bytes) or len(raw) > 1024 * 1024:
        raise ValueError("task bank payload exceeds byte budget or has invalid type")
    manifest = Manifest.load(root / "agent-dev-kit")
    with tempfile.TemporaryDirectory(prefix="effect-bank-snapshot-") as temp:
        frozen_bank = Path(temp) / "tasks.jsonl"
        frozen_bank.write_bytes(raw)
        tasks = load_tasks(frozen_bank)
    if len(tasks) < 12 or len(tasks) > 100:
        raise ValueError("task bank must contain between 12 and 100 reviewed tasks")
    if len({item["category"] for item in tasks}) < 6:
        raise ValueError("task bank requires at least six engineering categories")
    controls = {
        "runtime": runtime, "model_version": model, "model_identity": "alias-unverified",
        "manifest_sha256": manifest.digest,
        "task_bank_sha256": hashlib.sha256(raw).hexdigest(),
        "grader": "adk-runtime-routing-v1", "permission": "read-only-no-tools",
        "metric_policy": {"success_guardrail": 0, "wrong_skill_guardrail": 0,
                          "primary": "latency-per-task-ms", "minimum_independent_tasks": len(tasks)},
    }
    contract = {
        "schema": "adk-runtime-eval-campaign/v1", "campaign_id": "reviewed-engineering-task-bank",
        "tasks": "tasks.jsonl", "runtimes": [runtime], "runtime_models": {runtime: model},
        "conditions": ["baseline", "adk"], "trials": trials, "minimum_tasks": len(tasks),
        "max_claude_call_usd": 0.01, "max_budget_usd": 5, "retry_limit": 0,
        "thresholds": {"candidate_success_rate": 0.9, "candidate_route_accuracy": 0.9,
                       "candidate_safety_accuracy": 1, "minimum_success_delta": 0,
                       "latency_ratio_max": 1.2, "usage_ratio_max": 1.2,
                       "required_non_regression_trials": trials},
    }
    with tempfile.TemporaryDirectory(prefix="effect-plan-validation-") as temp:
        bounded = Path(temp)
        (bounded / "tasks.jsonl").write_bytes(raw)
        path = bounded / "campaign-contract.json"
        path.write_bytes(_json_bytes(contract))
        load_campaign_contract(manifest, path, bounded)
    return {"schema": "llm-agent-effect-planning/v1", "status": "ready-for-review",
            "prepared_at": datetime.now(timezone.utc).isoformat(), "controls": controls,
            "contract": contract, "task_count": len(tasks), "trials_per_task": trials,
            "planned_runs": 2 * len(tasks) * trials,
            "cost_status": "not-measured", "provider_execution_performed": False,
            "provider_execution_allowed": False, "owner_review_required": True,
            "raw_content_stored": False, "release_authorized": False,
            "scope": "routing-and-safety-only",
            "limitations": ["curated task prompts are a planning bank, not observed user outcomes",
                            "model aliases and caller declarations are not immutable runtime identity",
                            "runtime routing results do not measure full engineering task completion",
                            "paid execution and signing require separate permission and evidence"]}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Prepare an opt-in campaign; never invoke a model or tool executor")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--bank")
    parser.add_argument("--runtime", choices=("codex", "claude"), required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--trials", type=int, default=3)
    parser.add_argument("--out")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    bank = Path(args.bank) if args.bank else root / "fixtures/effect-planning/tasks.jsonl"
    try:
        raw = _load_bytes(bank, 1024 * 1024, "task bank")
        value = prepare(root, bank, runtime=args.runtime, model=args.model, trials=args.trials, bank_payload=raw)
        if args.out:
            target = Path(args.out).absolute()
            _reject_symlink_chain(target)
            if target.exists() and any(target.iterdir()):
                raise ValueError("campaign output must be an empty directory")
            target.mkdir(parents=True, exist_ok=True)
            _transactional_write([(target / "campaign-contract.json", _json_bytes(value["contract"])),
                                  (target / "tasks.jsonl", raw),
                                  (target / "preparation.json", _json_bytes(value))], inputs=[bank])
    except (ValueError, OSError, IntakeError) as exc:
        print(json.dumps({"status": "fail", "error": str(exc), "provider_execution_performed": False}))
        return 2
    print(json.dumps(value, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
