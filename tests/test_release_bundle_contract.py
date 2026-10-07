"""Deterministic hostile-input checks for provenance-only bundle plans."""
import hashlib
import json
import os
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.codex_assets.release_bundle import build_bundle, main, parser, plan_receipt
from tools.codex_assets.intake_io import IntakeError, _atomic_write


class ReleaseBundleContractTests(unittest.TestCase):
    def test_shared_writer_keeps_default_and_rejects_bad_modes_before_mutation(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "output.json"
            for mode in (True, -1, 0o1000, "600"):
                with self.subTest(mode=mode), self.assertRaises(IntakeError):
                    _atomic_write(path, b"{}", mode=mode)
                self.assertFalse(path.exists())
            _atomic_write(path, b"{}")
            if os.name == "posix":
                self.assertEqual(0o644, stat.S_IMODE(path.stat().st_mode))

    def test_bundle_never_reads_hub_repository_or_claims_persistence(self):
        args = parser().parse_args(["--codex-plan", "unused", "--knowledge-candidate", "local-candidate", "--evidence", "unused"])
        with mock.patch("tools.codex_assets.release_bundle.repo_receipt", side_effect=lambda name, *_: {"name": name}) as repositories, \
             mock.patch("tools.codex_assets.release_bundle.plan_receipt", return_value={}), \
             mock.patch("tools.codex_assets.release_bundle.artifact_receipt", return_value={}):
            bundle = build_bundle(args)
        self.assertEqual(["llm-agent", "agent-dev-kit", "codex"], [call.args[0] for call in repositories.call_args_list])
        self.assertEqual(2, bundle["schema_version"])
        self.assertEqual("adk-cross-repo-release-bundle-v2", bundle["projection"])
        self.assertFalse(bundle["knowledge_boundary"]["provider_persisted"])
        self.assertEqual("not-established", bundle["knowledge_boundary"]["archive_claim"])
        self.assertNotIn("hub_candidate", bundle)
        self.assertFalse(hasattr(args, "hub_root"))

    def test_plan_identity_uses_the_parsed_bytes_without_second_read(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "plan.json"
            raw = b'{"schema_version":3,"content_changes":1,"build_receipt":{"tree_sha256":"test"}}\n'
            path.write_bytes(raw)
            with mock.patch.object(Path, "read_text", side_effect=AssertionError("second read")):
                receipt = plan_receipt(path)
            self.assertEqual(hashlib.sha256(raw).hexdigest(), receipt["sha256"])
            self.assertEqual(len(raw), receipt["bytes"])
            self.assertEqual(1, receipt["content_changes"])
            self.assertEqual("test", receipt["build_tree_sha256"])

    def test_ambiguous_nonfinite_nonobject_and_malformed_receipts_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "plan.json"
            for raw in ('{"content_changes":9,"content_changes":0}',
                        '{"build_receipt":{"x":1,"x":2}}', '{"x":NaN}', '{"x":1e999}',
                        '[]', 'null', '{"build_receipt":[1]}', '{"target_receipt":"bad"}',
                        '{"build_receipt":[]}', '{"target_receipt":false}',
                        '[' * 66 + '0' + ']' * 66):
                path.write_text(raw)
                with self.subTest(raw=raw), self.assertRaises(ValueError):
                    plan_receipt(path)
            path.write_bytes(b" " * (4 * 1024 * 1024) + b"{}")
            with self.assertRaisesRegex(ValueError, "byte budget"):
                plan_receipt(path)

    @unittest.skipUnless(hasattr(os, "mkfifo"), "POSIX boundary")
    def test_plan_rejects_symlink_fifo_and_directory(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            regular = root / "plan.json"
            regular.write_text("{}")
            link = root / "link.json"
            link.symlink_to(regular)
            fifo = root / "fifo.json"
            os.mkfifo(fifo)
            for path in (link, fifo, root):
                with self.subTest(path=path), self.assertRaises(ValueError):
                    plan_receipt(path)

    @unittest.skipUnless(os.name == "posix", "POSIX output link")
    def test_bundle_output_rejects_link_without_overwriting_referent(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            sentinel = root / "sentinel"
            sentinel.write_bytes(b"SENTINEL")
            output = root / "bundle.json"
            output.symlink_to(sentinel)
            args = ["--codex-plan", "unused", "--knowledge-candidate", "unused", "--out", str(output)]
            with mock.patch("tools.codex_assets.release_bundle.build_bundle", return_value={"status": "provenance-only"}):
                with self.assertRaisesRegex(SystemExit, "FAIL"):
                    main(args)
            self.assertTrue(output.is_symlink())
            self.assertEqual(b"SENTINEL", sentinel.read_bytes())

    def test_valid_output_is_published_and_rereadable(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "new" / "nested" / "bundle.json"
            args = ["--codex-plan", "unused", "--knowledge-candidate", "unused", "--out", str(output)]
            payload = {"status": "provenance-only", "release_authorized": False}
            with mock.patch("tools.codex_assets.release_bundle.build_bundle", return_value=payload):
                self.assertEqual(0, main(args))
            self.assertEqual(payload, json.loads(output.read_bytes()))
            if os.name == "posix":
                self.assertEqual(0o600, stat.S_IMODE(output.stat().st_mode))
            self.assertEqual([output], list(output.parent.iterdir()))

    def test_output_cannot_overwrite_plan_input(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "plan.json"
            path.write_bytes(b"{}")
            args = ["--codex-plan", str(path), "--knowledge-candidate", "unused", "--out", str(path)]
            with mock.patch("tools.codex_assets.release_bundle.build_bundle", return_value={"status": "provenance-only"}):
                with self.assertRaisesRegex(SystemExit, "must not overwrite an input"):
                    main(args)
            self.assertEqual(b"{}", path.read_bytes())

    @unittest.skipUnless(hasattr(os, "mkfifo"), "POSIX output types")
    def test_output_directory_and_fifo_are_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            directory = root / "directory"
            directory.mkdir()
            child = directory / "keep"
            child.write_bytes(b"SENTINEL")
            fifo = root / "fifo"
            os.mkfifo(fifo)
            for output in (directory, fifo):
                identity = output.lstat()
                args = ["--codex-plan", "unused", "--knowledge-candidate", "unused", "--out", str(output)]
                with mock.patch("tools.codex_assets.release_bundle.build_bundle", return_value={"status": "provenance-only"}):
                    with self.assertRaisesRegex(SystemExit, "regular file"):
                        main(args)
                after = output.lstat()
                self.assertEqual((identity.st_ino, identity.st_mode), (after.st_ino, after.st_mode))
            self.assertEqual(b"SENTINEL", child.read_bytes())
            self.assertEqual({directory, fifo}, set(root.iterdir()))


if __name__ == "__main__":
    unittest.main()
