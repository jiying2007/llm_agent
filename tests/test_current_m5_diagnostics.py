"""Current-candidate diagnostics stay read-only and reject unsafe evidence."""

import hashlib
import copy
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.codex_assets import software_m5_diagnostics as diagnostic
from tools.codex_assets import software_m5_v3_core as core
from tools.codex_assets import software_m5_v3 as certifier

ROOT = Path(__file__).resolve().parents[1]


class CurrentM5DiagnosticsTests(unittest.TestCase):
    def field_fixture(self, root):
        paths = ["manifests/software_m5_pilot_ledger.json", "manifests/gitlinks.json",
                 "manifests/reference_pins.json", "reports/field-evidence/software-m5-v5-events.jsonl"]
        events = core._read_events(ROOT, ROOT / paths[-1])
        paths.extend(relative for event in events for relative in event["evidence"])
        for relative in paths:
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, destination)
        return core._load_object(ROOT / "manifests/software_m5_policy.json", "policy")

    def test_historical_field_is_not_a_current_candidate_pass(self):
        result = diagnostic.diagnose(ROOT, signature_verifier=lambda: {"status": "verified"})
        self.assertIn("field", result["blocking_gates"])
        self.assertIn("candidate version", result["stages"]["field"]["reason"])
        self.assertFalse(any("verify actual promotion" in action for action in result["next_actions"]))

    def test_field_candidate_version_and_commit_are_both_required(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            policy = self.field_fixture(root)
            self.assertEqual("pass", certifier._validate_field(root, policy)["status"])
            current = copy.deepcopy(policy)
            current["release"]["candidate_version"] = "8.0.5"
            current["release"]["candidate_commit"] = "a" * 40
            with self.assertRaisesRegex(core.M5Error, "candidate version"):
                certifier._validate_field(root, current)
            ledger_path = root / "manifests/software_m5_pilot_ledger.json"
            ledger = json.loads(ledger_path.read_text())
            ledger["candidate_version"] = "8.0.5"
            ledger_path.write_text(json.dumps(ledger))
            with self.assertRaisesRegex(core.M5Error, "candidate/repository identity"):
                certifier._validate_field(root, current)
            from m5_fixtures import bind_synthetic_field
            bind_synthetic_field(root, {"agent-dev-kit.version": "8.0.5", "agent-dev-kit.commit": "a" * 40})
            self.assertEqual("pass", certifier._validate_field(root, current)["status"])

    def test_candidate_and_reference_identity_cannot_be_spliced_across_evidence(self):
        policy = core._load_object(ROOT / "manifests/software_m5_policy.json", "policy")
        original = core._load_object(ROOT / "reports/field-evidence/software-m5-independent-pilot-start-2026-09-12.json", "pilot")
        pin = certifier._reference_repo_pins(ROOT)["digital-worker"]
        event = dict(pilot_id=original["pilot_id"], operator_id="operator-primary", repository_id="digital-worker",
                     evidence=["old.json", "wrong-repository.json"])
        old = copy.deepcopy(original)
        old["adk_source"]["commit"] = "b" * 40
        wrong = copy.deepcopy(original)
        wrong["pilot_repository"]["commit"] = "c" * 40
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "old.json").write_text(json.dumps(old))
            (root / "wrong-repository.json").write_text(json.dumps(wrong))
            self.assertFalse(certifier._pilot_start_matches_pin(root, event, "digital-worker", "digital-worker", pin, policy))

    def test_verified_signature_does_not_certify_missing_runtime_or_qualification(self):
        result = diagnostic.diagnose(ROOT, signature_verifier=lambda: {"status": "verified"})
        self.assertEqual("pass", result["stages"]["promotion_signature"]["status"])
        self.assertIn("runtime", result["blocking_gates"])
        self.assertIn("qualification", result["blocking_gates"])
        self.assertFalse(result["software_m5_certified"])
        self.assertFalse(result["release_authorized"])

    def test_signature_failure_remains_a_blocker(self):
        def failure():
            raise core.M5Error("signature mismatch")
        result = diagnostic.diagnose(ROOT, signature_verifier=failure)
        self.assertIn("promotion_signature", result["blocking_gates"])
        self.assertEqual("fail", result["stages"]["promotion_signature"]["status"])

    def test_wrong_verifier_pin_is_rejected_before_execution(self):
        with tempfile.TemporaryDirectory() as temp:
            binary = Path(temp) / "cosign"
            trust = Path(temp) / "root.json"
            binary.write_bytes(b"synthetic")
            trust.write_bytes(b"{}")
            with mock.patch("subprocess.run", side_effect=AssertionError("must not run")):
                with self.assertRaises(core.M5Error):
                    diagnostic._verify_signature(ROOT, binary, "0" * 64, trust, "0" * 64)

    def test_actual_diagnostics_preserve_history_and_do_not_certify(self):
        paths = [ROOT / "manifests/software_m5_policy.json", ROOT / "manifests/product_maturity_scorecard.json",
                 ROOT / "reports/runtime-evidence/software-m5-production-qualification-2026-09-12.json"]
        before = [hashlib.sha256(path.read_bytes()).hexdigest() for path in paths]
        with mock.patch("subprocess.Popen", side_effect=AssertionError("external process")):
            result = diagnostic.diagnose(ROOT)
        self.assertEqual("blocked", result["status"])
        self.assertFalse(result["software_m5_certified"])
        self.assertFalse(result["release_authorized"])
        self.assertEqual(0, result["model_invocations"])
        self.assertIn("runtime", result["blocking_gates"])
        self.assertIn("qualification", result["blocking_gates"])
        self.assertEqual(before, [hashlib.sha256(path.read_bytes()).hexdigest() for path in paths])

    def test_duplicate_nonfinite_and_overflow_json_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "evidence.json"
            for text in ('{"a":1,"a":2}', '{"a":NaN}', '{"a":1e999}'):
                path.write_text(text)
                with self.assertRaises(core.M5Error):
                    core._load_object(path, "fixture")

    def test_leaf_link_is_not_resolved_before_strict_read(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            target = root / "target.json"
            target.write_text('{}')
            link = root / "link.json"
            link.symlink_to(target)
            path = core._repo_path(root, "link.json", "fixture")
            self.assertEqual(link, path)
            with self.assertRaises(core.M5Error):
                core._load_object(path, "fixture")

    @unittest.skipUnless(hasattr(os, "mkfifo"), "POSIX")
    def test_special_evidence_is_rejected_without_hanging(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "fifo"
            os.mkfifo(path)
            with self.assertRaises(core.M5Error):
                core._load_object(path, "fixture")

    def test_duplicate_lock_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "adk.lock"
            path.write_text('schema=llm-agent-adk-lock/v2\nschema=llm-agent-adk-lock/v2\n')
            with self.assertRaises(core.M5Error):
                diagnostic._lock(root)
            with self.assertRaises(core.M5Error):
                core._kv(path)

    def test_field_hash_and_jsonl_reject_links_and_special_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            outside = root / "outside"
            outside.write_text('{}\n')
            link = root / "link"
            link.symlink_to(outside)
            for operation in (lambda: core._sha256_file(link), lambda: core._read_events(root, link)):
                with self.assertRaises(core.M5Error):
                    operation()
            if hasattr(os, "mkfifo"):
                fifo = root / "fifo"
                os.mkfifo(fifo)
                for operation in (lambda: core._sha256_file(fifo), lambda: core._read_events(root, fifo)):
                    with self.assertRaises(core.M5Error):
                        operation()

    def test_duplicate_jsonl_event_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "events.jsonl"
            path.write_text('{"sequence":1,"sequence":1}\n')
            with self.assertRaises(core.M5Error):
                core._read_events(root, path)


if __name__ == "__main__":
    unittest.main()
