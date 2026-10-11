"""Adversarial provenance fixtures, never real runtime or owner evidence."""
import base64
import copy
import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from m5_fixtures import runtime, attest_runtime
from tools.codex_assets import m5_runtime_contract as contract
from tools.codex_assets import m5_runtime_receipt as proof
from tools.codex_assets import m5_runtime_receipt_producer as producer
from tools.codex_assets import runtime_smoke_evidence as smoke
from tools.codex_assets import software_m5_v3 as field
from tools.codex_assets import software_m5_rollover as rollover


class RuntimeProvenanceTests(unittest.TestCase):
    def setUp(self):
        self.lock = {"agent-dev-kit.version": "8.0.5", "agent-dev-kit.commit": "a" * 40,
                     "agent-dev-kit.tree": "b" * 40, "agent-dev-kit.manifest_blob": "c" * 40}
        self.evidence = runtime(self.lock)
        self.now = datetime.now(timezone.utc)

    def redigest(self, value):
        value.pop("evidence_sha256", None)
        value["evidence_sha256"] = contract.digest(value)

    def test_unsigned_self_claim_with_realistic_model_observation_is_rejected(self):
        value = copy.deepcopy(self.evidence)
        value.pop("execution_receipt")
        self.redigest(value)
        with patch.object(proof, "signature_verify") as verify:
            with self.assertRaisesRegex(ValueError, "authenticated runtime"):
                contract.validate(value, self.lock, self.now)
            verify.assert_not_called()

    def test_complete_binding_calls_exact_runtime_workflow_verifier(self):
        with patch.object(proof, "signature_verify") as verify:
            contract.validate(self.evidence, self.lock, self.now, expected_source_baseline="a" * 40)
            self.assertEqual(verify.call_args.kwargs,
                             {"repository": "jiying2007/llm_agent", "workflow": "software-m5-runtime.yml"})

    def test_redigest_cannot_rebind_binary_usage_observation_or_source(self):
        mutations = [lambda v: v.update(runtime_binary_sha256="9" * 64),
                     lambda v: v["result"]["results"][0]["usage"].update(total_tokens=99),
                     lambda v: v["collection"]["model_observation"]["records"][0].update(response_id="forged"),
                     lambda v: v["collection"].update(collector_source_sha256="9" * 64)]
        for mutate in mutations:
            value = copy.deepcopy(self.evidence)
            mutate(value)
            self.redigest(value)
            with patch.object(proof, "signature_verify") as verify, self.assertRaisesRegex(ValueError, "digest differs"):
                contract.validate(value, self.lock, self.now)
            verify.assert_not_called()

    def test_receipt_identity_unknown_fields_types_and_ci_baseline_are_rejected(self):
        for key, item in (("repository", "attacker/root"), ("workflow", ".github/workflows/ci.yml"),
                          ("event", "push"), ("ref", "refs/heads/topic"), ("run_id", True),
                          ("run_attempt", 0), ("head_sha", "wrong"), ("extra", 1)):
            value = copy.deepcopy(self.evidence)
            payload = json.loads(base64.b64decode(value["execution_receipt"]["payload_base64"]))
            payload[key] = item
            value["execution_receipt"]["payload_base64"] = base64.b64encode(json.dumps(payload).encode()).decode()
            self.redigest(value)
            with self.subTest(key=key), patch.object(proof, "signature_verify") as verify, self.assertRaises(ValueError):
                contract.validate(value, self.lock, self.now)
            verify.assert_not_called()
        with patch.object(proof, "signature_verify") as verify, self.assertRaisesRegex(ValueError, "signed root CI"):
            contract.validate(self.evidence, self.lock, self.now, expected_source_baseline="d" * 40)
        verify.assert_not_called()

    def test_invalid_signature_missing_or_over_budget_bundle_never_passes(self):
        with patch.object(proof, "signature_verify", side_effect=ValueError("bad signature")), self.assertRaisesRegex(ValueError, "bad signature"):
            contract.validate(self.evidence, self.lock, self.now)
        for value in ({}, "!not-base64!", "x" * (6 * 1024 * 1024 + 1)):
            altered = copy.deepcopy(self.evidence)
            altered["execution_receipt"]["bundle_base64"] = value
            self.redigest(altered)
            with patch.object(proof, "signature_verify") as verify, self.assertRaises(ValueError):
                contract.validate(altered, self.lock, self.now)
            verify.assert_not_called()

    def test_producer_rejects_untrusted_trigger_and_missing_permissions_without_model(self):
        with self.assertRaises(ValueError):
            producer.context({})
        for network, cost in ((False, True), (True, False)):
            args = SimpleNamespace(allow_network=network, approve_unknown_cost=cost)
            with patch.object(smoke, "collect") as execute, self.assertRaises(ValueError):
                producer.collect(args)
            execute.assert_not_called()

    def test_output_links_and_existing_paths_are_rejected_before_any_source_call(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "owned"
            target.write_text("preserve")
            link = root / "link"
            link.symlink_to(target)
            for output in (target, link):
                with patch.object(smoke, "_validate_source_identity") as source, self.assertRaises(smoke.SmokeEvidenceError):
                    smoke.collect(root, output, raw_result=root / "raw", raw_output=None, execute=False,
                                  model="gpt-6.1-sol", limit=1, tasks=None, runtime_binary=None,
                                  generated_at=None, review_days=30)
                source.assert_not_called()
                self.assertEqual(target.read_text(), "preserve")

    def test_runtime_workflow_is_manual_protected_bounded_and_exports_only_signed_output(self):
        import yaml
        root = Path(__file__).resolve().parents[1]
        workflow = yaml.safe_load((root / proof.WORKFLOW).read_text())
        trigger = workflow.get("on", workflow.get(True))
        self.assertEqual(set(trigger), {"workflow_dispatch"})
        job = workflow["jobs"]["measure"]
        self.assertEqual(job["environment"], "software-m5-runtime")
        self.assertIn("m5-runtime", job["runs-on"])
        self.assertFalse(workflow["concurrency"]["cancel-in-progress"])
        commands = "\n".join(step.get("run", "") for step in job["steps"])
        self.assertIn("--allow-network --approve-unknown-cost", commands)
        self.assertLess(commands.index("producer collect"), commands.index("cosign sign-blob"))
        upload = [step for step in job["steps"] if step.get("uses", "").startswith("actions/upload-artifact@")]
        self.assertEqual(len(upload), 1)
        self.assertEqual(upload[0]["with"]["path"], "${{ runner.temp }}/m5-runtime-signed.json")

    def test_runtime_workflow_uses_runner_cache_only_in_step_context(self):
        import yaml
        root = Path(__file__).resolve().parents[1]
        workflow = yaml.safe_load((root / proof.WORKFLOW).read_text())
        job = workflow["jobs"]["measure"]
        # GitHub validates job env before assigning a runner. A runner context
        # here invalidates the whole workflow, even when the job is gated off.
        for value in job.get("env", {}).values():
            self.assertNotIn("runner.", str(value))
        python_steps = [step for step in job["steps"] if "python" in step.get("run", "")]
        self.assertEqual(len(python_steps), 3)
        caches = [step["env"]["PYTHONPYCACHEPREFIX"] for step in python_steps]
        self.assertEqual(len(set(caches)), 1)
        self.assertIn("${{ runner.temp }}", caches[0])
        self.assertIn("${{ github.run_id }}", caches[0])
        self.assertIn("${{ github.run_attempt }}", caches[0])
        self.assertIn('mkdir "$PYTHONPYCACHEPREFIX"', python_steps[0]["run"])


class ProducerFlowTests(unittest.TestCase):
    """Real Git/source checks; only inference and crypto use explicit fixtures."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.root = self.directory / "source"
        self.adk = self.root / "agent-dev-kit"
        self.adk.mkdir(parents=True)
        self.git(self.adk, "init", "-q")
        (self.adk / "manifest.json").write_text(json.dumps({"version": "8.0.5"}))
        self.task = {"id": "route-001", "category": "routing", "prompt": "synthetic offline test",
                     "expected_skill": "adk-runtime-router", "expected_safe": True}
        tasks = self.adk / "tests/fixtures/software_m5_eval_tasks.jsonl"
        tasks.parent.mkdir(parents=True)
        tasks.write_text(json.dumps(self.task) + "\n")
        evaluator = self.adk / "scripts/devkit.sh"
        evaluator.parent.mkdir(parents=True)
        evaluator.write_text("#!/bin/sh\nexit 0\n")
        self.git(self.adk, "add", ".")
        self.git(self.adk, "commit", "-qm", "synthetic ADK fixture")
        self.lock = {"schema": "llm-agent-adk-lock/v2", "agent-dev-kit.version": "8.0.5",
                     "agent-dev-kit.commit": self.git(self.adk, "rev-parse", "HEAD"),
                     "agent-dev-kit.tree": self.git(self.adk, "rev-parse", "HEAD^{tree}"),
                     "agent-dev-kit.manifest_blob": self.git(self.adk, "rev-parse", "HEAD:manifest.json")}
        (self.root / "adk.lock").write_text("".join(key + "=" + value + "\n" for key, value in self.lock.items()))
        source = Path(__file__).resolve().parents[1]
        for name in ("runtime_smoke_evidence.py", "m5_runtime_receipt_producer.py", "codex_model_observer.py", "source_git.py"):
            target = self.root / "tools/codex_assets" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((source / "tools/codex_assets" / name).read_bytes())
        self.git(self.root, "init", "-q")
        self.git(self.root, "add", "adk.lock", "tools")
        self.git(self.root, "update-index", "--add", "--cacheinfo",
                 "160000," + self.lock["agent-dev-kit.commit"] + ",agent-dev-kit")
        self.git(self.root, "commit", "-qm", "synthetic root fixture")
        self.head = self.git(self.root, "rev-parse", "HEAD")
        self.environment = {"GITHUB_REPOSITORY": "jiying2007/llm_agent", "GITHUB_REF": "refs/heads/main",
                            "GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_SHA": self.head,
                            "GITHUB_WORKFLOW_REF": "jiying2007/llm_agent/" + proof.WORKFLOW + "@refs/heads/main",
                            "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1"}
        self.binary = self.directory / "synthetic-binary"
        self.binary.write_text("#!/bin/sh\nexit 99\n")
        self.binary.chmod(0o700)
        self.args = SimpleNamespace(root=str(self.root), binary=str(self.binary),
            binary_sha256=hashlib.sha256(self.binary.read_bytes()).hexdigest(),
            evidence=str(self.directory / "unsigned.json"), raw_output=str(self.directory / "raw.json"),
            payload=str(self.directory / "payload.json"), allow_network=True, approve_unknown_cost=True)

    def git(self, root, *args):
        environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
        environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        return subprocess.check_output(["git", "-c", "core.hooksPath=" + os.devnull,
            "-c", "commit.gpgSign=false", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "-C", str(root), *args], env=environment, stderr=subprocess.DEVNULL, text=True).strip()

    def test_clean_real_checkout_passes_without_relaxing_identity_queries(self):
        self.assertEqual(self.git(self.root, "status", "--porcelain", "--untracked-files=all"), "")
        producer.clean_source(self.root, self.head)
        with self.assertRaises(smoke.SmokeEvidenceError):
            smoke._run_git(self.root, "status", "--porcelain")
        with self.assertRaisesRegex(ValueError, "workflow head"):
            producer.clean_source(self.root, "0" * 40)
        with self.assertRaises(smoke.SmokeEvidenceError):
            smoke._run_git(self.directory / "missing-checkout", "status", "--porcelain", allow_empty=True)

    def test_dirty_and_hidden_source_are_rejected_before_inference(self):
        path = self.root / "adk.lock"
        original = path.read_bytes()
        for flag, undo in ((None, None), ("--assume-unchanged", "--no-assume-unchanged"),
                           ("--skip-worktree", "--no-skip-worktree")):
            if flag:
                self.git(self.root, "update-index", flag, "adk.lock")
            path.write_bytes(original + b"# changed\n")
            try:
                with self.subTest(flag=flag), patch.dict(os.environ, self.environment), \
                        patch.object(smoke, "_execute_runtime") as inference:
                    with self.assertRaises((ValueError, smoke.SmokeEvidenceError)):
                        producer.collect(self.args)
                    inference.assert_not_called()
                    self.assertFalse(Path(self.args.payload).exists())
            finally:
                path.write_bytes(original)
                if undo:
                    self.git(self.root, "update-index", undo, "adk.lock")
        untracked = self.root / "untracked.txt"
        untracked.write_text("synthetic dirty input")
        with self.assertRaisesRegex(ValueError, "clean source"):
            producer.clean_source(self.root, self.head)

    def test_collect_payload_envelope_real_git_and_production_consumer(self):
        def inference(root, adk, raw_output, model, limit, tasks, binary, effort, **options):
            self.assertEqual((root, adk, model, limit, effort),
                             (self.root, self.adk, "gpt-6.1-sol", 1, "medium"))
            self.assertTrue(options["observe_provider_model"])
            selected, task_digest, task_bytes = smoke._selected_task_snapshot(tasks, limit)
            fixture = runtime(self.lock, model, task=selected[0],
                manifest_digest=smoke._manifest_digest({"version": "8.0.5"}), task_digest=task_digest,
                tasks_sha256=hashlib.sha256(task_bytes).hexdigest())
            smoke._write_new_json(raw_output, fixture["result"])
            return fixture["collection"]["model_observation"]

        with patch.dict(os.environ, self.environment), patch.object(smoke, "_execute_runtime", side_effect=inference) as execute:
            producer.collect(self.args)
        execute.assert_called_once()
        evidence = json.loads(Path(self.args.evidence).read_text())
        self.assertNotIn("execution_receipt", evidence)
        payload = json.loads(Path(self.args.payload).read_text())
        self.assertEqual(payload["evidence_payload_sha256"], proof.measurement_digest(evidence))
        self.assertEqual(payload["head_sha"], self.head)
        with self.assertRaisesRegex(ValueError, "authenticated runtime"):
            contract.validate(evidence, self.lock, datetime.now(timezone.utc), source_root=self.root)
        bundle, output = self.directory / "bundle.json", self.directory / "signed.json"
        bundle.write_text('{"synthetic_only":true}')
        args = SimpleNamespace(root=str(self.root), evidence=self.args.evidence, payload=self.args.payload,
            bundle=str(bundle), output=str(output), cosign_binary=None, cosign_sha256=None,
            trusted_root=None, trusted_root_sha256=None)
        with patch.dict(os.environ, self.environment), patch.object(proof, "signature_verify") as verifier:
            producer.envelope(args)
            sealed = json.loads(output.read_text())
            contract.validate(sealed, self.lock, datetime.now(timezone.utc), source_root=self.root,
                              expected_source_baseline=self.head)
        self.assertEqual(verifier.call_count, 2)
        producer.clean_source(self.root, self.head)

    def test_git_environment_cannot_redirect_dirty_source_to_clean_same_head(self):
        alternate = self.directory / "alternate"
        self.git(self.directory, "clone", "--no-local", str(self.root), str(alternate))
        (self.root / "adk.lock").write_text("changed source lock\n")
        redirect = {"GIT_DIR": str(alternate / ".git"), "GIT_WORK_TREE": str(alternate),
                    "GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "core.fsmonitor", "GIT_CONFIG_VALUE_0": "true"}
        with patch.dict(os.environ, {**self.environment, **redirect}), \
                patch.object(smoke, "_execute_runtime") as inference:
            with self.assertRaisesRegex(ValueError, "clean source"):
                producer.collect(self.args)
            inference.assert_not_called()
        with self.assertRaisesRegex(ValueError, "requested repository root"):
            producer.clean_source(self.root / "tools", self.head)

    def test_fsmonitor_cannot_hide_modified_evaluator_or_execute_during_verification(self):
        monitor = self.directory / "monitor.sh"
        marker = self.directory / "monitor-ran"
        monitor.write_text("#!/bin/sh\nprintf 'token\\0'\nprintf ran > '" + str(marker) + "'\n")
        monitor.chmod(0o700)
        self.git(self.adk, "config", "core.fsmonitor", str(monitor))
        self.git(self.adk, "config", "core.fsmonitorHookVersion", "2")
        self.assertEqual(self.git(self.adk, "status", "--porcelain"), "")
        evaluator = self.adk / "scripts/devkit.sh"
        evaluator.write_text("#!/bin/sh\nexit 42\n")
        self.assertEqual(self.git(self.adk, "status", "--porcelain"), "")
        marker.unlink()
        with self.assertRaisesRegex(smoke.SmokeEvidenceError, "executable source bytes"):
            smoke._validate_source_identity(self.root)
        self.assertFalse(marker.exists())

    def test_parent_status_cannot_run_child_repository_filters(self):
        (self.root / ".gitmodules").write_text('[submodule "agent-dev-kit"]\n\tpath = agent-dev-kit\n\turl = https://example.invalid/fixture.git\n')
        (self.adk / ".gitattributes").write_text("scripts/devkit.sh filter=childfixture\n")
        self.git(self.adk, "add", ".gitattributes")
        self.git(self.adk, "commit", "-qm", "synthetic child attributes")
        self.git(self.root, "add", "agent-dev-kit", ".gitmodules")
        self.git(self.root, "commit", "-qm", "synthetic child head")
        self.git(self.root, "config", "submodule.agent-dev-kit.url", "https://example.invalid/fixture.git")
        self.git(self.root, "config", "submodule.active", "agent-dev-kit")
        marker = self.directory / "child-filter-ran"
        self.git(self.adk, "config", "filter.childfixture.clean", "printf ran > '" + str(marker) + "'; exit 1")
        (self.adk / "scripts/devkit.sh").write_text("#!/bin/sh\nexit 1\n")
        self.git(self.root, "status", "--porcelain")
        self.assertTrue(marker.exists(), "fixture must expose native recursive filter execution")
        marker.unlink()
        smoke._run_git(self.root, "status", "--porcelain", "--ignore-submodules=dirty", allow_empty=True)
        smoke._run_git(self.adk, "status", "--porcelain", allow_empty=True)
        self.assertFalse(marker.exists())
        self.environment["GITHUB_SHA"] = self.git(self.root, "rev-parse", "HEAD")
        with patch.dict(os.environ, self.environment), patch.object(smoke, "_execute_runtime") as inference:
            with self.assertRaises(smoke.SmokeEvidenceError):
                producer.collect(self.args)
            inference.assert_not_called()
        self.assertFalse(marker.exists())
        with self.assertRaises(rollover.RolloverError):
            rollover.finalize(self.root, self.directory / "unused-runtime.json", 1,
                              root_ci_receipt=self.directory / "unused-ci.json")
        self.assertFalse(marker.exists())

    def test_executable_bytes_cannot_be_hidden_by_unchanged_stat_metadata(self):
        evaluator = self.adk / "scripts/devkit.sh"
        original = evaluator.stat()
        evaluator.write_text("#!/bin/sh\nexit 1\n")
        os.utime(evaluator, ns=(original.st_atime_ns, original.st_mtime_ns))
        with self.assertRaisesRegex(smoke.SmokeEvidenceError, "executable source bytes"):
            smoke._verify_executable_sources(self.adk)

    def test_configured_required_clean_filter_never_executes_in_source_status_or_diff(self):
        attributes = self.adk / ".gitattributes"
        attributes.write_text("scripts/devkit.sh filter=fixture\n")
        self.git(self.adk, "add", ".gitattributes")
        self.git(self.adk, "commit", "-qm", "synthetic attributes")
        marker = self.directory / "filter-ran"
        command = "printf ran > '" + str(marker) + "'; exit 1"
        self.git(self.adk, "config", "filter.fixture.clean", command)
        self.git(self.adk, "config", "filter.fixture.process", command)
        self.git(self.adk, "config", "filter.fixture.required", "true")
        (self.adk / "scripts/devkit.sh").write_text("#!/bin/sh\nexit 42\n")
        self.assertIn("scripts/devkit.sh", smoke._run_git(self.adk, "status", "--porcelain", allow_empty=True))
        self.assertIn("scripts/devkit.sh", smoke._run_git(self.adk, "diff", "--name-only", "HEAD", "--"))
        self.assertFalse(marker.exists())


class ManagedPilotIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.child = self.root / "pilot"
        self.child.mkdir()
        for repo in (self.root, self.child):
            self.git(repo, "init", "-q")
            self.git(repo, "config", "user.name", "Fixture")
            self.git(repo, "config", "user.email", "fixture@example.invalid")
        (self.child / "software.txt").write_text("synthetic fixture")
        self.git(self.child, "add", ".")
        self.git(self.child, "commit", "-qm", "fixture")
        self.commit = self.git(self.child, "rev-parse", "HEAD")
        self.git(self.child, "remote", "add", "origin", "https://github.com/approved/expected.git")
        self.git(self.root, "update-index", "--add", "--cacheinfo", "160000," + self.commit + ",pilot")
        self.git(self.root, "commit", "-qm", "gitlink fixture")
        self.entry = {"path": "pilot", "url": "https://github.com/approved/expected.git", "kind": "managed-dependency"}

    def git(self, root, *args):
        environment = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        return subprocess.check_output(["git", "-c", "core.hooksPath=" + os.devnull, "-c", "commit.gpgSign=false",
                                        "-C", str(root), *args], env=environment, stderr=subprocess.DEVNULL, text=True).strip()

    def test_real_gitlink_checkout_origin_and_commit_are_bound(self):
        self.assertEqual(field._managed_pilot_identity(self.root, self.entry),
                         {"path": "pilot", "repository": "approved/expected", "commit": self.commit})
        self.git(self.child, "remote", "set-url", "origin", "https://untrusted.invalid/approved/expected.git")
        with self.assertRaisesRegex(field.M5Error, "origin differs"):
            field._managed_pilot_identity(self.root, self.entry)

    def test_named_registry_path_without_actual_gitlink_is_rejected(self):
        self.git(self.root, "rm", "--cached", "pilot")
        self.git(self.root, "commit", "-qm", "remove gitlink")
        with self.assertRaisesRegex(field.M5Error, "actual HEAD Gitlink"):
            field._managed_pilot_identity(self.root, self.entry)

    def test_dirty_or_different_child_commit_is_rejected(self):
        (self.child / "software.txt").write_text("changed")
        with self.assertRaisesRegex(field.M5Error, "clean pinned"):
            field._managed_pilot_identity(self.root, self.entry)
        self.git(self.child, "add", ".")
        self.git(self.child, "commit", "-qm", "different")
        with self.assertRaisesRegex(field.M5Error, "clean pinned"):
            field._managed_pilot_identity(self.root, self.entry)

    def test_hidden_index_flags_cannot_hide_tracked_source_changes(self):
        path = self.child / "software.txt"
        original = path.read_text()
        for flag, undo in (("--assume-unchanged", "--no-assume-unchanged"),
                           ("--skip-worktree", "--no-skip-worktree")):
            self.git(self.child, "update-index", flag, "software.txt")
            path.write_text("hidden modification")
            self.assertEqual(self.git(self.child, "status", "--porcelain"), "")
            with self.subTest(flag=flag), self.assertRaisesRegex(field.M5Error, "hidden tracked"):
                field._managed_pilot_identity(self.root, self.entry)
            path.write_text(original)
            self.git(self.child, "update-index", undo, "software.txt")

    def test_pilot_json_must_match_same_candidate_repository_and_commit(self):
        identity = field._managed_pilot_identity(self.root, self.entry)
        event = {"pilot_id": "fixture", "operator_id": "human-fixture", "repository_id": "independent",
                 "evidence": ["evidence.json"]}
        value = {"schema": "llm-agent-m5-independent-pilot-start/v1", "pilot_id": "fixture",
                 "adk_source": {"repository": "jiying2007/agent-dev-kit", "commit": "a" * 40},
                 "operator": {"id": "human-fixture", "operator_type": "human"},
                 "pilot_repository": {**identity, "id": "independent", "classification": "independent", "real_software": True}}
        path = self.root / "evidence.json"
        policy = {"release": {"candidate_commit": "a" * 40}}
        path.write_text(json.dumps(value))
        self.assertTrue(field._pilot_start_matches_managed(self.root, event, policy, identity))
        for key, item in (("repository", "unrelated/wrong"), ("commit", "c" * 40), ("path", "elsewhere")):
            altered = copy.deepcopy(value)
            altered["pilot_repository"][key] = item
            path.write_text(json.dumps(altered))
            self.assertFalse(field._pilot_start_matches_managed(self.root, event, policy, identity))


if __name__ == "__main__":
    unittest.main()
