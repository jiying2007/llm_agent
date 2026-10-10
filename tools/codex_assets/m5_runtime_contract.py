"""One fail-closed consumer contract for measured M5 runtime evidence."""

from __future__ import annotations

import hashlib
import json
import re
from datetime import date, datetime, timezone
from typing import Any, Mapping
from pathlib import Path

GATES = {"success_rate", "route_accuracy", "safety_accuracy", "runtime_errors"}


def digest(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()


def validate(evidence: Mapping[str, Any], lock: Mapping[str, str], now: datetime,
             *, expected_model: str | None = None, source_root: Path | None = None) -> None:
    def require(condition: bool, message: str) -> None:
        if not condition:
            raise ValueError(message)

    require(evidence.get("schema") == "llm-agent-runtime-smoke-evidence/v1", "runtime evidence schema is invalid")
    for key, source in (("manifest_version", "version"), ("adk_commit", "commit"),
                        ("adk_tree", "tree"), ("manifest_blob", "manifest_blob")):
        require(evidence.get(key) == lock.get("agent-dev-kit." + source),
                f"runtime evidence {key} does not match current adk.lock")
    model = evidence.get("requested_model")
    require(isinstance(model, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}", model) is not None,
            "runtime requested model is invalid")
    require(expected_model is None or model == expected_model, "runtime requested model differs from expected model")
    timestamp = evidence.get("generated_at")
    require(isinstance(timestamp, str) and timestamp.endswith("Z"), "runtime generated_at is invalid")
    generated = datetime.fromisoformat(timestamp[:-1] + "+00:00")
    require(generated <= now.astimezone(timezone.utc), "runtime evidence is future-dated")
    review = date.fromisoformat(evidence.get("review_after", ""))
    require(1 <= (review - generated.date()).days <= 90 and review >= now.date(), "runtime review window is invalid or expired")
    unsigned = dict(evidence)
    stored = unsigned.pop("evidence_sha256", None)
    require(stored == digest(unsigned), "runtime evidence_sha256 does not match content")
    report = evidence.get("result")
    require(isinstance(report, dict), "runtime report is missing")
    require(evidence.get("runtime") == "codex" and report.get("runtime") == "codex"
            and report.get("condition") == "adk", "runtime report must describe codex/adk")
    require(report.get("schema_version") == 1 and report.get("suite") == "runtime-routing", "runtime report schema/suite is invalid")
    require(report.get("status") == "pass" and report.get("requested_model") == model
            and report.get("reported_models") == [model], "runtime report requested/observed model or status is invalid")
    require(isinstance(evidence.get("runtime_version"), str) and bool(evidence["runtime_version"].strip())
            and report.get("runtime_version") == evidence["runtime_version"], "runtime version is inconsistent")
    gates = report.get("quality_gate")
    require(isinstance(gates, dict) and set(gates) == GATES and all(v is True for v in gates.values()),
            "runtime quality gates are incomplete or not all passing")
    total, passed = report.get("total"), report.get("passed")
    collection = evidence.get("collection")
    require(isinstance(collection, dict) and collection.get("runtime_identity") == "selected-executable-pre-post-sha256",
            "runtime execution identity is unverified")
    require(type(total) is int and 1 <= total <= 1000 and type(passed) is int and passed == total
            and isinstance(collection, dict) and type(collection.get("task_limit")) is int
            and collection["task_limit"] == total, "runtime task counts are invalid")
    observation = collection.get("model_observation")
    if "model_observation" in collection:
        require(isinstance(observation, dict)
                and observation.get("scope") == "upstream-response-openai-model-header",
                "runtime provider observation scope is invalid")
        require(isinstance(observation.get("adapter_sha256"), str)
                and re.fullmatch(r"[0-9a-f]{64}", observation["adapter_sha256"]) is not None,
                "runtime provider adapter digest is invalid")
        records = observation.get("records")
        require(isinstance(records, list) and len(records) == total, "runtime provider records are incomplete")
        response_ids = set()
        for record in records:
            require(isinstance(record, dict) and record.get("model") == model
                    and record.get("completed") is True and record.get("tools_disabled") is True
                    and record.get("scope") == observation["scope"]
                    and record.get("upstream") == "https://chatgpt.com/backend-api/codex/responses",
                    "runtime provider record identity is invalid")
            identifier = record.get("response_id")
            require(isinstance(identifier, str) and 0 < len(identifier) <= 256 and identifier not in response_ids,
                    "runtime provider response identity is invalid")
            response_ids.add(identifier)
            sources = record.get("header_sources")
            require(isinstance(sources, list) and bool(sources)
                    and all(isinstance(source, str) for source in sources)
                    and sources == sorted(set(sources))
                    and set(sources) <= {"http-response-header", "sse-response-header"},
                    "runtime provider header sources are invalid")
            require(isinstance(record.get("request_sha256"), str)
                    and re.fullmatch(r"[0-9a-f]{64}", record["request_sha256"]) is not None,
                    "runtime provider request digest is invalid")
    for key in ("manifest_sha256", "runtime_binary_sha256", "raw_result_sha256"):
        require(isinstance(evidence.get(key), str) and re.fullmatch(r"[0-9a-f]{64}", evidence[key]) is not None,
                f"runtime {key} is invalid")
    require(report.get("manifest_sha256") == evidence["manifest_sha256"], "runtime manifest digest is inconsistent")
    from tools.codex_assets.runtime_smoke_evidence import TASK_IDENTITY_SCOPE, GRADER_CONTRACT, PROMPT_VERSION
    require(report.get("task_set_identity_scope") == TASK_IDENTITY_SCOPE
            and report.get("task_snapshot_frozen") is True and report.get("source_snapshot_atomic") is False
            and report.get("grader_contract") == GRADER_CONTRACT and report.get("prompt_version") == PROMPT_VERSION,
            "runtime task snapshot or grader contract is invalid")
    require(isinstance(report.get("task_set_sha256"), str)
            and re.fullmatch(r"[0-9a-f]{64}", report["task_set_sha256"]) is not None,
            "runtime task-set digest is invalid")
    results = report.get("results")
    require(isinstance(results, list) and len(results) == total, "runtime task results are incomplete")
    ids: set[str] = set()
    for item in results:
        require(isinstance(item, dict), "runtime task result is invalid")
        task_id = item.get("id")
        require(isinstance(task_id, str) and bool(task_id) and task_id not in ids, "runtime task identity is missing or duplicated")
        ids.add(task_id)
        require(item.get("status") == "pass" and item.get("route_ok") is True and item.get("safe_ok") is True
                and item.get("error") is None, "runtime task did not pass route/safety/error gates")
        require(item.get("requested_model") == model and item.get("reported_models") == [model], "runtime task observed model differs")
        skill = item.get("expected_skill")
        require(isinstance(skill, str) and bool(skill) and item.get("expected_route") == skill
                and item.get("actual_skill") == skill and type(item.get("expected_safe")) is bool
                and item.get("actual_safe") is item["expected_safe"], "runtime task grading labels are inconsistent")
        require(isinstance(item.get("prompt_sha256"), str)
                and re.fullmatch(r"[0-9a-f]{64}", item["prompt_sha256"]) is not None, "runtime prompt identity is invalid")
        usage = item.get("usage")
        require(isinstance(usage, dict) and type(usage.get("total_tokens")) is int
                and usage["total_tokens"] >= 0, "runtime task usage is invalid")
    if source_root is not None:
        from tools.codex_assets import runtime_smoke_evidence as smoke
        if observation is not None:
            from tools.codex_assets.intake_io import read_bytes
            adapter = source_root / "tools/codex_assets/codex_model_observer.py"
            require(hashlib.sha256(read_bytes(adapter.absolute(), label="provider observer", max_bytes=256 * 1024)).hexdigest()
                    == observation["adapter_sha256"], "runtime provider adapter differs from current source")
        current_lock, manifest, adk = smoke._validate_source_identity(source_root)
        if any(current_lock.get(key) != value for key, value in lock.items()):
            raise ValueError("runtime source lock changed")
        tasks_path = adk / "tests/fixtures/software_m5_eval_tasks.jsonl"
        tasks, tasks_digest, task_bytes = smoke._selected_task_snapshot(tasks_path, total)
        smoke._verify_pinned_bytes(adk, "tests/fixtures/software_m5_eval_tasks.jsonl", task_bytes)
        require(collection.get("tasks_sha256") == hashlib.sha256(task_bytes).hexdigest(),
                "runtime collection task dataset differs from pinned ADK tasks")
        smoke._validate_raw_report(report, model, total, smoke._manifest_digest(manifest), tasks, tasks_digest)
        post_lock, post_manifest, post_adk = smoke._validate_source_identity(source_root)
        require(post_lock == current_lock and post_manifest == manifest and post_adk == adk,
                "runtime pinned source changed during verification")
