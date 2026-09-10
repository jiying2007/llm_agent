import unittest
import subprocess
import tempfile
from pathlib import Path

from tools.codex_assets.validation_plan import _changed_paths, classify


class ValidationPlanTests(unittest.TestCase):
    def test_release_surface_uses_l4(self):
        value = classify(["agent-dev-kit/src/agent_dev_kit/release.py"], "a" * 64, "working-tree")
        self.assertEqual("L4", value["tier"])
        self.assertEqual("clean-commit-only", value["release_execution_boundary"])
        self.assertTrue(value["deferred_until_clean_commit"])

    def test_code_surface_uses_l3(self):
        value = classify(["tools/codex_assets/example.py"], "b" * 64, "working-tree")
        self.assertEqual("L3", value["tier"])

    def test_docs_only_uses_l1(self):
        value = classify(["docs/runbooks/example.md"], "c" * 64, "working-tree")
        self.assertEqual("L1", value["tier"])
        self.assertTrue(value["evidence_only"])

    def test_current_status_is_not_docs_only(self):
        value = classify(["reports/current-status.md"], "d" * 64, "working-tree")
        self.assertEqual("L4", value["tier"])

    def test_reference_dirty_is_excluded(self):
        value = classify(["OpenSpec"], "e" * 64, "working-tree")
        self.assertEqual("L1", value["tier"])
        self.assertEqual([], value["managed_paths"])

    def test_runtime_output_is_excluded(self):
        value = classify(["hermes_data"], "f" * 64, "working-tree")
        self.assertEqual([], value["managed_paths"])

    def test_script_readme_is_not_executable_code(self):
        value = classify(["scripts/README.md"], "1" * 64, "working-tree")
        self.assertEqual("L2", value["tier"])


class ValidationSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git(self.root, "init", "-q")
        (self.root / "README.md").write_text("baseline\n")
        self.commit(self.root)

    def git(self, root, *args):
        return subprocess.run(
            ["git", "-C", str(root), *args], check=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        ).stdout

    def commit(self, root):
        self.git(root, "add", ".")
        self.git(root, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "-c", "commit.gpgsign=false", "commit", "-qm", "fixture")

    def snapshot(self, staged=False):
        return _changed_paths(self.root, "HEAD", staged)[1]

    def add_child(self):
        child = self.root / "agent-dev-kit"
        child.mkdir()
        self.git(child, "init", "-q")
        (child / "source.py").write_text("value = 1\n")
        self.commit(child)
        self.commit(self.root)
        return child

    def test_excluded_cache_does_not_invalidate_snapshot(self):
        before = self.snapshot()
        cache = self.root / ".cache"
        cache.mkdir()
        (cache / "state.json").write_text("first")
        self.assertEqual(before, self.snapshot())
        (cache / "state.json").write_text("second")
        self.assertEqual(before, self.snapshot())

    def test_dirty_child_content_invalidates_snapshot(self):
        child = self.add_child()
        (child / "source.py").write_text("value = 2\n")
        before = self.snapshot()
        (child / "source.py").write_text("value = 3\n")
        self.assertNotEqual(before, self.snapshot())

    def test_child_untracked_content_invalidates_snapshot(self):
        child = self.add_child()
        (child / "new.py").write_text("value = 2\n")
        before = self.snapshot()
        (child / "new.py").write_text("value = 3\n")
        self.assertNotEqual(before, self.snapshot())

    def test_staged_snapshot_ignores_unstaged_child(self):
        child = self.add_child()
        (self.root / "README.md").write_text("staged\n")
        self.git(self.root, "add", "README.md")
        before = self.snapshot(staged=True)
        (child / "source.py").write_text("value = 9\n")
        self.assertEqual(before, self.snapshot(staged=True))

    def test_workspace_exclusions_do_not_hide_child_product_files(self):
        child = self.add_child()
        source = child / "superpowers"
        source.mkdir()
        (source / "contract.json").write_text("first")
        before = self.snapshot()
        (source / "contract.json").write_text("second")
        self.assertNotEqual(before, self.snapshot())

    def test_filename_with_newline_is_bound(self):
        source = self.root / "line\nbreak.py"
        source.write_text("first")
        before = self.snapshot()
        source.write_text("second")
        self.assertNotEqual(before, self.snapshot())

    def test_untracked_executable_mode_is_bound(self):
        source = self.root / "tool.sh"
        source.write_text("exit 0\n")
        source.chmod(0o644)
        before = self.snapshot()
        source.chmod(0o755)
        self.assertNotEqual(before, self.snapshot())

    def test_clean_base_tree_is_bound(self):
        before = self.snapshot()
        (self.root / "README.md").write_text("new baseline\n")
        self.commit(self.root)
        self.assertNotEqual(before, self.snapshot())

    def test_untracked_symlink_target_is_bound_without_following(self):
        link = self.root / "shortcut"
        link.symlink_to("missing-a")
        before = self.snapshot()
        link.unlink()
        link.symlink_to("missing-b")
        self.assertNotEqual(before, self.snapshot())


if __name__ == "__main__":
    unittest.main()
