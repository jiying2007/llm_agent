"""Provider-free checks for the current ADK runtime smoke invocation boundary."""

import subprocess
import os
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.codex_assets import runtime_smoke_evidence as smoke


class RuntimeSmokeCommandTests(unittest.TestCase):
    def test_default_model_and_reasoning_are_explicit(self):
        args = smoke._parser().parse_args(["--execute", "--output", "/unused/evidence"])
        self.assertEqual(args.model, "gpt-6.1-sol")
        self.assertEqual(args.reasoning_effort, "medium")
        with self.assertRaises(smoke.SmokeEvidenceError):
            smoke._execute_runtime(Path('/unused'), Path('/unused'), Path('/unused'), 'gpt-6.1-sol',
                                   1, Path('/unused'), reasoning_effort='invalid')
    def test_shell_startup_environment_is_removed_from_both_invocations(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            marker = root / "startup-marker"
            startup = root / "startup.sh"
            startup.write_text('touch "' + str(marker) + '"\n')
            (root / "scripts/devkit.sh").write_text(
                '#!/bin/bash\nif [[ "$3" == "--help" ]]; then\n'
                'printf "%s" "--max-new-results --approve-unknown-cost"\n'
                'else\nprintf "%s" "{}" > "${@: -1}"\nfi\n')
            tasks = root / "tasks.jsonl"
            tasks.write_text('{}\n')
            env = {"BASH_ENV": str(startup), "ENV": str(startup),
                   "BASH_FUNC_unused%%": "() { :; }"}
            original_run = subprocess.run
            def observed(command, **kwargs):
                self.assertFalse(any(key in {"BASH_ENV", "ENV"} or key.startswith("BASH_FUNC_")
                                     for key in kwargs["env"]))
                return original_run(command, **kwargs)
            with patch.dict(os.environ, env), patch.object(smoke.subprocess, "run", side_effect=observed):
                smoke._execute_runtime(root, root, root / "raw.json", "gpt-5.5", 1, tasks)
            self.assertFalse(marker.exists())
            self.assertEqual((root / "raw.json").read_text(), '{}')

    def test_selected_executable_overrides_path_and_binds_digest(self):
        self._selected_executable_case()

    def test_changed_selected_executable_prevents_evidence_publication(self):
        self._selected_executable_case(mutate=True)

    def test_nonexecutable_selection_fails_before_eval(self):
        self._selected_executable_case(nonexecutable=True)

    def _selected_executable_case(self, mutate=False, nonexecutable=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            adk = root / "adk"
            (adk / "scripts").mkdir(parents=True)
            (adk / "scripts/devkit.sh").write_text(
                '#!/bin/bash\nif [[ "$3" == "--help" ]]; then\n'
                'printf "%s" "--max-new-results --approve-unknown-cost"\n'
                'else\ncodex exec "${@: -1}"\nfi\n')
            wrong_dir = root / "other"
            wrong_dir.mkdir()
            wrong = wrong_dir / "codex"
            wrong.write_text('#!/bin/sh\ntouch "' + str(root / "wrong-marker") + '"\n')
            wrong.chmod(0o700)
            selected = root / "selected launcher"
            selected.write_text('#!/bin/sh\n'
                                '[ "$1" = "exec" ] || exit 9\nshift\n'
                                '[ "$1" = "--ignore-user-config" ] || exit 10\n'
                                '[ "$2" = "-c" ] || exit 11\n'
                                '[ "$3" = \'model_reasoning_effort="medium"\' ] || exit 12\n'
                                'shift 3\nprintf "%s" "{}" > "$1"\n' +
                                ('printf "%s" "# changed" >> "$0"\n' if mutate else ''))
            if not nonexecutable:
                selected.chmod(0o700)
            selected_sha = hashlib.sha256(selected.read_bytes()).hexdigest()
            tasks = root / "tasks.jsonl"
            tasks.write_text('{}\n')
            output = root / "evidence.json"
            identity = ({"agent-dev-kit.commit": "a" * 40, "agent-dev-kit.tree": "b" * 40,
                         "agent-dev-kit.manifest_blob": "c" * 40}, {"version": "8.0.5"}, adk)
            with patch.dict(os.environ, {"PATH": str(wrong_dir) + os.pathsep + os.environ["PATH"]}), \
                    patch.object(smoke, "_validate_source_identity", return_value=identity), \
                    patch.object(smoke, "_selected_task_snapshot", return_value=([{}], "a" * 64, b'{}\n')), \
                    patch.object(smoke, "_validate_raw_report"), \
                    patch.object(smoke, "_load_json_snapshot", return_value=({"runtime_version": "synthetic"}, b'{}')):
                def collect():
                    return smoke.collect(root, output, raw_result=None, raw_output=root / "raw.json",
                                         execute=True, model="gpt-5.5", limit=1, tasks=tasks,
                                         runtime_binary=selected, generated_at=None, review_days=30,
                                         approve_unknown_cost=True)
                if mutate or nonexecutable:
                    with self.assertRaisesRegex(smoke.SmokeEvidenceError, "changed|executable regular"):
                        collect()
                    self.assertFalse(output.exists())
                else:
                    evidence = collect()
                    self.assertEqual(evidence["runtime_binary_sha256"], selected_sha)
                    self.assertEqual(evidence["collection"]["runtime_identity"], "selected-executable-pre-post-sha256")
                    self.assertEqual(evidence["collection"]["requested_reasoning_effort"], "medium")
                    self.assertFalse(evidence["collection"]["user_config_loaded"])
            self.assertFalse((root / "wrong-marker").exists())
            if nonexecutable:
                self.assertFalse((root / "raw.json").exists())

    def test_execute_requires_explicit_unknown_cost_acknowledgment(self):
        with patch.object(smoke, "_validate_source_identity") as source:
            with self.assertRaises(smoke.SmokeEvidenceError):
                smoke.collect(
                    Path("/unused"), Path("/unused/result.json"), raw_result=None,
                    raw_output=Path("/unused/raw.json"), execute=True, model="gpt-5.5",
                    limit=1, tasks=None, runtime_binary=None, generated_at=None,
                    review_days=30,
                )
        source.assert_not_called()

    def test_current_adk_entry_and_budget_flags_are_passed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            adk = root / "agent-dev-kit"
            (adk / "scripts").mkdir(parents=True)
            (adk / "scripts/devkit.sh").write_text("#!/usr/bin/env bash\n", encoding="utf-8")
            tasks = root / "tasks.jsonl"
            tasks.write_text("{}\n", encoding="utf-8")
            output = root / "raw.json"

            def fake_run(command, **kwargs):
                self.assertEqual(command[:2], ["bash", str(adk / "scripts/devkit.sh")])
                self.assertTrue(Path(kwargs["env"]["PYTHONPYCACHEPREFIX"]).is_dir())
                self.assertNotIn("PYTHONPATH", kwargs["env"])
                if "--help" in command:
                    return subprocess.CompletedProcess(
                        command, 0, stdout="--max-new-results --approve-unknown-cost", stderr="",
                    )
                self.assertEqual(command[command.index("--max-new-results") + 1], "2")
                self.assertIn("--approve-unknown-cost", command)
                self.assertEqual(command[command.index("--model") + 1], "gpt-5.5")
                output.write_text("{}\n", encoding="utf-8")
                return subprocess.CompletedProcess(command, 0)

            with patch.object(smoke.subprocess, "run", side_effect=fake_run):
                smoke._execute_runtime(root, adk, output, "gpt-5.5", 2, tasks)

            output.unlink()
            with patch.object(smoke.subprocess, "run", return_value=subprocess.CompletedProcess(
                ["bash", str(adk / "scripts/devkit.sh"), "eval", "run", "--help"],
                0, stdout="legacy eval help", stderr="",
            )) as model_call:
                with self.assertRaises(smoke.SmokeEvidenceError):
                    smoke._execute_runtime(root, adk, output, "gpt-5.5", 2, tasks)
            model_call.assert_called_once()
            self.assertFalse(output.exists())

    def test_execution_ignores_existing_valid_header_bytecode_without_deleting_it(self):
        import json
        import os
        import py_compile
        import struct
        import sys
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            adk = root / "agent-dev-kit"
            package = adk / "src/reviewpkg"
            package.mkdir(parents=True)
            source = package / "__init__.py"
            source.write_text('VALUE = "reviewed"\n')
            injected = root / "injected.py"
            injected.write_text('VALUE = "injected"\n')
            cache = package / "__pycache__" / ("__init__." + sys.implementation.cache_tag + ".pyc")
            cache.parent.mkdir()
            py_compile.compile(str(injected), cfile=str(cache), doraise=True,
                               invalidation_mode=py_compile.PycInvalidationMode.TIMESTAMP)
            original = cache.read_bytes()
            poisoned = original[:8] + struct.pack("<II", int(source.stat().st_mtime), source.stat().st_size) + original[16:]
            cache.write_bytes(poisoned)
            environment = dict(os.environ, PYTHONPATH=str(adk / "src"))
            environment.pop("PYTHONPYCACHEPREFIX", None)
            observed = subprocess.check_output([sys.executable, "-c", "import reviewpkg; print(reviewpkg.VALUE)"],
                                               env=environment, cwd=root, text=True)
            self.assertEqual(observed.strip(), "injected")
            scripts = adk / "scripts"
            scripts.mkdir()
            devkit = scripts / "devkit.sh"
            devkit.write_text(
                '#!/bin/bash\nexport PYTHONPATH="' + str(adk / "src") + '"\n'
                'if [[ "$3" == "--help" ]]; then\n'
                '  "' + sys.executable + '" -c \'import reviewpkg; print("--max-new-results --approve-unknown-cost")\'\n'
                'else\n'
                '  "' + sys.executable + '" -c \'import reviewpkg,json,sys; from pathlib import Path; '
                'Path(sys.argv[1]).write_text(json.dumps({"value":reviewpkg.VALUE}))\' "${@: -1}"\nfi\n'
            )
            tasks = root / "tasks.jsonl"
            tasks.write_text('{}\n')
            raw = root / "raw.json"
            smoke._execute_runtime(root, adk, raw, "gpt-5.5", 1, tasks)
            self.assertEqual(json.loads(raw.read_text()), {"value": "reviewed"})
            self.assertEqual(cache.read_bytes(), poisoned)

    def test_duplicate_task_fields_cannot_define_report_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            tasks = Path(directory) / "tasks.jsonl"
            tasks.write_text('{"id":"one","id":"two"}\n', encoding="utf-8")
            with self.assertRaises(smoke.SmokeEvidenceError):
                smoke._selected_tasks(tasks, 1)

    def test_source_drift_after_raw_report_prevents_evidence_write(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            adk = root / "agent-dev-kit"
            adk.mkdir()
            output = root / "evidence.json"
            identity = ({"agent-dev-kit.version": "7.12.2"}, {"version": "7.12.2"}, adk)
            with patch.object(smoke, "_validate_source_identity", side_effect=[
                identity, smoke.SmokeEvidenceError("source changed"),
            ]) as source:
                with patch.object(smoke, "_selected_task_snapshot", return_value=([{"id": "case"}], "a" * 64, b"tasks")):
                    with patch.object(smoke, "_load_json_snapshot", return_value=({}, b"{}")), \
                            patch.object(smoke, "_verify_pinned_bytes"):
                        with patch.object(smoke, "_validate_raw_report"):
                            with self.assertRaises(smoke.SmokeEvidenceError):
                                smoke.collect(
                                    root, output, raw_result=root / "raw.json", raw_output=None,
                                    execute=False, model="gpt-5.5", limit=1, tasks=None,
                                    runtime_binary=None, generated_at=None, review_days=30,
                                )
            self.assertEqual(source.call_count, 2)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
