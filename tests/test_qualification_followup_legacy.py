"""Offline, isolated, reproducible synthetic tests for the original ADK verifier.

No calls to providers or original GitHub network. Fixture tags, review values
and bytes are deliberately synthetic and never become production qualification.
"""
from __future__ import annotations

import hashlib
import io
import json
import subprocess
import sys
import tarfile
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

from delegated_review_fixtures import policy_fixture, review_fixture, write_json

from tools.control_plane import historical_review_verification as history


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args], check=True,
        capture_output=True, text=True,
    )
    return result.stdout.strip()


class OriginalHistoricalReexecutionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="original-review-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.adk = self.root / "agent-dev-kit"
        self.adk.mkdir()
        now = datetime.now(UTC)
        policy_fixture(self.adk, now)
        init = self.adk / "src/agent_dev_kit/__init__.py"
        init.write_text("", encoding="utf-8")
        targets = {}
        for change in history.RECORDS:
            archive = self.adk / "docs/changes/archive" / ("20261020-" + change)
            archive.mkdir(parents=True)
            source = archive / "proposal.md"
            source.write_text("Synthetic source, not historical production evidence.\n", encoding="utf-8")
            result = review_fixture(
                self.adk, archive / "review-evidence.json", subject=change,
                scope="source-change", sources=[source], reviewed_at=now,
                target={"base_commit": "a" * 40, "head_commit": "b" * 40},
            )
            targets[change] = result["target"]["original_patch_sha256"]
        _git(self.adk, "add", ".")
        subprocess.run(
            ["git", "-C", str(self.adk),
             "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
             "commit", "-qm", "Synthetic historical source"],
            check=True, capture_output=True,
        )
        subprocess.run(
            ["git", "-C", str(self.adk),
             "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
             "tag", "-a", "v8.0.36", "-m", "Synthetic frozen tag"],
            check=True, capture_output=True,
        )
        from agent_dev_kit import review_evidence

        originals = {
            "TAG_OBJECT": _git(self.adk, "rev-parse", "refs/tags/v8.0.36"),
            "COMMIT": _git(self.adk, "rev-parse", "HEAD"),
            "TREE": _git(self.adk, "rev-parse", "HEAD^{tree}"),
            "VALIDATORS": review_evidence.validator_fingerprints(),
            "POLICY_SHA": _sha(self.adk / ".adk/review-policy.json"),
            "AUTHORIZATION": "authorization.txt",
            "AUTHORIZATION_SHA": _sha(self.adk / "authorization.txt"),
            "RECORDS": {
                cid: (_sha(self.adk / "docs/changes/archive" / ("20261020-" + cid)
                           / "review-evidence.json"), targets[cid],
                      _git(self.adk, "rev-parse", "HEAD:docs/changes/archive/20261020-" + cid))
                for cid in history.RECORDS
            },
        }
        originals["SRC"] = tuple(originals["VALIDATORS"]) + (
            "src/agent_dev_kit/__init__.py", history.POLICY, originals["AUTHORIZATION"],
        )
        for name, value in originals.items():
            patcher = patch.object(history, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_actual_isolated_validator_runs_all_three_original_records(self) -> None:
        result = history.verify_original_reviews(self.adk)
        self.assertEqual(result["schema"], history.SCHEMA)
        self.assertEqual(result["source"]["commit"], history.COMMIT)
        self.assertTrue(result["historical_review_verified"])
        self.assertFalse(result["current_source_review_verified"])
        self.assertFalse(result["release_authorized"])
        self.assertEqual(set(result["records"]), set(history.RECORDS))
        self.assertTrue(all(x["spec"] == "pass" and x["quality"] == "pass"
                            for x in result["records"].values()))

    def test_different_tag_or_commit_is_not_original_evidence(self) -> None:
        with patch.object(history, "TAG_OBJECT", "0" * 40):
            with self.assertRaisesRegex(ValueError, "tag does not match"):
                history.verify_original_reviews(self.adk)
        with patch.object(history, "COMMIT", "0" * 40):
            with self.assertRaises(ValueError):
                history.verify_original_reviews(self.adk)

    def test_unavailable_original_tag_fails_closed(self) -> None:
        _git(self.adk, "tag", "-d", "v8.0.36")
        with self.assertRaises(ValueError):
            history.verify_original_reviews(self.adk)

    def test_original_policy_and_validator_digests_are_required(self) -> None:
        with patch.object(history, "POLICY_SHA", "0" * 64):
            with self.assertRaises(ValueError):
                history.verify_original_reviews(self.adk)
        with patch.object(history, "VALIDATORS", {"src/agent_dev_kit/review_evidence.py": "0" * 64}):
            with self.assertRaises(ValueError):
                history.verify_original_reviews(self.adk)

    def test_invalid_spec_even_with_new_pin_cannot_pass_original_validator(self) -> None:
        first = next(iter(history.RECORDS))
        record = self.adk / "docs/changes/archive" / ("20261020-" + first) / "review-evidence.json"
        row = json.loads(record.read_text(encoding="utf-8"))
        row["verdicts"]["spec"] = "fail"
        write_json(record, row)
        _git(self.adk, "add", ".")
        subprocess.run(
            ["git", "-C", str(self.adk), "-c", "user.name=Fixture",
             "-c", "user.email=fixture@example.invalid", "commit", "-qm", "Invalid original review"],
            check=True, capture_output=True,
        )
        _git(self.adk, "tag", "-d", "v8.0.36")
        subprocess.run(
            ["git", "-C", str(self.adk), "-c", "user.name=Fixture",
             "-c", "user.email=fixture@example.invalid",
             "tag", "-a", "v8.0.36", "-m", "Invalid fixture tag"],
            check=True, capture_output=True,
        )
        new_records = dict(history.RECORDS)
        digest, patch_digest, _ = new_records[first]
        new_records[first] = (_sha(record), patch_digest,
                              _git(self.adk, "rev-parse", "HEAD:docs/changes/archive/20261020-" + first))
        with patch.object(history, "TAG_OBJECT", _git(self.adk, "rev-parse", "refs/tags/v8.0.36")), \
                patch.object(history, "COMMIT", _git(self.adk, "rev-parse", "HEAD")), \
                patch.object(history, "TREE", _git(self.adk, "rev-parse", "HEAD^{tree}")), \
                patch.object(history, "RECORDS", new_records):
            with self.assertRaisesRegex(ValueError, "execution failed"):
                history.verify_original_reviews(self.adk)

    def test_symlink_and_traversal_tar_entries_cannot_be_extracted(self) -> None:
        for name, entry_type in (("outside/../../escape", tarfile.REGTYPE),
                                 ("src/agent_dev_kit/evil.py", tarfile.SYMTYPE)):
            data = io.BytesIO()
            with tarfile.open(fileobj=data, mode="w:") as bundle:
                item = tarfile.TarInfo(name)
                item.type = entry_type
                item.size = 0
                bundle.addfile(item)
            with tempfile.TemporaryDirectory() as target:
                with self.assertRaises(ValueError):
                    history._materialize(data.getvalue(), Path(target))

    def test_missing_original_files_and_invalid_review_bytes_reject(self) -> None:
        with tempfile.TemporaryDirectory() as target:
            with self.assertRaises(ValueError):
                history._materialize(b"", Path(target))
        with patch.object(history, "RECORDS", {cid: ("0" * 64, p, t)
                                               for cid, (_, p, t) in history.RECORDS.items()}):
            with self.assertRaises(ValueError):
                history.verify_original_reviews(self.adk)


if __name__ == "__main__":
    unittest.main()
