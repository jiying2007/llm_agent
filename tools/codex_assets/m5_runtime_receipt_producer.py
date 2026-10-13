"""Collect and seal runtime evidence in one explicitly trusted manual workflow.

There is no operation that accepts an arbitrary report to create a signable
payload. Collection must complete here before a payload is emitted.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Mapping

from tools.codex_assets import m5_runtime_contract as contract
from tools.codex_assets import m5_runtime_receipt as receipt
from tools.codex_assets import m5_signature, runtime_smoke_evidence as smoke
from tools.codex_assets.intake_io import IntakeError, read_bytes, read_json, decode_json, _sha256_file


def context(environment: Mapping[str, str]) -> dict:
    expected = {"GITHUB_REPOSITORY": "jiying2007/llm_agent", "GITHUB_REF": "refs/heads/main",
                "GITHUB_EVENT_NAME": "workflow_dispatch",
                "GITHUB_WORKFLOW_REF": "jiying2007/llm_agent/" + receipt.WORKFLOW + "@refs/heads/main"}
    if any(environment.get(key) != value for key, value in expected.items()):
        raise ValueError("runtime producer requires canonical main manual workflow context")
    head = environment.get("GITHUB_SHA", "")
    if re.fullmatch(r"[0-9a-f]{40}", head) is None:
        raise ValueError("runtime producer head is invalid")
    runs = []
    for key in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"):
        value = environment.get(key, "")
        if re.fullmatch(r"[1-9][0-9]{0,19}", value) is None:
            raise ValueError("runtime producer run is invalid")
        runs.append(int(value))
    return {"schema": receipt.SCHEMA, "repository": expected["GITHUB_REPOSITORY"],
            "workflow": receipt.WORKFLOW, "ref": expected["GITHUB_REF"],
            "event": expected["GITHUB_EVENT_NAME"], "head_sha": head,
            "run_id": runs[0], "run_attempt": runs[1]}


def clean_source(root: Path, head: str) -> None:
    if Path(smoke._run_git(root, "rev-parse", "--show-toplevel")).resolve() != root.resolve():
        raise ValueError("runtime producer source is not the requested repository root")
    if smoke._run_git(root, "rev-parse", "HEAD") != head:
        raise ValueError("runtime producer source differs from workflow head")
    if smoke._run_git(root, "status", "--porcelain", "--untracked-files=all",
                      "--ignore-submodules=dirty", allow_empty=True):
        raise ValueError("runtime producer requires a clean source checkout")
    smoke._reject_hidden_index_entries(root)
    smoke._reject_ignored_executable_inputs(root)
    smoke._verify_executable_sources(root)
    # Parent status must not run a child repository's unknown filter commands.
    # Inspect the governed ADK directly with its own isolated Git configuration.
    smoke._validate_source_identity(root)


def source_hashes(root: Path) -> dict:
    return {key: hashlib.sha256(read_bytes((root / "tools/codex_assets" / filename).absolute(),
                                           label="runtime producer source", max_bytes=256 * 1024)).hexdigest()
            for key, filename in (("collector_source_sha256", "runtime_smoke_evidence.py"),
                                   ("producer_source_sha256", "m5_runtime_receipt_producer.py"))}


def outputs(*paths: Path) -> None:
    if len(set(paths)) != len(paths):
        raise ValueError("runtime outputs must be distinct")
    for path in paths:
        smoke._preflight_new_output(path)
        path.parent.mkdir(parents=True, exist_ok=True)


def collect(args) -> None:
    if not args.allow_network or not args.approve_unknown_cost:
        raise ValueError("runtime collection requires explicit network and cost authorization")
    current = context(os.environ)
    root = Path(args.root).absolute()
    clean_source(root, current["head_sha"])
    pins = source_hashes(root)
    binary = Path(args.binary).absolute()
    if re.fullmatch(r"[0-9a-f]{64}", args.binary_sha256) is None or _sha256_file(binary) != args.binary_sha256:
        raise ValueError("runtime executable differs from reviewed owner pin")
    evidence_path, raw_path, payload_path = map(lambda value: Path(value).absolute(),
                                               (args.evidence, args.raw_output, args.payload))
    if any(path.is_relative_to(root) for path in (evidence_path, raw_path, payload_path)):
        raise ValueError("runtime producer outputs must be outside the source checkout")
    outputs(evidence_path, raw_path, payload_path)
    # Fixed ADK task set and exactly one native upstream-observed request.
    evidence = smoke.collect(root, evidence_path, raw_result=None, raw_output=raw_path,
                             execute=True, model=smoke.DEFAULT_MODEL, limit=1, tasks=None,
                             runtime_binary=binary, generated_at=None, review_days=30,
                             approve_unknown_cost=True, reasoning_effort="medium",
                             observe_provider_model=True, allow_network=True)
    clean_source(root, current["head_sha"])
    if source_hashes(root) != pins or _sha256_file(binary) != args.binary_sha256:
        raise ValueError("runtime producer inputs changed during execution")
    evidence["collection"].update(pins, source_baseline=current["head_sha"])
    evidence.pop("evidence_sha256", None)
    evidence["evidence_sha256"] = contract.digest(evidence)
    lock, _, _ = smoke._validate_source_identity(root)
    contract.validate_measurement(evidence, lock, datetime.now(timezone.utc), source_root=root)
    # Update only this producer's newly created unsigned output. It is never
    # exported by the workflow; the signed output is a separate exclusive file.
    smoke._write_json(evidence_path, evidence)
    current["evidence_payload_sha256"] = receipt.measurement_digest(evidence)
    smoke._write_new_json(payload_path, current)


def envelope(args) -> None:
    current = context(os.environ)
    root = Path(args.root).absolute()
    clean_source(root, current["head_sha"])
    output = Path(args.output).absolute()
    outputs(output)
    evidence = read_json(Path(args.evidence).absolute(), label="producer runtime evidence", max_bytes=8 * 1024 * 1024)
    payload = read_bytes(Path(args.payload).absolute(), label="runtime execution payload", max_bytes=1024 * 1024)
    bundle = read_bytes(Path(args.bundle).absolute(), label="runtime execution bundle", max_bytes=4 * 1024 * 1024)
    current["evidence_payload_sha256"] = receipt.measurement_digest(evidence)
    if decode_json(payload, label="runtime execution payload") != current:
        raise ValueError("runtime payload differs from current producer context/measurement")
    if evidence.get("execution_receipt") is not None or any(evidence["collection"].get(key) != value for key, value in source_hashes(root).items()):
        raise ValueError("runtime input is sealed already or source differs")
    evidence["execution_receipt"] = {"schema": receipt.ENVELOPE_SCHEMA,
        "payload_base64": base64.b64encode(payload).decode(), "bundle_base64": base64.b64encode(bundle).decode()}
    evidence.pop("evidence_sha256", None)
    evidence["evidence_sha256"] = contract.digest(evidence)
    lock, _, _ = smoke._validate_source_identity(root)
    with m5_signature.using(m5_signature.from_arguments(args)):
        contract.validate(evidence, lock, datetime.now(timezone.utc), source_root=root,
                          expected_source_baseline=current["head_sha"])
    smoke._write_new_json(output, evidence)


def failure_summary(args) -> None:
    """Export bounded negative diagnostics, never a signable measurement."""
    current = context(os.environ)
    root = Path(args.root).resolve()
    output = Path(args.output).absolute()
    # Reject lexical links before normalization can conceal them.
    smoke._preflight_new_output(output)
    if output.resolve().is_relative_to(root):
        raise ValueError("failure summary must be outside the source checkout")
    outputs(output)
    path = Path(args.diagnostics).absolute()
    if path.is_symlink():
        raise ValueError("failure diagnostics must not be linked")
    summaries = []
    available = path.exists()
    if available:
        try:
            value = read_json(path, label="negative observer diagnostics", max_bytes=64 * 1024)
        except (OSError, IntakeError) as exc:
            raise ValueError("negative observer diagnostics cannot be safely read") from exc
        if (not isinstance(value, dict) or set(value) != {"status", "qualification", "diagnostics"}
                or value["status"] != "fail" or value["qualification"] is not False
                or not isinstance(value["diagnostics"], list) or len(value["diagnostics"]) > 1):
            raise ValueError("negative diagnostics schema is invalid")
        fields = {"status", "stages", "upstream_status", "claimed_requests", "prepared_requests",
                  "response_content_types", "observed_models", "completed"}
        stages = {"native-start", "request-validation", "request-encoding-denied", "upstream-request-sent",
                  "upstream-status-or-html-rejected", "upstream-headers", "upstream-stream"}
        for item in value["diagnostics"]:
            if (not isinstance(item, dict) or set(item) not in (fields, fields | {"identity_diagnostics"})
                    or item["status"] != "fail"):
                raise ValueError("negative observer schema is invalid")
            identity = item.get("identity_diagnostics")
            if "identity_diagnostics" in item:
                flags = {"http_model_header_present", "http_model_alias_present",
                         "sse_response_model_header_present", "sse_top_level_model_header_present",
                         "unsupported_sse_model_header_present", "response_model_field_present"}
                if (not isinstance(identity, dict) or set(identity) != flags | {"failure_kind"}
                        or any(type(identity[key]) is not bool for key in flags)
                        or not isinstance(identity["failure_kind"], str)
                        or identity["failure_kind"] not in {"response-not-completed", "missing-model-header",
                                                           "model-mismatch-or-conflict", "native-or-transport-failed"}):
                    raise ValueError("negative identity diagnostics schema is invalid")
            if (not isinstance(item["stages"], list) or len(item["stages"]) > 16
                    or any(not isinstance(s, str) or s not in stages for s in item["stages"])):
                raise ValueError("negative observer stages are invalid")
            for key in ("claimed_requests", "prepared_requests"):
                if type(item[key]) is not int or item[key] not in (0, 1):
                    raise ValueError("negative observer request count is invalid")
            statuses = item["upstream_status"]
            media = item["response_content_types"]
            models = item["observed_models"]
            if (not isinstance(statuses, list) or len(statuses) > 1
                    or any(type(s) is not int or not 100 <= s <= 599 for s in statuses)
                    or not isinstance(media, list) or len(media) > 1
                    or any(not isinstance(s, str) or s not in
                           {"text/event-stream", "application/json", "text/html", "text/plain",
                            "application/octet-stream", "binary/octet-stream", "application/x-ndjson",
                            "other-or-missing"}
                           for s in media)
                    or not isinstance(models, list) or len(models) > 16
                    or any(not isinstance(s, str) or len(s) > 128 for s in models)
                    or type(item["completed"]) is not bool):
                raise ValueError("negative observer response metadata is invalid")
            summaries.append({"stages": item["stages"], "upstream_status": statuses,
                              "claimed_requests": item["claimed_requests"],
                              "prepared_requests": item["prepared_requests"],
                              "response_content_types": media, "observed_model_count": len(models),
                              "expected_model_observed": smoke.DEFAULT_MODEL in models,
                              "completed": item["completed"]})
            if identity is not None:
                summaries[-1]["identity_diagnostics"] = identity
    version = "v2" if any("identity_diagnostics" in item for item in summaries) else "v1"
    smoke._write_new_json(output, {**current, "schema": "llm-agent-runtime-failure-summary/" + version,
                         "status": "fail", "diagnostics_available": available,
                         "diagnostics": summaries, "model_request_count_verified": False,
                         "model_retry_authorized": False, "qualification": False,
                         "software_m5_certified": False, "release_authorized": False})


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    for operation in ("collect", "envelope"):
        command = sub.add_parser(operation)
        command.add_argument("--root", required=True)
        command.add_argument("--evidence", required=True)
        command.add_argument("--payload", required=True)
        if operation == "collect":
            command.add_argument("--binary", required=True)
            command.add_argument("--binary-sha256", required=True)
            command.add_argument("--raw-output", required=True)
            command.add_argument("--allow-network", action="store_true")
            command.add_argument("--approve-unknown-cost", action="store_true")
        else:
            command.add_argument("--bundle", required=True)
            command.add_argument("--output", required=True)
            m5_signature.add_arguments(command)
    negative = sub.add_parser("failure-summary")
    negative.add_argument("--root", required=True)
    negative.add_argument("--diagnostics", required=True)
    negative.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    try:
        {"collect": collect, "envelope": envelope, "failure-summary": failure_summary}[args.operation](args)
    except (OSError, ValueError, RuntimeError, KeyError, TypeError, subprocess.SubprocessError) as exc:
        print(json.dumps({"status": "blocked", "error": str(exc), "release_authorized": False}))
        return 1
    status = {"collect": "measured-unsealed", "envelope": "signature-verified",
              "failure-summary": "negative-diagnostics-exported"}[args.operation]
    print(json.dumps({"status": status,
                      "software_m5_certified": False, "release_authorized": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
