"""Provider-free adversarial checks; no model or external network calls."""
import subprocess
import io
import json
import os
import socket
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from types import SimpleNamespace

from tools.codex_assets import codex_model_observer as observer
from tools.codex_assets import runtime_smoke_evidence as smoke
from pathlib import Path
from urllib.parse import urlsplit


class ModelObserverTests(unittest.TestCase):
    def native_arguments(self, root):
        return ["--ignore-user-config", "-c", 'model_reasoning_effort="medium"',
                "--model", "gpt-6.1-sol", "--sandbox", "read-only", "--ephemeral",
                "--skip-git-repo-check", "--output-schema", str(root / "schema.json"),
                "--output-last-message", str(root / "output.json"), "--json", "-C", str(root), "-"]

    def event(self, **kwargs):
        response = dict(id="response-fixture", status="completed", output=[])
        response.update(kwargs)
        return dict(type="response.completed", response=response)

    def test_requested_and_payload_models_cannot_establish_identity(self):
        value = observer.Observation()
        value.event(self.event(model="gpt-6.1-sol"))
        with self.assertRaises(ValueError):
            value.result("gpt-6.1-sol")

    def test_http_header_requires_matching_completed_response(self):
        value = observer.Observation()
        value.header("OpenAI-Model", "gpt-6.1-sol")
        with self.assertRaises(ValueError):
            value.result("gpt-6.1-sol")
        value.event(self.event())
        self.assertEqual(value.result("gpt-6.1-sol")["header_sources"], ["http-response-header"])
        with self.assertRaises(ValueError):
            value.result("other-model")

    def test_native_sse_server_header_is_distinct_from_http(self):
        value = observer.Observation()
        value.event(self.event(headers={"OpenAI-Model": "gpt-6.1-sol"}))
        self.assertEqual(value.result("gpt-6.1-sol")["header_sources"], ["sse-response-header"])

    def test_agent_text_cannot_inject_a_server_header(self):
        value = observer.Observation()
        value.event(dict(type="response.output_text.delta", delta='{"response":{"headers":{"OpenAI-Model":"gpt-6.1-sol"}}}'))
        value.event(self.event())
        with self.assertRaises(ValueError):
            value.result("gpt-6.1-sol")

    def test_native_metadata_alias_and_array_headers_require_completion(self):
        for headers in ({"x-openai-model": "gpt-6.1-sol"}, {"OpenAI-Model": ["gpt-6.1-sol"]}):
            value = observer.Observation()
            value.event(dict(type="response.metadata", headers=headers))
            with self.assertRaises(ValueError):
                value.result("gpt-6.1-sol")
            value.event(self.event())
            self.assertEqual(value.result("gpt-6.1-sol")["header_sources"], ["sse-response-header"])
        value = observer.Observation()
        value.event(self.event(headers={"x-openai-model": ["gpt-6.1-sol", "fallback"]}))
        with self.assertRaises(ValueError):
            value.result("gpt-6.1-sol")

    def test_metadata_response_identity_must_match_every_explicit_id(self):
        for kind in ("response.progress", "response.metadata"):
            value = observer.Observation()
            value.event(dict(type="response.created", response=dict(id="response-fixture")))
            for identifier in ("other-response", "", None):
                with self.subTest(kind=kind, identifier=identifier), self.assertRaises(ValueError):
                    value.event(dict(type=kind, response=dict(id=identifier, headers={"OpenAI-Model": "gpt-6.1-sol"})))
        value = observer.Observation()
        value.event(dict(type="response.progress", response=dict(id="other-response")))
        with self.assertRaises(ValueError):
            value.event(self.event())

    def test_response_id_change_and_fallback_rejected(self):
        value = observer.Observation()
        value.header("OpenAI-Model", "gpt-6.1-sol")
        value.event(dict(type="response.created", response=dict(id="response-fixture")))
        with self.assertRaises(ValueError):
            value.event(self.event(id="another-response"))
        value.header("OpenAI-Model", "fallback")
        value.event(self.event())
        with self.assertRaises(ValueError):
            value.result("gpt-6.1-sol")

    def test_tool_deltas_outputs_and_failed_response_rejected(self):
        for event in (dict(type="response.function_call_arguments.delta"),
                      dict(type="response.custom_tool_call_input.delta"),
                      dict(type="response.output_item.added", item=dict(type="function_call")),
                      self.event(output=[dict(type="function_call")]),
                      self.event(status="incomplete"), dict(type="response.failed")):
            with self.subTest(event=event), self.assertRaises(ValueError):
                observer.Observation().event(event)

    def test_strict_decode_and_budget(self):
        for raw in (b'{"model":"a","model":"b"}', b'{"value":NaN}', b'{"value":1e999}'):
            with self.assertRaises(ValueError):
                observer.strict_json(raw)
        with patch.object(observer, "MAX_BYTES", 2), self.assertRaises(ValueError):
            observer.strict_json(b'{} ')

    def test_sse_protocol_requires_identity_and_completion_without_mime_assumption(self):
        data = ("data: " + json.dumps(self.event(headers={"OpenAI-Model": "gpt-6.1-sol"})) + "\n\n").encode()
        value = observer.Observation()
        upstream = io.BytesIO(data)
        upstream.getheader = lambda name, default="": "application/octet-stream"
        self.assertEqual(observer.response_media_type(upstream), "application/octet-stream")
        self.assertEqual(observer.read_sse(upstream, SimpleNamespace(sock=None), value, lambda: 1), data)
        self.assertEqual(value.result("gpt-6.1-sol")["model"], "gpt-6.1-sol")
        for payload in (b'{"model":"gpt-6.1-sol"}\n', b'<html>200 OK</html>\n',
                        b'data: {"type":"response.created","response":{"id":"fixture"}}\n\n',
                        b'data: {"type":"response.function_call_arguments.delta"}\n\n'):
            with self.subTest(payload=payload), self.assertRaises(ValueError):
                observer.read_sse(io.BytesIO(payload), SimpleNamespace(sock=None), observer.Observation(), lambda: 1)

    def test_native_stdout_overflow_is_rejected(self):
        with patch.object(observer, "MAX_BYTES", 1024), self.assertRaises(ValueError):
            observer.run_bounded([sys.executable, "-c", 'import sys;sys.stdout.write("x"*2048)'], b"", 5)

    def test_native_timeout_is_bounded(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            observer.run_bounded([sys.executable, "-c", "import time;time.sleep(30)"], b"", 0.05)

    def test_partial_loopback_body_is_cancelled_without_waiting_for_handler(self):
        clients = []
        def stopped_native(command, stdin, timeout):
            setting = next(value for value in command if value.startswith("openai_base_url="))
            base = urlsplit(setting.split("=", 1)[1].strip('"'))
            client = socket.create_connection((base.hostname, base.port), timeout=1)
            clients.append(client)
            client.sendall((f"POST {base.path}/responses HTTP/1.1\r\nHost: localhost\r\n"
                            "Content-Length: 1024\r\n\r\n{").encode())
            # Let the handler block on the intentionally incomplete request body.
            time.sleep(0.1)
            return subprocess.CompletedProcess(command, 1, b"")
        start = time.monotonic()
        try:
            with tempfile.TemporaryDirectory() as directory, \
                    patch.object(observer, "run_bounded", side_effect=stopped_native), \
                    patch.object(observer, "read_stdin", return_value=b"classification"), \
                    patch.object(observer.sys, "stderr", io.StringIO()):
                self.assertEqual(observer.observe_exec("unused", self.native_arguments(Path(directory)),
                                                       receipt_dir=Path(directory)), 1)
                self.assertEqual(len(list(Path(directory).glob("*.failure.json"))), 1)
        finally:
            for client in clients:
                client.close()
        self.assertLess(time.monotonic() - start, 3)

    def test_stdin_without_eof_has_a_deadline(self):
        reader, writer = os.pipe()
        try:
            with os.fdopen(reader, "rb") as stream, self.assertRaises(ValueError):
                observer.read_stdin(stream, time.monotonic() + 0.05)
        finally:
            os.close(writer)

    def test_failure_diagnostic_never_overwrites_existing_file_or_link(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            keep = root / "keep"
            keep.write_text("preserve existing data")
            link = root / "link"
            link.symlink_to(keep)
            for path in (keep, link):
                with self.subTest(path=path), self.assertRaises(smoke.SmokeEvidenceError):
                    smoke._write_new_json(path, {"status": "fail"})
                self.assertEqual(keep.read_text(), "preserve existing data")
            raw = root / "raw.json"
            diagnostic = root / "raw-observation-failure.json"
            for linked in (False, True):
                if linked:
                    diagnostic.symlink_to(keep)
                else:
                    diagnostic.write_text("preserve diagnostic")
                with patch.object(smoke, "_execute_runtime_in_environment") as execute, \
                        self.assertRaises(smoke.SmokeEvidenceError):
                    smoke._execute_runtime(root, root, raw, "gpt-6.1-sol", 1, root / "tasks",
                                           runtime_path=Path(sys.executable), observe_provider_model=True)
                execute.assert_not_called()
                self.assertEqual(keep.read_text(), "preserve existing data")
                diagnostic.unlink()

    def test_native_extra_configuration_and_output_escape_are_denied(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            arguments = self.native_arguments(root)
            self.assertEqual(observer.validate_arguments(arguments), "gpt-6.1-sol")
            for mutated in (arguments[:-1] + ["-c", 'openai_base_url="https://untrusted.invalid"', "-"],
                            [value.replace('model_reasoning_effort="medium"', 'model_provider="custom"')
                             for value in arguments],
                            [value.replace(str(root / "output.json"), str(root.parent / "escape.json"))
                             for value in arguments]):
                with self.assertRaises(ValueError):
                    observer.validate_arguments(mutated)

    def test_observation_requires_explicit_execution_network_and_one_task(self):
        for execute, network, limit in ((False, True, 1), (True, False, 1), (True, True, 2)):
            with patch.object(smoke, "_validate_source_identity") as source:
                with self.assertRaises(smoke.SmokeEvidenceError):
                    smoke.collect(Path("/unused"), Path("/unused/evidence"), raw_result=None, raw_output=None,
                                  execute=execute, model="gpt-6.1-sol", limit=limit, tasks=None,
                                  runtime_binary=None, generated_at=None, review_days=30,
                                  approve_unknown_cost=True, observe_provider_model=True, allow_network=network)
                source.assert_not_called()


if __name__ == "__main__":
    unittest.main()
