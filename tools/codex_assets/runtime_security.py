"""Read-only endpoint trust audit; no provider or MCP connection is made."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from urllib.parse import urlsplit
import tomllib
from .intake_io import IntakeError, read_bytes

DEFAULT_TRUSTED = ("https://api.openai.com", "https://api.anthropic.com")
MAX_CONFIG_BYTES = 4 * 1024 * 1024


def endpoint_parts(value: str) -> tuple[str, str, int, str]:
    if (not isinstance(value, str) or not value
            or any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in value)):
        raise ValueError("invalid endpoint")
    parsed = urlsplit(value)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("HTTPS endpoint required")
    if parsed.username is not None or parsed.password is not None:
        raise ValueError("endpoint credentials forbidden")
    if parsed.query or parsed.fragment:
        raise ValueError("endpoint query or fragment forbidden")
    path = parsed.path or "/"
    if "%" in path or any(part in {".", ".."} for part in path.split("/")) or "\\" in path:
        raise ValueError("ambiguous endpoint path")
    port = 443 if parsed.port is None else parsed.port
    if port < 1:
        raise ValueError("invalid endpoint port")
    return parsed.scheme, parsed.hostname.lower(), port, path.rstrip("/") or "/"


def trusted_endpoint(value: str, trusted: tuple[str, ...]) -> bool:
    candidate = endpoint_parts(value)
    for expected in trusted:
        allowed = endpoint_parts(expected)
        if candidate[:3] == allowed[:3]:
            prefix = allowed[3]
            if prefix == "/" or candidate[3] == prefix or candidate[3].startswith(prefix + "/"):
                return True
    return False


def audit(config: Path, trusted: tuple[str, ...]) -> dict:
    # Validate all declared expectations before accepting any endpoint.
    for expected in trusted:
        endpoint_parts(expected)
    try:
        payload = read_bytes(config, label="configuration", max_bytes=MAX_CONFIG_BYTES)
    except IntakeError as exc:
        raise ValueError("invalid configuration input") from exc
    data = tomllib.loads(payload.decode("utf-8"))
    pending = [data]
    endpoints: list[object] = []
    hooks = 0
    while pending:
        item = pending.pop()
        if isinstance(item, dict):
            for key, value in item.items():
                if key in {"base_url", "OPENAI_BASE_URL", "ANTHROPIC_BASE_URL"}:
                    endpoints.append(value)
                if "hook" in key.lower():
                    hooks += 1
                if isinstance(value, (dict, list)):
                    pending.append(value)
        elif isinstance(item, list):
            pending.extend(value for value in item if isinstance(value, (dict, list)))
    failures = []
    for index, value in enumerate(endpoints):
        try:
            if not trusted_endpoint(value, trusted):
                failures.append({"index": index, "reason": "endpoint-not-trusted"})
        except (ValueError, TypeError):
            failures.append({"index": index, "reason": "invalid-endpoint"})
    # Never print URL values, credentials, query strings or raw TOML content.
    return {"schema": "llm-agent-runtime-security/v1", "read_only": True,
            "status": "fail" if failures else "pass", "endpoints": len(endpoints),
            "failures": failures, "hook_warnings": hooks, "network_executed": False}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args(argv)
    trusted = DEFAULT_TRUSTED + tuple(os.environ.get("CODEX_TRUSTED_BASE_URLS", "").split())
    try:
        result = audit(args.config, trusted)
    except (OSError, ValueError, TypeError):
        result = {"schema": "llm-agent-runtime-security/v1", "status": "fail",
                  "reason": "invalid-config-or-trust-policy", "read_only": True,
                  "network_executed": False}
    print(json.dumps(result, sort_keys=True))
    if result.get("hook_warnings", 0):
        import sys
        print("[WARN] hooks configured; declared validator/audit purpose required", file=sys.stderr)
    return 0 if result["status"] == "pass" else 3


if __name__ == "__main__":
    raise SystemExit(main())
