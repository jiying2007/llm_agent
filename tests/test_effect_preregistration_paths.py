"""Real G22 CLI file-boundary tests; no provider or qualification evidence."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from agent_dev_kit.model import Manifest, canonical_json_bytes, sha256_bytes
from tools.control_plane import effect_preregistration_package as packages

ROOT = Path(__file__).resolve().parents[1]
ADK = ROOT / "agent-dev-kit"


def source_fixture() -> dict:
    manifest = Manifest.load(ADK)
    agent = next(iter(manifest.all_assets("agent")))
    profiles = manifest.data["profiles"]
    profile = sorted(profiles)[0]
    baseline = [{"asset_kind": "profile", "asset_id": profile,
                 "content_ref": "ref:" + sha256_bytes(canonical_json_bytes(profiles[profile]))}]
    candidate = baseline + [{"asset_kind": "agent", "asset_id": agent.name,
                             "content_ref": "ref:" + agent.digest}]
    return {
        "schema": packages.SOURCE_SCHEMA, "status": "draft",
        "plan": {
            "campaign_id": "g22-file-boundary-synthetic-fixture",
            "registered_at": "2020-01-01T00:00:00Z",
            "window": {"from": "2020-01-01T01:00:00Z", "through": "2020-01-01T02:00:00Z",
                       "as_of": "2020-01-01T03:00:00Z"},
            "task_ids": ["synthetic-a", "synthetic-b"], "trial_ids": ["trial-1", "trial-2"],
            "controls": {"runtime_target": "claude", "runtime_version": "2.1.278",
                         "model_version": "claude-haiku-4-5-20251001", "prompt_version": "fixture-v1",
                         "orchestration_mode": "single-agent", "model_identity": "revision-bound"},
            "policy": {"primary_metric": "latency-per-task-ms", "minimum_effect": 0,
                       "noninferiority_margin": 0, "guardrails": {"task-success-rate": 0, "wrong-skill-rate": 0},
                       "minimum_tasks": 2, "minimum_trials": 2, "bootstrap_samples": 100,
                       "bootstrap_seed": 42, "confidence": 0.95},
        },
        "controls": {name: {"synthetic": True, "name": name}
                     for name in ("environment", "tool_policy", "grader", "dataset", "parameters", "provider")},
        "bundles": {side: {"schema": packages.BUNDLE_SCHEMA, "condition": side, "runtime_target": "claude",
                           "assets": assets, "metadata": {"synthetic": True},
                           "raw_content_stored": False, "release_authorized": False}
                    for side, assets in (("baseline", baseline), ("candidate", candidate))},
        "raw_content_stored": False, "provider_execution_performed": False, "release_authorized": False,
    }


class PreregistrationPathTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source_bytes = json.dumps(source_fixture()).encode("utf-8")

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="g22-cli-path-fixture-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.source = self.base / "source.json"
        self.package = self.base / "package.json"
        self.source.write_bytes(self.source_bytes)
        self.canonical, _ = packages.build_package(ADK, self.source)
        self.package.write_bytes(self.canonical)

    def cli(self, *args: str) -> subprocess.CompletedProcess:
        env = dict(os.environ, PYTHONPATH=os.pathsep.join((str(ROOT), str(ADK / "src"))))
        return subprocess.run([sys.executable, "-m", "tools.control_plane.effect_preregistration_package",
                               "--adk", str(ADK), *args, "--summary-json"], cwd=ROOT, env=env,
                              capture_output=True, timeout=20, check=False)

    def assert_rejected(self, result: subprocess.CompletedProcess) -> None:
        self.assertEqual(result.returncode, 1, result.stdout.decode("utf-8", errors="replace"))
        self.assertEqual(json.loads(result.stdout)["status"], "fail")
        self.assertNotIn(b"Traceback", result.stderr)

    def test_normal_build_and_canonical_output(self) -> None:
        output = self.base / "new" / "result.json"
        result = self.cli("--source", str(self.source), "--output", str(output))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_bytes(), self.canonical)
        canonical = self.base / "canonical.json"
        canonical.write_bytes(b"previous-regular-output")
        result = self.cli("--package", str(output), "--canonical-out", str(canonical))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(canonical.read_bytes(), self.canonical)
        self.assertEqual(self.source.read_bytes(), self.source_bytes)

    def test_regular_overwrite_requires_explicit_opt_in(self) -> None:
        output = self.base / "existing.json"
        output.write_bytes(b"previous-output")
        self.assert_rejected(self.cli("--source", str(self.source), "--output", str(output)))
        self.assertEqual(output.read_bytes(), b"previous-output")
        result = self.cli("--source", str(self.source), "--output", str(output), "--overwrite")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_bytes(), self.canonical)

    def test_source_and_package_symlink_inputs_are_rejected(self) -> None:
        for mode, target in (("source", self.source), ("package", self.package)):
            for kind in ("leaf", "parent"):
                with self.subTest(mode=mode, kind=kind):
                    case = self.base / (mode + "-" + kind)
                    case.mkdir()
                    link = case / "linked"
                    if kind == "leaf":
                        link.symlink_to(target)
                        supplied = link
                    else:
                        link.symlink_to(self.base, target_is_directory=True)
                        supplied = link / target.name
                    output = case / "result.json"
                    option = "--output" if mode == "source" else "--canonical-out"
                    self.assert_rejected(self.cli("--" + mode, str(supplied), option, str(output)))
                    self.assertTrue(link.is_symlink())
                    self.assertFalse(output.exists())
                    self.assertEqual(self.source.read_bytes(), self.source_bytes)
                    self.assertEqual(self.package.read_bytes(), self.canonical)

    def test_output_links_preserve_target_and_reject_parent_creation(self) -> None:
        for mode in ("source", "package"):
            for kind in ("existing", "dangling", "parent"):
                with self.subTest(mode=mode, kind=kind):
                    case = self.base / (mode + "-" + kind)
                    case.mkdir()
                    target = case / "target"
                    link = case / "linked"
                    if kind == "parent":
                        target.mkdir()
                        link.symlink_to(target, target_is_directory=True)
                        output = link / "result.json"
                    else:
                        if kind == "existing":
                            target.write_bytes(b"original-target")
                        link.symlink_to(target)
                        output = link
                    option = "--output" if mode == "source" else "--canonical-out"
                    arguments = ["--" + mode, str(self.source if mode == "source" else self.package),
                                 option, str(output)]
                    if mode == "source" and kind == "existing":
                        arguments.append("--overwrite")
                    self.assert_rejected(self.cli(*arguments))
                    self.assertTrue(link.is_symlink())
                    if kind == "existing":
                        self.assertEqual(target.read_bytes(), b"original-target")
                    elif kind == "dangling":
                        self.assertFalse(target.exists())
                    else:
                        self.assertEqual(list(target.iterdir()), [])
        actual, link = self.base / "parent-target", self.base / "parent-link"
        actual.mkdir()
        link.symlink_to(actual, target_is_directory=True)
        self.assert_rejected(self.cli("--source", str(self.source), "--output", str(link / "new" / "result.json")))
        self.assertFalse((actual / "new").exists())

    def test_input_alias_outputs_are_rejected(self) -> None:
        for mode, original in (("source", self.source), ("package", self.package)):
            for kind in ("same", "hardlink"):
                with self.subTest(mode=mode, kind=kind):
                    case = self.base / (mode + "-" + kind)
                    case.mkdir()
                    target = case / "input.json"
                    before = original.read_bytes()
                    target.write_bytes(before)
                    output = target
                    if kind == "hardlink":
                        output = case / "alias.json"
                        os.link(target, output)
                    option = "--output" if mode == "source" else "--canonical-out"
                    arguments = ["--" + mode, str(target), option, str(output)]
                    if mode == "source":
                        arguments.append("--overwrite")
                    self.assert_rejected(self.cli(*arguments))
                    self.assertEqual(target.read_bytes(), before)
                    self.assertEqual(self.source.read_bytes(), self.source_bytes)
                    self.assertEqual(self.package.read_bytes(), self.canonical)


if __name__ == "__main__":
    unittest.main()
