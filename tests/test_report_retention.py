import os
import tempfile
import unittest
from pathlib import Path
from tools.codex_assets.report_retention import plan


class ReportRetentionTests(unittest.TestCase):
    def test_dependencies_protect_evidence_and_plan_never_moves(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "reports").mkdir()
            (root / "docs").mkdir()
            for name in ("old.md", "free.md", "current-status.md"):
                path = root / "reports" / name
                path.write_text("historical evidence")
                os.utime(path, (0, 0))
            (root / "docs" / "consumer.md").write_text("reports/old.md")
            value = plan(root)
            items = {v["path"]: v for v in value["candidates"]}
            self.assertFalse(items["reports/old.md"]["eligible_for_review"])
            self.assertTrue(items["reports/free.md"]["eligible_for_review"])
            self.assertFalse(items["reports/current-status.md"]["eligible_for_review"])
            self.assertEqual(value["files_moved"], 0)
            self.assertTrue((root / "reports/old.md").exists())
            self.assertFalse(value["apply_supported"])

    def test_symlink_and_incomplete_scan_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "reports").mkdir()
            (root / "docs").mkdir()
            old = root / "reports" / "old.md"
            old.write_text("evidence")
            os.utime(old, (0, 0))
            (root / "docs" / "linked").symlink_to("missing", target_is_directory=True)
            value = plan(root)
            self.assertTrue(value["scan_incomplete"])
            self.assertFalse(value["candidates"][0]["eligible_for_review"])

    def test_root_entry_source_and_relative_markdown_links_are_consumers(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ("reports", "tools", "docs"):
                (root / name).mkdir()
            old = root / "reports" / "old.md"
            old.write_text("evidence")
            os.utime(old, (0, 0))
            (root / "README.md").write_text("[old](reports/old.md)")
            (root / "tools" / "consumer.py").write_text('path = "reports/old.md"')
            (root / "reports" / "consumer.md").write_text("[old](old.md)")
            item = next(v for v in plan(root)["candidates"] if v["path"] == "reports/old.md")
            self.assertFalse(item["eligible_for_review"])
            self.assertEqual(item["referenced_by"], ["README.md", "reports/consumer.md", "tools/consumer.py"])


if __name__ == "__main__":
    unittest.main()
