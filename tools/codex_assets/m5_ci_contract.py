"""Signed root-CI receipts; a user supplied run number is not evidence."""

from __future__ import annotations

import base64
import hashlib
import re
from typing import Any, Mapping

from tools.codex_assets.intake_io import decode_json
from tools.codex_assets.m5_signature import verify

JOBS = {"contract", "doc-sync", "integration", "integration-summary"}


def validate_receipt(envelope: Mapping[str, Any], *, head: str, run_id: int) -> dict[str, Any]:
    if not isinstance(envelope, dict) or envelope.get("schema") != "llm-agent-signed-ci-receipt/v1":
        raise ValueError("signed root CI receipt is required")
    if type(run_id) is not int or run_id <= 0 or not isinstance(head, str) or re.fullmatch(r"[0-9a-f]{40}", head) is None:
        raise ValueError("root CI run/head identity is invalid")
    for key in ("payload_base64", "bundle_base64"):
        if not isinstance(envelope.get(key), str) or len(envelope[key]) > 6 * 1024 * 1024:
            raise ValueError("signed CI receipt exceeds input budget")
    payload = base64.b64decode(envelope["payload_base64"], validate=True)
    bundle = base64.b64decode(envelope["bundle_base64"], validate=True)
    receipt = decode_json(payload, label="root CI receipt")
    decode_json(bundle, label="root CI Sigstore bundle")
    if not isinstance(receipt, dict) or receipt.get("schema") != "llm-agent-root-ci-receipt/v1":
        raise ValueError("root CI receipt payload schema is invalid")
    expected = {"repository": "jiying2007/llm_agent", "workflow": ".github/workflows/ci.yml",
                "ref": "refs/heads/main", "event": "push", "head_sha": head,
                "run_id": run_id, "conclusion": "success"}
    if any(receipt.get(key) != value for key, value in expected.items()) or type(receipt.get("run_id")) is not int:
        raise ValueError("root CI repository/workflow/event/head/run binding is invalid")
    if type(receipt.get("run_attempt")) is not int or receipt["run_attempt"] <= 0:
        raise ValueError("root CI attempt is invalid")
    jobs = receipt.get("jobs")
    if not isinstance(jobs, dict) or set(jobs) != JOBS or any(value != "success" for value in jobs.values()):
        raise ValueError("root CI required job conclusions are incomplete")
    verify(payload, bundle, repository="jiying2007/llm_agent")
    return {**expected, "run_attempt": receipt["run_attempt"], "jobs": jobs,
            "receipt_sha256": hashlib.sha256(payload).hexdigest()}


def validate_record(record: Mapping[str, Any], lock: Mapping[str, str]) -> None:
    adk = record.get("adk")
    if not isinstance(adk, dict) or any(adk.get(key) != lock.get("agent-dev-kit." + key)
                                        for key in ("version", "commit", "tree", "manifest_blob")):
        raise ValueError("qualification ADK identity differs from lock")
    runs = record.get("required_runs")
    if not isinstance(runs, list) or len(runs) != 2 or any(not isinstance(run, dict) for run in runs):
        raise ValueError("qualification requires exactly the ADK promotion and signed root CI runs")
    promotion, root = runs
    if (promotion.get("repository") != "jiying2007/agent-dev-kit"
            or promotion.get("head_sha") != adk["commit"] or promotion.get("conclusion") != "success"
            or type(promotion.get("run_id")) is not int or promotion["run_id"] <= 0
            or promotion["run_id"] != adk.get("promotion_run_id")):
        raise ValueError("ADK CI promotion run binding is invalid")
    trusted = validate_receipt(record.get("root_ci_receipt"), head=record.get("source_baseline"), run_id=root.get("run_id"))
    if any(root.get(key) != value for key, value in trusted.items()):
        raise ValueError("root CI run does not match signed receipt")
