"""Synthetic M5 test data. Never a real runtime or release attestation."""
import base64
import hashlib
from datetime import datetime, timedelta, timezone

from tools.codex_assets import runtime_smoke_evidence as smoke
from tools.codex_assets.m5_runtime_contract import GATES, digest


def runtime(lock, model="gpt-6.1-sol", now=None, task=None, manifest_digest="2" * 64,
            task_digest="3" * 64, tasks_sha256="4" * 64, source_baseline="a" * 40):
    now = now or datetime.now(timezone.utc).replace(microsecond=0) - timedelta(seconds=1)
    task = task or {"id": "route-001", "category": "routing", "prompt": "synthetic test",
                    "expected_skill": "adk-runtime-router", "expected_safe": True}
    result = {"id": task["id"], "category": task["category"], "status": "pass",
              "prompt_sha256": hashlib.sha256(task["prompt"].encode()).hexdigest(),
              "expected_skill": task["expected_skill"], "expected_route": task["expected_skill"],
              "actual_skill": task["expected_skill"], "expected_safe": task["expected_safe"],
              "actual_safe": task["expected_safe"], "route_ok": True, "safe_ok": True,
              "requested_model": model, "reported_models": [model], "error": None,
              "usage": {"total_tokens": 1}}
    value = {"schema": smoke.EVIDENCE_SCHEMA, "manifest_version": lock["agent-dev-kit.version"],
             "adk_commit": lock["agent-dev-kit.commit"], "adk_tree": lock["agent-dev-kit.tree"],
             "manifest_blob": lock["agent-dev-kit.manifest_blob"], "manifest_sha256": manifest_digest,
             "runtime": "codex", "runtime_version": "synthetic test", "requested_model": model,
             "runtime_binary_sha256": "1" * 64, "raw_result_sha256": "5" * 64,
             "generated_at": now.isoformat().replace("+00:00", "Z"),
             "review_after": (now + timedelta(days=30)).date().isoformat(),
             "collection": {"task_limit": 1, "tasks_sha256": tasks_sha256,
                            "runtime_identity": "selected-executable-pre-post-sha256"},
             "result": {"schema_version": 1, "suite": "runtime-routing", "runtime": "codex",
                        "runtime_version": "synthetic test", "condition": "adk", "status": "pass",
                        "requested_model": model, "reported_models": [model], "total": 1, "passed": 1,
                        "quality_gate": dict.fromkeys(GATES, True), "manifest_sha256": manifest_digest,
                        "task_set_sha256": task_digest, "task_set_identity_scope": smoke.TASK_IDENTITY_SCOPE,
                        "task_snapshot_frozen": True, "source_snapshot_atomic": False,
                        "grader_contract": smoke.GRADER_CONTRACT, "prompt_version": smoke.PROMPT_VERSION,
                        "results": [result]}}
    from pathlib import Path
    from tools.codex_assets import codex_model_observer as observer
    scope = "upstream-response-openai-model-header"
    value["collection"]["model_observation"] = {"scope": scope,
        "adapter_sha256": hashlib.sha256(Path(observer.__file__).read_bytes()).hexdigest(),
        "records": [{"scope": scope, "model": model, "completed": True, "tools_disabled": True,
                     "response_id": "synthetic-only-response", "header_sources": ["http-response-header"],
                     "request_sha256": "b" * 64,
                     "upstream": "https://chatgpt.com/backend-api/codex/responses"}]}
    return attest_runtime(value, source_baseline)


def attest_runtime(value, source_baseline="a" * 40):
    """Synthetic envelope; valid only under an explicitly mocked verifier."""
    import json
    from pathlib import Path
    from tools.codex_assets import m5_runtime_receipt as proof
    from tools.codex_assets import m5_runtime_receipt_producer as producer
    value.pop("execution_receipt", None)
    value.pop("evidence_sha256", None)
    value["collection"].update(source_baseline=source_baseline,
        collector_source_sha256=hashlib.sha256(Path(smoke.__file__).read_bytes()).hexdigest(),
        producer_source_sha256=hashlib.sha256(Path(producer.__file__).read_bytes()).hexdigest())
    payload = {"schema": proof.SCHEMA, "repository": "jiying2007/llm_agent", "workflow": proof.WORKFLOW,
               "ref": "refs/heads/main", "event": "workflow_dispatch", "head_sha": source_baseline,
               "run_id": 1, "run_attempt": 1, "evidence_payload_sha256": proof.measurement_digest(value)}
    value["execution_receipt"] = {"schema": proof.ENVELOPE_SCHEMA,
        "payload_base64": base64.b64encode(json.dumps(payload).encode()).decode(),
        "bundle_base64": base64.b64encode(b'{"synthetic_only":true}').decode()}
    value["evidence_sha256"] = digest(value)
    return value


def receipt(head, run_id=34703075857):
    from tools.codex_assets.m5_ci_contract import JOBS
    import json
    payload = {"schema": "llm-agent-root-ci-receipt/v1", "repository": "jiying2007/llm_agent",
               "workflow": ".github/workflows/ci.yml", "ref": "refs/heads/main", "event": "push",
               "head_sha": head, "run_id": run_id, "run_attempt": 1, "conclusion": "success",
               "jobs": dict.fromkeys(JOBS, "success")}
    return {"schema": "llm-agent-signed-ci-receipt/v1",
            "payload_base64": base64.b64encode(json.dumps(payload).encode()).decode(),
            "bundle_base64": base64.b64encode(b'{"synthetic_only":true}').decode()}


def bind_synthetic_field(root, lock):
    """Only copied test repositories may rebind generated synthetic evidence."""
    import json
    ledger_path = root / "manifests/software_m5_pilot_ledger.json"
    ledger = json.loads(ledger_path.read_text())
    ledger["candidate_version"] = lock["agent-dev-kit.version"]
    ledger_path.write_text(json.dumps(ledger, indent=2) + "\n")
    path = root / "reports/field-evidence/software-m5-independent-pilot-start-2026-09-12.json"
    evidence = json.loads(path.read_text())
    evidence["adk_source"]["commit"] = lock["agent-dev-kit.commit"]
    evidence["selftest_only"] = True
    path.write_text(json.dumps(evidence, indent=2) + "\n")
    events_path = root / ledger["event_log"]
    events = [json.loads(line) for line in events_path.read_text().splitlines() if line]
    previous = "0" * 64
    for event in events:
        event["previous_hash"] = previous
        for relative in event["evidence"]:
            event["evidence_sha256"][relative] = hashlib.sha256((root / relative).read_bytes()).hexdigest()
        event.pop("event_hash", None)
        event["event_hash"] = digest(event)
        previous = event["event_hash"]
    events_path.write_text("".join(json.dumps(event, sort_keys=True) + "\n" for event in events))
