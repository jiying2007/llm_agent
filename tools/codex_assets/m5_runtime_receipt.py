"""Authenticate measured runtime provenance, separately from report consistency."""
from __future__ import annotations

import base64
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Mapping

from tools.codex_assets.intake_io import decode_json, read_bytes
from tools.codex_assets.m5_signature import verify as signature_verify

SCHEMA = "llm-agent-runtime-execution-receipt/v1"
ENVELOPE_SCHEMA = "llm-agent-signed-runtime-execution/v1"
WORKFLOW = ".github/workflows/software-m5-runtime.yml"
PAYLOAD_KEYS = {"schema", "repository", "workflow", "ref", "event", "head_sha",
                "run_id", "run_attempt", "evidence_payload_sha256"}


def measurement_digest(evidence: Mapping[str, Any]) -> str:
    unsigned = {key: value for key, value in evidence.items()
                if key not in {"execution_receipt", "evidence_sha256"}}
    return hashlib.sha256(json.dumps(unsigned, ensure_ascii=False, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()


def validate(evidence: Mapping[str, Any], *, source_root: Path | None = None,
             expected_source_baseline: str | None = None) -> dict[str, Any]:
    envelope = evidence.get("execution_receipt")
    if not isinstance(envelope, dict) or set(envelope) != {"schema", "payload_base64", "bundle_base64"} or envelope.get("schema") != ENVELOPE_SCHEMA:
        raise ValueError("authenticated runtime execution receipt is required")
    for key in ("payload_base64", "bundle_base64"):
        if not isinstance(envelope[key], str) or len(envelope[key]) > 6 * 1024 * 1024:
            raise ValueError("runtime execution envelope exceeds input budget")
    payload = base64.b64decode(envelope["payload_base64"], validate=True)
    bundle = base64.b64decode(envelope["bundle_base64"], validate=True)
    value = decode_json(payload, label="runtime execution receipt")
    if not isinstance(value, dict) or set(value) != PAYLOAD_KEYS:
        raise ValueError("runtime execution receipt fields are invalid")
    expected = {"schema": SCHEMA, "repository": "jiying2007/llm_agent", "workflow": WORKFLOW,
                "ref": "refs/heads/main", "event": "workflow_dispatch",
                "evidence_payload_sha256": measurement_digest(evidence)}
    if any(value.get(key) != item for key, item in expected.items()):
        raise ValueError("runtime execution receipt identity or measurement digest differs")
    head = value.get("head_sha")
    if not isinstance(head, str) or re.fullmatch(r"[0-9a-f]{40}", head) is None:
        raise ValueError("runtime execution source baseline is invalid")
    if expected_source_baseline is not None and head != expected_source_baseline:
        raise ValueError("runtime execution source baseline differs from signed root CI")
    if any(type(value.get(key)) is not int or value[key] <= 0 for key in ("run_id", "run_attempt")):
        raise ValueError("runtime execution run identity is invalid")
    collection = evidence.get("collection", {})
    if collection.get("source_baseline") != head:
        raise ValueError("runtime collection source baseline differs from execution receipt")
    for filename, key in (("runtime_smoke_evidence.py", "collector_source_sha256"),
                          ("m5_runtime_receipt_producer.py", "producer_source_sha256")):
        pin = collection.get(key)
        if not isinstance(pin, str) or re.fullmatch(r"[0-9a-f]{64}", pin) is None:
            raise ValueError("runtime collection source digest is invalid")
        if source_root is not None:
            raw = read_bytes((source_root / "tools/codex_assets" / filename).absolute(),
                             label="runtime provenance source", max_bytes=256 * 1024)
            if hashlib.sha256(raw).hexdigest() != pin:
                raise ValueError("runtime collection source differs from current source")
    if not isinstance(decode_json(bundle, label="runtime execution Sigstore bundle"), dict):
        raise ValueError("runtime execution Sigstore bundle is invalid")
    signature_verify(payload, bundle, repository="jiying2007/llm_agent", workflow="software-m5-runtime.yml")
    return value
