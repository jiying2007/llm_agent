import unittest

from tools.codex_assets.validation_plan import classify


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


if __name__ == "__main__":
    unittest.main()
