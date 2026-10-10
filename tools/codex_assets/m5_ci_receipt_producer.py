"""Produce CI payloads from trusted main-push workflow context; never certify."""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
from pathlib import Path
from typing import Mapping, Sequence

from tools.codex_assets.intake_io import read_bytes, decode_json
from tools.codex_assets.m5_ci_contract import JOBS


def payload(environment: Mapping[str, str]) -> dict:
    expected = {"GITHUB_REPOSITORY": "jiying2007/llm_agent", "GITHUB_EVENT_NAME": "push",
                "GITHUB_REF": "refs/heads/main",
                "GITHUB_WORKFLOW_REF": "jiying2007/llm_agent/.github/workflows/ci.yml@refs/heads/main"}
    if any(environment.get(key) != value for key, value in expected.items()):
        raise ValueError("CI receipt requires canonical trusted main push workflow context")
    head = environment.get("GITHUB_SHA", "")
    if re.fullmatch(r"[0-9a-f]{40}", head) is None:
        raise ValueError("CI head SHA is invalid")
    integers = []
    for key in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"):
        value = environment.get(key, "")
        if re.fullmatch(r"[1-9][0-9]{0,19}", value) is None:
            raise ValueError("CI run/attempt is invalid")
        integers.append(int(value))
    jobs = {job: environment.get("M5_JOB_" + job.upper().replace("-", "_")) for job in JOBS}
    if any(value != "success" for value in jobs.values()):
        raise ValueError("CI receipt requires every required job to succeed")
    return {"schema": "llm-agent-root-ci-receipt/v1", "repository": expected["GITHUB_REPOSITORY"],
            "workflow": ".github/workflows/ci.yml", "ref": expected["GITHUB_REF"], "event": "push",
            "head_sha": head, "run_id": integers[0], "run_attempt": integers[1],
            "conclusion": "success", "jobs": jobs}


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("payload", "envelope"))
    parser.add_argument("--output", required=True)
    parser.add_argument("--payload")
    parser.add_argument("--bundle")
    args = parser.parse_args(argv)
    try:
        # Both operations are restricted to the producer's trusted trigger.
        current = payload(os.environ)
        if args.operation == "payload":
            value = current
        else:
            if not args.payload or not args.bundle:
                raise ValueError("--payload and --bundle are required")
            raw = read_bytes(Path(args.payload).absolute(), label="CI payload", max_bytes=1024 * 1024)
            bundle = read_bytes(Path(args.bundle).absolute(), label="CI bundle", max_bytes=4 * 1024 * 1024)
            if decode_json(raw, label="CI payload") != current or not isinstance(decode_json(bundle, label="CI bundle"), dict):
                raise ValueError("CI payload differs from trusted producer context")
            value = {"schema": "llm-agent-signed-ci-receipt/v1",
                     "payload_base64": base64.b64encode(raw).decode(),
                     "bundle_base64": base64.b64encode(bundle).decode()}
        output = Path(args.output).absolute()
        if output.exists() or output.is_symlink() or any(parent.is_symlink() for parent in output.parents):
            raise ValueError("CI output must be a new path without symbolic links")
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("x", encoding="utf-8") as stream:
            stream.write(json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n")
    except (ValueError, OSError, RuntimeError) as exc:
        print(json.dumps({"status": "blocked", "error": str(exc)}))
        return 1
    print(json.dumps({"status": "artifact-created", "software_m5_certified": False, "release_authorized": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
