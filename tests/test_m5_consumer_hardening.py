"""Adversarial synthetic evidence tests; no real model or release execution."""
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
from unittest import mock

from m5_fixtures import receipt, runtime
from tools.codex_assets import m5_ci_contract as ci
from tools.codex_assets import m5_runtime_contract as contract
from tools.codex_assets import m5_signature as signature
from tools.codex_assets import runtime_smoke_evidence as smoke
from tools.codex_assets import software_m5_rollover as rollover
from tools.codex_assets import software_m5_v3_core as core


class ConsumerHardeningTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.lock = {"agent-dev-kit.version": "8.0.5", "agent-dev-kit.commit": "a" * 40,
                     "agent-dev-kit.tree": "b" * 40, "agent-dev-kit.manifest_blob": "c" * 40}
        self.now = datetime.now(timezone.utc)

    def write(self, name, value):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))
        return path

    def redigest(self, value):
        value.pop("evidence_sha256", None)
        value["evidence_sha256"] = contract.digest(value)

    def test_runtime_rejects_all_original_bypass_classes_after_redigest(self):
        original = runtime(self.lock)
        mutations = [
            lambda v: v["collection"].update(runtime_identity="unverified-import"),
            lambda v: v["collection"].pop("runtime_identity"),
            lambda v: v.update(adk_commit="d" * 40),
            lambda v: v.update(adk_tree="d" * 40),
            lambda v: v.update(manifest_blob="d" * 40),
            lambda v: v.update(generated_at="2000-01-01T00:00:00Z", review_after="2000-01-31"),
            lambda v: v["result"].update(reported_models=["wrong-model"]),
            lambda v: v["result"].update(total=0, passed=0, results=[]),
            lambda v: v["result"].update(total=True, passed=True),
            lambda v: v["result"].update(passed=True),
            lambda v: v["result"].update(quality_gate={"invented_gate": True}),
            lambda v: v["result"].update(results=[]),
            lambda v: v["result"]["results"][0].update(reported_models=["wrong-model"]),
            lambda v: v["result"]["results"][0].update(actual_skill="wrong-route"),
            lambda v: v["result"]["results"][0].update(actual_safe=False),
            lambda v: v["result"]["results"][0].update(error="runtime-error"),
        ]
        contract.validate(original, self.lock, self.now)
        for index, mutate in enumerate(mutations):
            value = copy.deepcopy(original)
            mutate(value)
            self.redigest(value)
            with self.subTest(index=index), self.assertRaises(ValueError):
                contract.validate(value, self.lock, self.now)
            path = self.write("runtime.json", value)
            with self.subTest(consumer="rollover", index=index), self.assertRaises(rollover.RolloverError):
                rollover._validate_runtime(path, self.lock, self.now)

    def test_content_tampering_without_new_digest_is_rejected(self):
        value = runtime(self.lock)
        value["evidence_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "does not match content"):
            contract.validate(value, self.lock, self.now)

    def test_provider_observation_rejects_redigested_identity_tampering(self):
        original = runtime(self.lock)
        scope = "upstream-response-openai-model-header"
        original["collection"]["model_observation"] = {
            "scope": scope, "adapter_sha256": "a" * 64, "records": [{
                "scope": scope, "model": "gpt-6.1-sol", "completed": True,
                "tools_disabled": True, "response_id": "fixture-response",
                "header_sources": ["sse-response-header"], "request_sha256": "b" * 64,
                "upstream": "https://chatgpt.com/backend-api/codex/responses"}]}
        self.redigest(original)
        contract.validate(original, self.lock, self.now)
        for key, value in (("model", "fallback"), ("completed", False),
                           ("tools_disabled", False), ("response_id", ""),
                           ("header_sources", ["agent-text"]), ("request_sha256", "bad"),
                           ("upstream", "https://untrusted.invalid")):
            mutated = copy.deepcopy(original)
            mutated["collection"]["model_observation"]["records"][0][key] = value
            self.redigest(mutated)
            with self.subTest(key=key), self.assertRaises(ValueError):
                contract.validate(mutated, self.lock, self.now)

    def test_core_uses_same_identity_and_expiry_contract(self):
        value = runtime(self.lock)
        value["adk_commit"] = "f" * 40
        self.redigest(value)
        self.write("runtime.json", value)
        (self.root / "adk.lock").write_text("\n".join(f"{k}={v}" for k, v in self.lock.items()))
        policy = {"runtime_qualification": {"measured_evidence": ["runtime.json"]}, "release": {}}
        with self.assertRaisesRegex(core.M5Error, "adk_commit"):
            core._validate_runtime(self.root, policy)

    def test_ci_rejects_number_only_and_unbound_success_record(self):
        with self.assertRaises(ValueError):
            ci.validate_receipt(None, head="a" * 40, run_id=1)
        with self.assertRaises(ValueError):
            ci.validate_record({"required_runs": [{"conclusion": "success"}]}, self.lock)
        with self.assertRaisesRegex(rollover.RolloverError, "run ID alone"):
            rollover.finalize(self.root, self.root / "unused", 1)

    def test_signed_ci_identity_and_jobs_are_mandatory(self):
        envelope = receipt("a" * 40, 17)
        with mock.patch.object(ci, "verify", return_value={}) as verify:
            self.assertEqual(ci.validate_receipt(envelope, head="a" * 40, run_id=17)["run_id"], 17)
            verify.assert_called_once()
        source = json.loads(base64.b64decode(envelope["payload_base64"]))
        for field, value in (("repository", "attacker/repo"), ("head_sha", "b" * 40),
                             ("run_id", 18), ("event", "pull_request"), ("run_attempt", True),
                             ("workflow", "other.yml"), ("conclusion", "failure"),
                             ("jobs", {"invented": "success"})):
            payload = dict(source, **{field: value})
            altered = dict(envelope, payload_base64=base64.b64encode(json.dumps(payload).encode()).decode())
            with self.subTest(field=field), mock.patch.object(ci, "verify") as verify:
                with self.assertRaises(ValueError):
                    ci.validate_receipt(altered, head="a" * 40, run_id=17)
                verify.assert_not_called()

    def trust(self):
        binary = self.root / "cosign"
        binary.write_bytes(b"#!/bin/sh\nexit 1\n")
        trust = self.root / "trusted-root.json"
        trust.write_bytes(b'{}')
        return signature.Trust(binary, hashlib.sha256(binary.read_bytes()).hexdigest(),
                               trust, hashlib.sha256(trust.read_bytes()).hexdigest())

    def test_missing_trust_or_wrong_pin_never_executes(self):
        with mock.patch.object(signature.subprocess, "run") as execute:
            with self.assertRaises(ValueError):
                signature.verify(b'{}', b'{"not_a_bundle":true}', repository="jiying2007/agent-dev-kit")
            trust = self.trust()
            wrong = signature.Trust(trust.verifier, "0" * 64, trust.trusted_root, trust.trusted_root_sha256)
            with signature.using(wrong), self.assertRaises(ValueError):
                signature.verify(b'{}', b'{}', repository="jiying2007/agent-dev-kit")
            execute.assert_not_called()

    def test_invalid_signature_never_becomes_verified(self):
        with signature.using(self.trust()), self.assertRaisesRegex(ValueError, "verification failed"):
            signature.verify(b'{}', b'{"not_a_sigstore_bundle":true}', repository="jiying2007/agent-dev-kit")

    def test_official_verifier_fits_finite_size_bound(self):
        self.assertGreaterEqual(signature.MAX_VERIFIER_BYTES, 141_178_250)
        self.assertEqual(signature.MAX_VERIFIER_BYTES, 256 * 1024 * 1024)
        trust = self.trust()
        with signature.using(trust), mock.patch.object(signature, "read_bytes", wraps=signature.read_bytes) as read:
            with mock.patch.object(signature.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
                signature.verify(b'{}', b'{}', repository="jiying2007/agent-dev-kit")
        self.assertEqual(read.call_args_list[0].kwargs["max_bytes"], signature.MAX_VERIFIER_BYTES)

    def test_signature_executes_only_frozen_inputs_offline(self):
        trust = self.trust()
        def execute(command, **kwargs):
            self.assertNotEqual(Path(command[0]), trust.verifier)
            self.assertEqual(Path(command[0]).read_bytes(), trust.verifier.read_bytes())
            self.assertIn("--offline", command)
            self.assertIn("--new-bundle-format", command)
            self.assertEqual(kwargs["input"], b'{"payload":true}')
            self.assertEqual(Path(command[command.index("--bundle") + 1]).read_bytes(), b'{"bundle":true}')
            self.assertEqual(Path(command[command.index("--trusted-root") + 1]).read_bytes(), b'{}')
            trust.verifier.write_bytes(b"mutated after snapshot")
            return subprocess.CompletedProcess(command, 0)
        with signature.using(trust), mock.patch.object(signature.subprocess, "run", side_effect=execute):
            result = signature.verify(b'{"payload":true}', b'{"bundle":true}', repository="jiying2007/llm_agent")
        self.assertEqual(result["evidence_sha256"], hashlib.sha256(b'{"payload":true}').hexdigest())

    def test_collector_rejects_leaf_parent_links_and_fifo(self):
        raw = self.write("source/raw.json", {})
        task = self.root / "source/tasks.jsonl"
        task.write_text('{}\n')
        (self.root / "linked").symlink_to(raw.parent, target_is_directory=True)
        leaf = self.root / "leaf.json"
        leaf.symlink_to(raw)
        for path in (leaf, self.root / "linked/raw.json"):
            with self.subTest(path=path), self.assertRaises(smoke.SmokeEvidenceError):
                smoke._load_json(path, "raw report")
        with self.assertRaises(smoke.SmokeEvidenceError):
            smoke._selected_tasks(self.root / "linked/tasks.jsonl", 1)
        fifo = self.root / "fifo"
        os.mkfifo(fifo)
        with self.assertRaises(smoke.SmokeEvidenceError):
            smoke._load_json(fifo, "raw report")

    def test_execute_rejects_linked_tasks_before_any_eval(self):
        task = self.root / "tasks.jsonl"
        task.write_text('{}\n')
        link = self.root / "linked.jsonl"
        link.symlink_to(task)
        with mock.patch.object(smoke, "_validate_source_identity", return_value=(self.lock, {}, self.root)), \
                mock.patch.object(smoke, "_execute_runtime") as execute:
            with self.assertRaises(smoke.SmokeEvidenceError):
                smoke.collect(self.root, self.root / "out.json", raw_result=None,
                              raw_output=self.root / "raw.json", execute=True, model="gpt-5.5",
                              limit=1, tasks=link, runtime_binary=None, generated_at=None,
                              review_days=30, approve_unknown_cost=True)
            execute.assert_not_called()

    def test_ci_producer_requires_actual_trusted_context_and_full_success(self):
        from tools.codex_assets.m5_ci_receipt_producer import payload
        environment = {"GITHUB_REPOSITORY": "jiying2007/llm_agent", "GITHUB_EVENT_NAME": "push",
                       "GITHUB_REF": "refs/heads/main", "GITHUB_SHA": "a" * 40,
                       "GITHUB_WORKFLOW_REF": "jiying2007/llm_agent/.github/workflows/ci.yml@refs/heads/main",
                       "GITHUB_RUN_ID": "17", "GITHUB_RUN_ATTEMPT": "2"}
        environment.update({"M5_JOB_" + job.upper().replace("-", "_"): "success" for job in ci.JOBS})
        self.assertEqual(payload(environment)["run_attempt"], 2)
        for field, value in (("GITHUB_REPOSITORY", "attacker/fork"), ("GITHUB_EVENT_NAME", "pull_request"),
                             ("GITHUB_REF", "refs/heads/topic"), ("GITHUB_SHA", "wrong"),
                             ("GITHUB_RUN_ID", "0"), ("M5_JOB_INTEGRATION", "skipped")):
            with self.subTest(field=field), self.assertRaises(ValueError):
                payload(dict(environment, **{field: value}))

    def test_ci_trust_materialization_requires_explicit_reviewed_pins(self):
        output = self.root / "ci/root.json"
        with mock.patch.dict(os.environ, {}, clear=True), self.assertRaises(ValueError):
            signature.prepare_ci_trust(output)
        self.assertFalse(output.exists())
        public_root = b'{"synthetic_only":true}'
        environment = {"M5_COSIGN_SHA256": "a" * 64,
                       "M5_TRUSTED_ROOT_SHA256": hashlib.sha256(public_root).hexdigest(),
                       "M5_TRUSTED_ROOT_BASE64": base64.b64encode(public_root).decode()}
        with mock.patch.dict(os.environ, environment, clear=True):
            signature.prepare_ci_trust(output)
        self.assertEqual(output.read_bytes(), public_root)
        environment["M5_TRUSTED_ROOT_SHA256"] = "0" * 64
        with mock.patch.dict(os.environ, environment, clear=True), self.assertRaises(ValueError):
            signature.prepare_ci_trust(self.root / "wrong.json")
        self.assertFalse((self.root / "wrong.json").exists())

    def test_hosted_certifier_has_its_own_verifier_adk_and_owner_pins(self):
        import yaml
        workflow = yaml.safe_load((Path(__file__).resolve().parents[1] / ".github/workflows/ci.yml").read_text())
        job = workflow["jobs"]["software-m5"]
        self.assertTrue(any(step.get("uses", "").startswith("sigstore/cosign-installer@") for step in job["steps"]))
        entry = next(step for step in job["steps"] if step.get("name") == "Enforce Software M5 current-or-historical qualification state")
        for variable in ("M5_COSIGN_SHA256", "M5_TRUSTED_ROOT_SHA256", "M5_TRUSTED_ROOT_BASE64"):
            self.assertEqual(entry["env"][variable], "${{ vars." + variable + " }}")
        self.assertIn("git submodule update --init --depth=1 agent-dev-kit", entry["run"])
        for flag in ("--cosign-binary", "--cosign-sha256", "--trusted-root", "--trusted-root-sha256"):
            self.assertIn(flag, entry["run"])

    def test_snapshot_hashes_are_bound_to_parsed_bytes(self):
        raw = self.write("raw.json", {"schema_version": 1})
        parsed, snapshot = smoke._load_json_snapshot(raw, "raw report")
        raw.write_text('{"schema_version":2}')
        self.assertEqual(parsed, json.loads(snapshot))
        self.assertNotEqual(hashlib.sha256(snapshot).hexdigest(), hashlib.sha256(raw.read_bytes()).hexdigest())
        tasks = self.root / "tasks.jsonl"
        task = {"id": "one", "prompt": "first", "category": "routing", "expected_skill": "a", "expected_safe": True}
        tasks.write_text(json.dumps(task) + "\n")
        selected, task_digest, task_snapshot = smoke._selected_task_snapshot(tasks, 1)
        tasks.write_text(json.dumps(dict(task, prompt="second")) + "\n")
        self.assertEqual(selected, [task])
        self.assertEqual(task_digest, hashlib.sha256(smoke._canonical([task]) + b"\n").hexdigest())
        self.assertNotEqual(task_snapshot, tasks.read_bytes())

    def pinned_source(self):
        adk = self.root / "agent-dev-kit"
        adk.mkdir()
        def git(*args):
            return subprocess.check_output(["git", "-C", str(adk), *args], stderr=subprocess.DEVNULL).decode().strip()
        git("init", "-q")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "user.name", "Fixture")
        manifest = {"version": "8.0.5"}
        (adk / "manifest.json").write_text(json.dumps(manifest))
        tasks = adk / "tests/fixtures/software_m5_eval_tasks.jsonl"
        tasks.parent.mkdir(parents=True)
        task = {"id": "one", "category": "routing", "prompt": "reviewed prompt",
                "expected_skill": "reviewed-skill", "expected_safe": True}
        tasks.write_text(json.dumps(task) + "\n")
        git("add", ".")
        git("commit", "-qm", "fixture")
        lock = {"agent-dev-kit.version": manifest["version"],
                "agent-dev-kit.commit": git("rev-parse", "HEAD"),
                "agent-dev-kit.tree": git("rev-parse", "HEAD^{tree}"),
                "agent-dev-kit.manifest_blob": git("rev-parse", "HEAD:manifest.json")}
        (self.root / "adk.lock").write_text("\n".join(k + "=" + v for k, v in lock.items()))
        selected, task_digest, raw = smoke._selected_task_snapshot(tasks, 1)
        evidence = runtime(lock, task=selected[0], manifest_digest=smoke._manifest_digest(manifest),
                           task_digest=task_digest, tasks_sha256=hashlib.sha256(raw).hexdigest())
        return adk, tasks, lock, evidence, git

    def test_production_runtime_rejects_hidden_tasks_manifest_and_evaluator(self):
        adk, tasks, lock, evidence, git = self.pinned_source()
        evaluator = adk / "scripts/devkit.sh"
        evaluator.parent.mkdir()
        evaluator.write_text("#!/bin/sh\nexit 0\n")
        git("add", ".")
        git("commit", "-qm", "fixture evaluator")
        lock["agent-dev-kit.commit"] = git("rev-parse", "HEAD")
        lock["agent-dev-kit.tree"] = git("rev-parse", "HEAD^{tree}")
        (self.root / "adk.lock").write_text("\n".join(k + "=" + v for k, v in lock.items()))
        evidence.update(adk_commit=lock["agent-dev-kit.commit"], adk_tree=lock["agent-dev-kit.tree"])
        self.redigest(evidence)
        contract.validate(evidence, lock, self.now, source_root=self.root)
        for relative in ("tests/fixtures/software_m5_eval_tasks.jsonl", "manifest.json", "scripts/devkit.sh"):
            path = adk / relative
            original = path.read_bytes()
            for flag, undo in (("--assume-unchanged", "--no-assume-unchanged"),
                               ("--skip-worktree", "--no-skip-worktree")):
                with self.subTest(path=relative, flag=flag):
                    git("update-index", flag, relative)
                    path.write_bytes(original + b" \n")
                    self.assertEqual(git("status", "--porcelain", "--untracked-files=all"), "")
                    with self.assertRaisesRegex(smoke.SmokeEvidenceError, "source index"):
                        contract.validate(evidence, lock, self.now, source_root=self.root)
                    path.write_bytes(original)
                    git("update-index", undo, relative)

    def test_consumed_task_bytes_are_bound_to_head_even_if_status_is_empty(self):
        adk, tasks, lock, evidence, git = self.pinned_source()
        task = json.loads(tasks.read_text())
        task.update(prompt="injected prompt", expected_skill="injected-skill")
        tasks.write_text(json.dumps(task) + "\n")
        selected, task_digest, raw = smoke._selected_task_snapshot(tasks, 1)
        altered = runtime(lock, task=selected[0], manifest_digest=evidence["manifest_sha256"],
                          task_digest=task_digest, tasks_sha256=hashlib.sha256(raw).hexdigest())
        # Isolate blob binding from Git status: never accept new local labels as pinned labels.
        with mock.patch.object(smoke, "_validate_source_identity", return_value=(lock, {"version": "8.0.5"}, adk)):
            with self.assertRaisesRegex(smoke.SmokeEvidenceError, "pinned HEAD blob"):
                contract.validate(altered, lock, self.now, source_root=self.root)
        with self.assertRaisesRegex(smoke.SmokeEvidenceError, "pinned HEAD blob"):
            smoke._verify_pinned_bytes(adk, "manifest.json", b'{"version":"8.0.5","injected":true}')

    def test_root_ci_baseline_rejects_hidden_tracked_source(self):
        def git(*args):
            return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.DEVNULL).decode().strip()
        git("init", "-q")
        git("config", "user.email", "fixture@example.invalid")
        git("config", "user.name", "Fixture")
        source = self.root / "source.py"
        source.write_text("reviewed = True\n")
        promotion = self.write("promotion.json", {"source": {"run_id": 17}})
        attestation = self.write("bundle.json", {})
        (self.root / "adk.lock").write_text("\n".join(k + "=" + v for k, v in self.lock.items()))
        git("add", ".")
        git("commit", "-qm", "fixture")
        baseline = git("rev-parse", "HEAD")
        record = {"schema": "llm-agent-m5-qualification-record/v1", "source_baseline": baseline,
                  "required_runs": [{"conclusion": "success"}], "adk": {
                      "promotion_run_id": 17,
                      "promotion_evidence_sha256": hashlib.sha256(promotion.read_bytes()).hexdigest(),
                      "promotion_attestation_sha256": hashlib.sha256(attestation.read_bytes()).hexdigest()}}
        record["record_sha256"] = core._digest(record)
        self.write("qualification.json", record)
        policy = {"qualification_record": "qualification.json", "release": {
            "promotion_evidence": "promotion.json", "promotion_attestation": "bundle.json"},
            "runtime_qualification": {"measured_evidence": []}}
        with mock.patch.object(ci, "validate_record"):
            self.assertEqual(core._validate_qualification_record(self.root, policy)["status"], "pass")
            for flag, undo in (("--assume-unchanged", "--no-assume-unchanged"),
                               ("--skip-worktree", "--no-skip-worktree")):
                git("update-index", flag, "source.py")
                source.write_text("reviewed = False\n")
                self.assertEqual(git("diff", "--name-only", baseline, "--"), "")
                with self.assertRaisesRegex(core.M5Error, "source index"):
                    core._validate_qualification_record(self.root, policy)
                source.write_text("reviewed = True\n")
                git("update-index", undo, "source.py")

    def test_hosted_checkout_preserves_signed_historical_baseline(self):
        import yaml
        root = Path(__file__).resolve().parents[1]
        workflow = yaml.safe_load((root / ".github/workflows/ci.yml").read_text())
        checkout = next(step for step in workflow["jobs"]["software-m5"]["steps"]
                        if step.get("name") == "Checkout root source")
        self.assertEqual(checkout["with"]["fetch-depth"], 0)
        origin = self.root / "origin"
        origin.mkdir()
        def git(path, *args):
            return subprocess.check_output(["git", "-C", str(path), *args], stderr=subprocess.DEVNULL).decode().strip()
        git(origin, "init", "-q")
        git(origin, "config", "user.email", "fixture@example.invalid")
        git(origin, "config", "user.name", "Fixture")
        (origin / "source.py").write_text("reviewed = True\n")
        git(origin, "add", ".")
        git(origin, "commit", "-qm", "signed baseline")
        baseline = git(origin, "rev-parse", "HEAD")
        (origin / "qualification.json").write_text('{}\n')
        git(origin, "add", ".")
        git(origin, "commit", "-qm", "qualification outputs")
        shallow, full = self.root / "shallow", self.root / "full"
        subprocess.run(["git", "clone", "-q", "--depth", "1", origin.as_uri(), str(shallow)], check=True)
        missing = subprocess.run(["git", "-C", str(shallow), "diff", "--name-only", baseline, "--"],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertNotEqual(missing.returncode, 0)
        subprocess.run(["git", "clone", "-q", origin.as_uri(), str(full)], check=True)
        self.assertEqual(git(full, "diff", "--name-only", baseline, "--"), "qualification.json")

    def test_ignored_startup_bytecode_cannot_hide_in_clean_pinned_source(self):
        import py_compile
        adk, tasks, lock, evidence, git = self.pinned_source()
        (adk / ".gitignore").write_text("*.pyc\n__pycache__/\n")
        git("add", ".gitignore")
        git("commit", "-qm", "fixture ignore rules")
        lock["agent-dev-kit.commit"] = git("rev-parse", "HEAD")
        lock["agent-dev-kit.tree"] = git("rev-parse", "HEAD^{tree}")
        (self.root / "adk.lock").write_text("\n".join(k + "=" + v for k, v in lock.items()))
        source = adk / "src"
        source.mkdir()
        startup = self.root / "startup_fixture.py"
        startup.write_text('print("SYNTHETIC_IGNORED_STARTUP_EXECUTED")\n')
        bytecode = source / "sitecustomize.pyc"
        py_compile.compile(str(startup), cfile=str(bytecode), doraise=True)
        self.assertEqual(git("status", "--porcelain", "--untracked-files=all"), "")
        self.assertEqual(git("check-ignore", "src/sitecustomize.pyc"), "src/sitecustomize.pyc")
        import sys
        launched = subprocess.run([sys.executable, "-c", 'print("entry")'], cwd=adk,
                                  env={**os.environ, "PYTHONPATH": str(source)},
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        self.assertIn("SYNTHETIC_IGNORED_STARTUP_EXECUTED", launched.stdout)
        with self.assertRaisesRegex(smoke.SmokeEvidenceError, "ignored executable"):
            smoke._validate_source_identity(self.root)
        bytecode.unlink()
        normal_cache = source / "__pycache__/fixture.cpython-311.pyc"
        normal_cache.parent.mkdir()
        normal_cache.write_bytes(b"synthetic cache; not a sourceless import candidate")
        self.assertEqual(smoke._validate_source_identity(self.root)[0], lock)


if __name__ == "__main__":
    unittest.main()
