"""Input Unicode and transactional-output regressions using owned fixtures."""
from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.codex_assets import intake_io


class StrictUnicodeTests(unittest.TestCase):
    def test_utf16_and_utf32_bytes_are_rejected(self) -> None:
        for encoding in ("utf-16", "utf-16-le", "utf-32", "utf-32-be"):
            raw = '{"synthetic":"PRIVATE_INPUT"}'.encode(encoding)
            with self.subTest(encoding=encoding):
                with self.assertRaises(intake_io.IntakeError) as failure:
                    intake_io.decode_json(raw, "fixture")
                self.assertNotIn("PRIVATE_INPUT", str(failure.exception))

    def test_isolated_surrogates_in_nested_values_and_keys_are_rejected(self) -> None:
        for value in ({"outer": ["PRIVATE_INPUT\ud800"]}, {"outer": {"PRIVATE_INPUT\udfff": 1}}):
            escaped = json.dumps(value, ensure_ascii=True)
            literal = json.dumps(value, ensure_ascii=False)
            for raw in (escaped, escaped.encode("utf-8"), literal):
                with self.subTest(raw_type=type(raw).__name__):
                    with self.assertRaises(intake_io.IntakeError) as failure:
                        intake_io.decode_json(raw, "fixture")
                    self.assertNotIn("PRIVATE_INPUT", str(failure.exception))

    def test_valid_utf8_and_paired_escapes_are_preserved(self) -> None:
        expected = {"中文键": ["中文值", "😀"]}
        for raw in (json.dumps(expected, ensure_ascii=True),
                    json.dumps(expected, ensure_ascii=False),
                    json.dumps(expected, ensure_ascii=False).encode("utf-8")):
            self.assertEqual(intake_io.decode_json(raw, "fixture"), expected)

    def test_file_consumers_reject_invalid_unicode(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "input.json"
            path.write_bytes(b'{"nested":[{"bad":"\\ud800"}]}')
            for reader in (intake_io._load_json, intake_io._load_jsonl):
                with self.subTest(reader=reader.__name__), self.assertRaises(intake_io.IntakeError):
                    reader(path, 1024, "fixture")


class AtomicOutputTests(unittest.TestCase):
    def test_nonregular_second_output_preserves_all_existing_data(self) -> None:
        kinds = ["directory", "symlink"] + (["fifo"] if hasattr(os, "mkfifo") else [])
        for kind in kinds:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary)
                first, second = base / "first.json", base / "second.json"
                first.write_bytes(b"original-first")
                if kind == "directory":
                    second.mkdir()
                    (second / "original.txt").write_bytes(b"original-directory")
                elif kind == "fifo":
                    os.mkfifo(second)
                else:
                    second.symlink_to(base / "missing-target")
                before_mode = second.lstat().st_mode
                with self.assertRaises(intake_io.IntakeError):
                    intake_io._transactional_write([(first, b"new-first"), (second, b"new-second")])
                self.assertEqual(first.read_bytes(), b"original-first")
                self.assertEqual(second.lstat().st_mode, before_mode)
                if kind == "directory":
                    self.assertEqual((second / "original.txt").read_bytes(), b"original-directory")
                self.assertEqual(sorted(entry.name for entry in base.iterdir()), ["first.json", "second.json"])

    def test_output_type_is_rechecked_before_publication(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            first, second = base / "first.json", base / "second.json"
            first.write_bytes(b"original-first")
            original_chmod = intake_io.os.chmod
            calls = 0

            def create_directory_after_staging(path, mode):
                nonlocal calls
                original_chmod(path, mode)
                calls += 1
                if calls == 2:
                    second.mkdir()
                    (second / "original.txt").write_bytes(b"late-directory")

            with patch.object(intake_io.os, "chmod", side_effect=create_directory_after_staging):
                with self.assertRaises(intake_io.IntakeError):
                    intake_io._transactional_write([(first, b"new-first"), (second, b"new-second")])
            self.assertEqual(first.read_bytes(), b"original-first")
            self.assertTrue(second.is_dir())
            self.assertEqual((second / "original.txt").read_bytes(), b"late-directory")
            self.assertEqual(sorted(entry.name for entry in base.iterdir()), ["first.json", "second.json"])

    def test_no_overwrite_creates_new_file_and_preserves_existing_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            target = base / "result.json"
            intake_io._atomic_write(target, b"first", overwrite=False)
            self.assertEqual(target.read_bytes(), b"first")
            with self.assertRaises(intake_io.IntakeError):
                intake_io._atomic_write(target, b"second", overwrite=False)
            self.assertEqual(target.read_bytes(), b"first")
            intake_io._atomic_write(target, b"replacement")
            self.assertEqual(target.read_bytes(), b"replacement")
            self.assertEqual([entry.name for entry in base.iterdir()], ["result.json"])

    def test_late_destination_creation_is_preserved_and_earlier_outputs_roll_back(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            first, second = base / "first.json", base / "second.json"
            original_link = intake_io.os.link

            def competing_create(source, target, *args, **kwargs):
                if Path(target) == second:
                    second.write_bytes(b"competing-writer")
                return original_link(source, target, *args, **kwargs)

            with patch.object(intake_io.os, "link", side_effect=competing_create):
                with self.assertRaises(intake_io.IntakeError):
                    intake_io._transactional_write([(first, b"ours-first"), (second, b"ours-second")],
                                                   overwrite=False)
            self.assertFalse(first.exists())
            self.assertEqual(second.read_bytes(), b"competing-writer")
            self.assertEqual([entry.name for entry in base.iterdir()], ["second.json"])

    def test_no_overwrite_rollback_preserves_replaced_output(self) -> None:
        for kind in ("regular", "symlink"):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary)
                first, second = base / "first.json", base / "second.json"
                original_link = intake_io.os.link
                first_stage = None
                competing_identity = None

                def replace_first_and_create_second(source, target, *args, **kwargs):
                    nonlocal first_stage, competing_identity
                    if Path(target) == first:
                        first_stage = Path(source)
                    elif Path(target) == second:
                        if kind == "regular":
                            replacement = base / "competing-first"
                            replacement.write_bytes(b"competitor-first")
                            os.replace(replacement, first)
                        else:
                            first.unlink()
                            first.symlink_to(first_stage)
                        info = first.lstat()
                        competing_identity = (info.st_dev, info.st_ino)
                        second.write_bytes(b"competitor-second")
                    return original_link(source, target, *args, **kwargs)

                with patch.object(intake_io.os, "link", side_effect=replace_first_and_create_second):
                    with self.assertRaisesRegex(intake_io.IntakeError, "^atomic output transaction failed$"):
                        intake_io._transactional_write([(first, b"ours-first"), (second, b"ours-second")],
                                                       overwrite=False)
                if kind == "regular":
                    self.assertTrue(first.is_file())
                    self.assertEqual(first.read_bytes(), b"competitor-first")
                else:
                    self.assertTrue(first.is_symlink())
                    self.assertEqual(os.readlink(first), str(first_stage))
                info = first.lstat()
                self.assertEqual((info.st_dev, info.st_ino), competing_identity)
                self.assertEqual(second.read_bytes(), b"competitor-second")
                self.assertEqual(sorted(entry.name for entry in base.iterdir()), ["first.json", "second.json"])

    def test_no_overwrite_rollback_tolerates_removed_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            first, second = base / "first.json", base / "second.json"
            original_link = intake_io.os.link

            def remove_first_and_create_second(source, target, *args, **kwargs):
                if Path(target) == second:
                    first.unlink()
                    second.write_bytes(b"competitor-second")
                return original_link(source, target, *args, **kwargs)

            with patch.object(intake_io.os, "link", side_effect=remove_first_and_create_second):
                with self.assertRaisesRegex(intake_io.IntakeError, "^atomic output transaction failed$"):
                    intake_io._transactional_write([(first, b"ours-first"), (second, b"ours-second")],
                                                   overwrite=False)
            self.assertFalse(first.exists())
            self.assertEqual(second.read_bytes(), b"competitor-second")
            self.assertEqual([entry.name for entry in base.iterdir()], ["second.json"])

    def test_input_aliases_are_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            source, alias = base / "source.json", base / "alias.json"
            source.write_bytes(b"original-input")
            os.link(source, alias)
            for target in (source, alias):
                with self.subTest(target=target.name), self.assertRaises(intake_io.IntakeError):
                    intake_io._atomic_write(target, b"replacement", inputs=[source])
                self.assertEqual(source.read_bytes(), b"original-input")
                self.assertEqual(alias.read_bytes(), b"original-input")

    def test_symlink_parent_is_rejected_without_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            actual, link = base / "actual", base / "link"
            actual.mkdir()
            link.symlink_to(actual, target_is_directory=True)
            with self.assertRaises(intake_io.IntakeError):
                intake_io._atomic_write(link / "result.json", b"result")
            self.assertEqual(list(actual.iterdir()), [])

    def test_rollback_failure_keeps_original_backup_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            first, second = base / "first.json", base / "second.json"
            first.write_bytes(b"original-first")
            second.write_bytes(b"original-second")
            original_replace = intake_io.os.replace

            def fail_publication_and_first_restore(source, target):
                source = Path(source)
                if (source.name.startswith(".practice-intake-stage-") and Path(target) == second
                        or source.name.startswith(".practice-intake-backup-") and Path(target) == first):
                    raise OSError("injected transaction failure")
                return original_replace(source, target)

            with patch.object(intake_io.os, "replace", side_effect=fail_publication_and_first_restore):
                with self.assertRaisesRegex(intake_io.IntakeError, "rollback failed"):
                    intake_io._transactional_write([(first, b"new-first"), (second, b"new-second")])
            backups = list(base.glob(".practice-intake-backup-*"))
            self.assertEqual([entry.read_bytes() for entry in backups], [b"original-first"])
            self.assertEqual(second.read_bytes(), b"original-second")
            self.assertFalse(list(base.glob(".practice-intake-stage-*")))


if __name__ == "__main__":
    unittest.main()
