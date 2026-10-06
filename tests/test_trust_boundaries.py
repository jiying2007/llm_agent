import json
import os
from pathlib import Path
import tempfile
import unittest
import subprocess
import sys
from unittest.mock import patch

from tools.codex_assets.runtime_security import audit, trusted_endpoint, DEFAULT_TRUSTED
from tools.control_plane.adk_promotion_evidence import verify_evidence_claims
from tools.codex_assets import intake_io as input_io

ROOT = Path(__file__).resolve().parents[1]


class EndpointTrustTest(unittest.TestCase):
    def test_configuration_preflight_error_is_normalized(self):
        with patch.object(Path, "is_symlink", side_effect=PermissionError("PRIVATE_OS_DETAIL")):
            with self.assertRaises(ValueError) as failure:
                audit(Path("unopened-fixture"), DEFAULT_TRUSTED)
        self.assertNotIn("PRIVATE_OS_DETAIL", str(failure.exception))

    def test_configuration_link_replacement_fails_without_reading_secrets(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            config = root / "config.toml"
            config.write_text('base_url="https://api.openai.com/v1"\n')
            outside = root / "private.toml"
            outside.write_text('base_url="https://secret:PRIVATE_TOKEN@api.openai.com"\n')
            original_open = os.open

            def replace_then_open(name, flags):
                config.rename(root / "old.toml")
                config.symlink_to(outside)
                return original_open(name, flags)

            with patch.object(input_io.os, "open", side_effect=replace_then_open):
                with self.assertRaises(ValueError) as failure:
                    audit(config, DEFAULT_TRUSTED)
            self.assertNotIn("PRIVATE_TOKEN", str(failure.exception))

    def test_exact_authority_and_path_boundary(self):
        self.assertTrue(trusted_endpoint("https://api.openai.com/v1", DEFAULT_TRUSTED))
        self.assertTrue(trusted_endpoint("https://API.OPENAI.COM:443/v1", DEFAULT_TRUSTED))
        for value in ("https://api.anthropic.co", "https://api", "https://api.openai.com.evil.test",
                      "https://api.openai.com:8443/v1"):
            self.assertFalse(trusted_endpoint(value, DEFAULT_TRUSTED))
        custom = ("https://proxy.example.test/v1",)
        self.assertTrue(trusted_endpoint("https://proxy.example.test/v1/chat", custom))
        self.assertFalse(trusted_endpoint("https://proxy.example.test/v10", custom))
        self.assertFalse(trusted_endpoint("https://proxy.example.test/admin", custom))

    def test_ambiguous_or_secret_endpoints_rejected(self):
        for value in ("https://user:secret@api.openai.com/v1", "https://api.openai.com/?token=secret",
                      "https://api.openai.com/#secret", "https://api.openai.com:0/v1",
                      "https://api.openai.com/v1/../admin", "https://api.openai.com/v1/%252e%252e",
                      "http://api.openai.com/v1", "https://api.openai.com/v1\\admin",
                      "\x00https://api.openai.com/v1", "https://api.openai.com/v1\x7f"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                trusted_endpoint(value, DEFAULT_TRUSTED)

    def test_nested_toml_and_redacted_diagnostics(self):
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp) / "config.toml"
            config.write_text('[model_providers.custom]\nbase_url="https://user:secret@proxy.example.test/?token=secret"\n', encoding="utf-8")
            result = audit(config, DEFAULT_TRUSTED)
            self.assertEqual("fail", result["status"])
            self.assertEqual(1, result["endpoints"])
            self.assertNotIn("secret", json.dumps(result))
            self.assertNotIn("proxy.example", json.dumps(result))
            self.assertFalse(result["network_executed"])

    def test_escaped_control_and_config_budget(self):
        with tempfile.TemporaryDirectory() as temp:
            config = Path(temp) / "config.toml"
            config.write_text('base_url="\\u0000https://api.openai.com/v1"\n', encoding="utf-8")
            self.assertEqual("fail", audit(config, DEFAULT_TRUSTED)["status"])
            config.write_bytes(b" " * (4 * 1024 * 1024 + 1))
            with self.assertRaises(ValueError):
                audit(config, DEFAULT_TRUSTED)

    def test_real_shell_security_gate_with_stubbed_external_tools(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            target = base / "target"
            target.mkdir()
            # HOME keeps its normal meaning only inside the isolated child;
            # the parent environment and real Codex installation are untouched.
            fixture_home = base / "home"
            doctor = fixture_home / "codex/scripts/doctor.sh"
            doctor.parent.mkdir(parents=True)
            doctor.write_text("#!/bin/sh\nexit 0\n")
            commands = base / "bin"
            commands.mkdir()
            bash = commands / "bash"
            bash.write_text('#!/bin/sh\ncase "$1" in */scripts/doctor.sh) printf "errors=0 warnings=0\\n" ;; *) exec /bin/bash "$@" ;; esac\n')
            bash.chmod(0o755)
            codex = commands / "codex"
            codex.write_text('#!/bin/sh\nprintf "no servers configured\\n"\n')
            codex.chmod(0o755)
            env = dict(os.environ, PATH=str(commands) + os.pathsep + os.path.dirname(sys.executable)
                       + os.pathsep + os.environ["PATH"])
            env["HOME"] = str(fixture_home)
            env.pop("CODEX_TRUSTED_BASE_URLS", None)
            config = target / "config.toml"
            for url, expected in (("https://api.anthropic.co", 3), ("https://api.openai.com/v1", 0),
                                  ("https://secret:credential@api.openai.com/v1?token=tokenvalue", 3)):
                config.write_text('base_url="' + url + '"\n')
                result = subprocess.run(["/bin/bash", str(ROOT / "scripts/check-global-codex-health.sh"),
                                         str(target), "security"], env=env, text=True, capture_output=True)
                self.assertEqual(expected, result.returncode, result.stdout + result.stderr)
                self.assertNotIn("credential", result.stdout + result.stderr)
                self.assertNotIn("tokenvalue", result.stdout + result.stderr)


class PromotionInputTest(unittest.TestCase):
    def setUp(self):
        self.evidence = json.loads((ROOT / "reports/promotion/agent-dev-kit/promotion-evidence.json").read_text())

    def verify(self, raw, interface=None, lock=None):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "evidence.json"
            path.write_text(raw, encoding="utf-8")
            return verify_evidence_claims(evidence_path=path, lock_path=lock or ROOT / "adk.lock",
                                         interface_path=interface or ROOT / "manifests/adk_interface.lock.json")

    def test_normal_canonical_evidence_preserved(self):
        self.assertEqual("pass", self.verify(json.dumps(self.evidence))["status"])

    def test_exact_integer_ids_and_workflow_identity(self):
        for key, value in (("run_id", True), ("run_attempt", True), ("workflow_sha", "0" * 40)):
            data = json.loads(json.dumps(self.evidence))
            data["source"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.verify(json.dumps(data))

    def test_duplicate_and_nonfinite_json_rejected(self):
        raw = json.dumps(self.evidence)
        for value in ('{"schema":"invalid-first",' + raw[1:],
                      '{"extra":NaN,' + raw[1:], '{"extra":1e9999,' + raw[1:]):
            with self.subTest(value=value[:30]), self.assertRaises(ValueError):
                self.verify(value)

    def test_byte_and_depth_budget_rejected(self):
        for raw in (' ' * (4 * 1024 * 1024 + 1), '[' * 65 + '0' + ']' * 65):
            with self.assertRaises(ValueError):
                self.verify(raw)

    def test_duplicate_interface_and_lock_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            interface = base / "interface.json"
            raw = (ROOT / "manifests/adk_interface.lock.json").read_text()
            interface.write_text('{"schema":"wrong",' + raw.lstrip()[1:])
            with self.assertRaises(ValueError):
                self.verify(json.dumps(self.evidence), interface=interface)
            lock = base / "adk.lock"
            lock.write_text((ROOT / "adk.lock").read_text() + "\nagent-dev-kit.version=duplicate\n")
            with self.assertRaises(ValueError):
                self.verify(json.dumps(self.evidence), lock=lock)


if __name__ == "__main__":
    unittest.main()
