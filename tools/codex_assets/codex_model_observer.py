"""Bounded loopback relay for native Codex provider-model observations.

Credentials and response content remain in memory. Only the upstream server's
OpenAI-Model header is an observation; request/config/payload model is ignored.
"""
from __future__ import annotations

import argparse
import hashlib
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import secrets
import select
import socket
import ssl
import subprocess
import sys
import threading
import time

MAX_BYTES = 8 * 1024 * 1024
UPSTREAM_HOST = "chatgpt.com"
UPSTREAM_PATH = "/backend-api/codex/responses"


def response_media_type(upstream):
    value = upstream.getheader("Content-Type", "").split(";", 1)[0].strip().lower()
    allowed = {"text/event-stream", "application/json", "text/plain", "text/html",
               "application/octet-stream", "binary/octet-stream", "application/x-ndjson"}
    return value if value in allowed else "other-or-missing"


def read_sse(upstream, connection, observation, remaining):
    """Validate the actual event stream, independently of its MIME label."""
    chunks = []
    count = 0
    while not observation.completed:
        block = []
        while True:
            if connection.sock is not None:
                connection.sock.settimeout(remaining())
            else:
                remaining()
            line = upstream.readline(MAX_BYTES + 1)
            if not line:
                raise ValueError("incomplete upstream stream")
            count += len(line)
            if count > MAX_BYTES:
                raise ValueError("response byte budget exceeded")
            block.append(line)
            if not line.strip():
                break
        payload = b"\n".join(line[5:].strip() for line in block if line.startswith(b"data:"))
        if payload and payload != b"[DONE]":
            observation.event(strict_json(payload))
        chunks.extend(block)
    return b"".join(chunks)


def strict_json(raw: bytes):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate field")
            result[key] = value
        return result
    def nonfinite(value):
        raise ValueError("non-finite number")
    def finite(value):
        number = float(value)
        if not math.isfinite(number):
            raise ValueError("non-finite number")
        return number
    if len(raw) > MAX_BYTES:
        raise ValueError("byte budget exceeded")
    return json.loads(raw, object_pairs_hook=unique, parse_constant=nonfinite, parse_float=finite)


class Observation:
    def __init__(self):
        self.response_id = None
        self.models = set()
        self.completed = False
        self.sources = set()

    def header(self, name, value, *, source="http-response-header"):
        if name.lower() == "openai-model" or (source == "sse-response-header" and name.lower() == "x-openai-model"):
            if isinstance(value, list) and source == "sse-response-header":
                if not 0 < len(value) <= 8 or not all(isinstance(item, str) for item in value):
                    raise ValueError("invalid upstream model header")
                for item in value:
                    self.header(name, item, source=source)
                return
            if not isinstance(value, str) or re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}", value) is None:
                raise ValueError("invalid upstream model header")
            self.models.add(value)
            self.sources.add(source)

    def event(self, value):
        if not isinstance(value, dict):
            raise ValueError("invalid upstream event")
        kind = value.get("type", "")
        if not isinstance(kind, str) or any(part in kind for part in ("tool", "function_call", "computer", "web_search")):
            raise ValueError("tool event denied")
        if kind in {"error", "response.failed", "response.incomplete"}:
            raise ValueError("upstream failed")
        item = value.get("item")
        if isinstance(item, dict) and item.get("type") not in {"message", "reasoning"}:
            raise ValueError("tool output denied")
        response = value.get("response")
        if isinstance(response, dict):
            if "id" in response:
                identifier = response["id"]
                if not isinstance(identifier, str) or not identifier or len(identifier) > 256:
                    raise ValueError("invalid upstream response identity")
                if self.response_id is not None and self.response_id != identifier:
                    raise ValueError("upstream response identity changed")
                self.response_id = identifier
            headers = response.get("headers", {})
            if not isinstance(headers, dict):
                raise ValueError("invalid upstream headers")
            for name, header in headers.items():
                self.header(name, header, source="sse-response-header")
        if kind == "response.metadata":
            headers = value.get("headers", {})
            if not isinstance(headers, dict):
                raise ValueError("invalid upstream headers")
            for name, header in headers.items():
                self.header(name, header, source="sse-response-header")
        if value.get("type") in {"response.created", "response.completed"} and isinstance(response, dict):
            identifier = response.get("id")
            if not isinstance(identifier, str) or not identifier or len(identifier) > 256:
                raise ValueError("missing upstream response identity")
            if self.response_id is not None and self.response_id != identifier:
                raise ValueError("upstream response identity changed")
            self.response_id = identifier
            if value["type"] == "response.completed":
                if response.get("status", "completed") != "completed":
                    raise ValueError("upstream response did not complete")
                for output in response.get("output", []):
                    if not isinstance(output, dict) or output.get("type") not in {"message", "reasoning"}:
                        raise ValueError("tool output denied")
                self.completed = True

    def result(self, expected_model):
        if not self.completed or not self.response_id or self.models != {expected_model}:
            raise ValueError("no matching completed upstream server-model observation")
        return {"scope": "upstream-response-openai-model-header", "model": expected_model,
                "header_sources": sorted(self.sources),
                "response_id": self.response_id, "completed": True}


def validate_arguments(arguments):
    """Allow only the pinned evaluator's read-only invocation shape."""
    flags = {"--ignore-user-config", "--ephemeral", "--skip-git-repo-check", "--json", "-"}
    values = {"--model", "--sandbox", "--output-schema", "--output-last-message", "-C", "-c"}
    seen = {}
    index = 0
    while index < len(arguments):
        name = arguments[index]
        if name in seen or name not in flags | values:
            raise ValueError("native option denied")
        index += 1
        if name in values:
            if index == len(arguments):
                raise ValueError("native option value missing")
            seen[name] = arguments[index]
            index += 1
        else:
            seen[name] = True
    if set(seen) != flags | values or seen["--sandbox"] != "read-only" or arguments[-1:] != ["-"]:
        raise ValueError("native invocation shape denied")
    if re.fullmatch(r'model_reasoning_effort="(?:low|medium|high|xhigh|max)"', seen["-c"]) is None:
        raise ValueError("native config override denied")
    workspace = Path(seen["-C"]).absolute()
    for name in ("--output-schema", "--output-last-message"):
        target = Path(seen[name]).absolute()
        if target.parent != workspace or target.is_symlink() or any(parent.is_symlink() for parent in target.parents):
            raise ValueError("native output path denied")
    return seen["--model"]


def observe_exec(binary: str, arguments: list[str], *, receipt_dir: Path) -> int:
    model = validate_arguments(arguments)
    observation = Observation()
    capability = secrets.token_urlsafe(32)
    failures = []
    request_digests = []
    request_claimed = []
    stages = ["native-start"]
    upstream_status = []
    content_types = []
    deadline = time.monotonic() + 180
    connections = []
    guard = threading.Lock()
    closing = threading.Event()

    def remaining():
        duration = deadline - time.monotonic()
        if duration <= 0:
            raise ValueError("observation deadline exceeded")
        return min(duration, 15)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            connection = None
            try:
                self.connection.settimeout(remaining())
                with guard:
                    if closing.is_set():
                        raise ValueError("observation closing")
                    connections.append(self.connection)
                with guard:
                    if self.path != "/" + capability + "/responses" or request_claimed:
                        raise ValueError("route or request budget denied")
                    request_claimed.append(True)
                stages.append("request-validation")
                if self.headers.get("Transfer-Encoding") or self.headers.get("Content-Encoding"):
                    stages.append("request-encoding-denied")
                    raise ValueError("encoded request denied")
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= MAX_BYTES:
                    raise ValueError("request byte budget denied")
                body = strict_json(self.rfile.read(size))
                if not isinstance(body, dict) or body.get("model") != model or body.get("stream") is not True:
                    raise ValueError("unexpected request identity")
                # Classification tasks require no tools. Enforce this before inference.
                body["tools"] = []
                body.pop("tool_choice", None)
                body["store"] = False
                encoded = json.dumps(body, separators=(",", ":")).encode()
                request_digests.append(hashlib.sha256(encoded).hexdigest())
                headers = {name: value for name, value in self.headers.items()
                           if name.lower() not in {"host", "content-length", "connection", "accept-encoding", "transfer-encoding"}}
                headers["Accept-Encoding"] = "identity"
                connection = http.client.HTTPSConnection(UPSTREAM_HOST, context=ssl.create_default_context(), timeout=remaining())
                with guard:
                    if closing.is_set():
                        raise ValueError("observation closing")
                    connections.append(connection)
                connection.request("POST", UPSTREAM_PATH, encoded, headers)
                stages.append("upstream-request-sent")
                upstream = connection.getresponse()
                upstream_status.append(upstream.status)
                content_types.append(response_media_type(upstream))
                if upstream.status != 200 or content_types[-1] == "text/html":
                    stages.append("upstream-status-or-html-rejected")
                    raise ValueError("upstream response rejected")
                stages.append("upstream-headers")
                for name, value in upstream.getheaders():
                    observation.header(name, value)
                stages.append("upstream-stream")
                # Buffer this small classification stream: inspect before any tool event reaches Codex.
                data = read_sse(upstream, connection, observation, remaining)
                observation.result(model)
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except (ValueError, OSError, http.client.HTTPException, KeyError, TypeError):
                failures.append("upstream observation rejected")
                try:
                    self.send_error(502, "upstream observation rejected")
                except OSError:
                    pass
            finally:
                if connection is not None:
                    connection.close()

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    server.block_on_close = False
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    base = f"http://127.0.0.1:{server.server_port}/{capability}"
    overrides = ["-c", f'openai_base_url="{base}"',
                 "-c", "features.enable_request_compression=false",
                 "-c", "features.unbounded_connection_retries=false"]
    try:
        stdin = read_stdin(sys.stdin.buffer, deadline)
        process = run_bounded([binary, "exec", *overrides, *arguments], stdin, max(0.01, deadline - time.monotonic()))
        if process.returncode or failures or len(request_digests) != 1:
            raise ValueError("native Codex or upstream observation failed")
        record = observation.result(model)
        record["request_sha256"] = request_digests[0]
        record["upstream"] = "https://" + UPSTREAM_HOST + UPSTREAM_PATH
        record["tools_disabled"] = True
        receipt_dir.mkdir(parents=True, exist_ok=True)
        (receipt_dir / (secrets.token_hex(12) + ".json")).write_text(json.dumps(record) + "\n")
        sys.stdout.buffer.write(process.stdout)
        sys.stdout.buffer.write((json.dumps(dict(type="m5.provider-model-observed", **record)) + "\n").encode())
        return 0
    except (ValueError, OSError, subprocess.SubprocessError):
        receipt_dir.mkdir(parents=True, exist_ok=True)
        (receipt_dir / (secrets.token_hex(12) + ".failure.json")).write_text(json.dumps({
            "status": "fail", "stages": stages, "upstream_status": upstream_status,
            "claimed_requests": len(request_claimed), "prepared_requests": len(request_digests),
            "response_content_types": content_types,
            "observed_models": sorted(observation.models), "completed": observation.completed}) + "\n")
        print("[FAIL] native provider model observation unavailable", file=sys.stderr)
        return 1
    finally:
        with guard:
            closing.set()
            for connection in connections:
                sock = connection if isinstance(connection, socket.socket) else connection.sock
                if sock is not None:
                    try:
                        sock.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass
                    sock.close()
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)


def read_stdin(stream, deadline):
    descriptor = stream.fileno()
    data = bytearray()
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([descriptor], [], [], remaining)[0]:
            raise ValueError("stdin deadline exceeded")
        chunk = os.read(descriptor, min(65536, MAX_BYTES + 1 - len(data)))
        if not chunk:
            return bytes(data)
        data.extend(chunk)
        if len(data) > MAX_BYTES:
            raise ValueError("stdin byte budget exceeded")


def run_bounded(command, stdin, timeout):
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    output = bytearray()
    failed = threading.Event()

    def read():
        try:
            while chunk := process.stdout.read1(65536):
                if len(output) + len(chunk) > MAX_BYTES:
                    failed.set()
                    process.kill()
                    break
                output.extend(chunk)
        except OSError:
            failed.set()

    def write():
        try:
            process.stdin.write(stdin)
            process.stdin.close()
        except OSError:
            failed.set()

    reader = threading.Thread(target=read, daemon=True)
    writer = threading.Thread(target=write, daemon=True)
    reader.start()
    writer.start()
    try:
        process.wait(timeout=timeout)
        reader.join(timeout=1)
        writer.join(timeout=1)
        if failed.is_set() or reader.is_alive() or writer.is_alive():
            raise ValueError("native standard stream budget or lifecycle failed")
        return subprocess.CompletedProcess(command, process.returncode, bytes(output))
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=2)
        reader.join(timeout=1)
        writer.join(timeout=1)
        # Killing the child releases its pipe ends before closing ours.
        if not reader.is_alive():
            process.stdout.close()
        if not writer.is_alive():
            process.stdin.close()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-network", action="store_true")
    parser.add_argument("--binary", required=True)
    parser.add_argument("--receipt-dir", required=True)
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if not args.allow_network:
        parser.error("explicit --allow-network required")
    arguments = args.arguments[1:] if args.arguments[:1] == ["--"] else args.arguments
    return observe_exec(args.binary, arguments, receipt_dir=Path(args.receipt_dir))


if __name__ == "__main__":
    raise SystemExit(main())
