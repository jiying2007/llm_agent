"""Independent method-intake review; all generated outputs are temporary.

Reviewer: ai/root/external_methods. Does not fetch or execute upstream content.
"""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from urllib.parse import urlsplit

from tools.codex_assets.practice_intake import _jsonl_bytes

ROOT = Path(__file__).resolve().parents[4]
CHANGE = ROOT / "docs/changes/20261023-evidence-methods"
CLI = ROOT / "scripts/practice-intake.sh"
DATE = "2026-10-23"


def rows(path):
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]


def invoke(*arguments):
    return subprocess.run([str(CLI), *map(str, arguments)], cwd=ROOT,
                          capture_output=True, text=True, timeout=30)


class IndependentMethodsReview(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="root-methods-independent-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)

    def test_real_twelve_source_public_replay_and_exact_change_scope(self):
        source = CHANGE / "source-metadata.jsonl"
        canonical = CHANGE / "candidates.jsonl"
        original_source_bytes = source.read_bytes()
        original_ledger_bytes = canonical.read_bytes()
        original_decisions_bytes = (CHANGE / "decisions.jsonl").read_bytes()
        generated = self.work / "candidates.jsonl"
        generated_evidence = self.work / "collection.json"
        result = invoke("collect", "--provider", "manual", "--input", source,
                        "--max-results", "12", "--as-of", DATE,
                        "--out", generated, "--evidence-out", generated_evidence)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(original_ledger_bytes, generated.read_bytes())
        observed = rows(generated)
        self.assertEqual(12, len(observed))
        self.assertEqual(12, len({row["candidate_id"] for row in observed}))
        expected_repositories = {"EXT-05": "addyosmani/agent-skills", "EXT-06": "mattpocock/skills",
                                 "EXT-07": "cursor/plugins", "EXT-08": "cursor/plugins"}
        for row in observed:
            if row["source_id"] in expected_repositories:
                self.assertEqual(expected_repositories[row["source_id"]], row["repository"]["full_name"])
            self.assertEqual("review-required", row["review_status"])
            self.assertEqual("unverified-metadata", row["trust_status"])
            self.assertFalse(row["body_persisted"])
            self.assertEqual([], row["auto_actions"])
        collection = json.loads((CHANGE / "collection.json").read_text())
        replay = json.loads(generated_evidence.read_text())
        self.assertEqual(hashlib.sha256(original_source_bytes).hexdigest(), replay["jobs"][0]["input_sha256"])
        self.assertEqual(hashlib.sha256(original_ledger_bytes).hexdigest(), replay["ledger_sha256"])
        collection["jobs"][0].pop("duration_ms")
        replay["jobs"][0].pop("duration_ms")
        self.assertEqual(collection, replay)

        # This hash was independently observed before the fix. Restoring only
        # the four former full_name values must reproduce the entire old ledger.
        legacy = copy.deepcopy(observed)
        for row in legacy:
            if row["source_id"] in expected_repositories:
                row["repository"]["full_name"] = urlsplit(row["canonical_url"]).path.strip("/")
        self.assertEqual("82033b320cd6ce3211f9499422e96c3952476b219fad29e98cbef8afb83cf35d",
                         hashlib.sha256(_jsonl_bytes(legacy)).hexdigest())
        self.assertEqual("4bad3191fac50362d3f30ff8290741cd258702c243ddb413da6e2d1e3b3372f6",
                         hashlib.sha256(original_source_bytes).hexdigest())
        self.assertEqual("3d3582391dc2fdf9fd79e67a9a3dbfc4174392df07965b7d0aac0e3294a4109b",
                         hashlib.sha256(original_decisions_bytes).hexdigest())
        self.assertEqual(original_source_bytes, source.read_bytes())
        self.assertEqual(original_ledger_bytes, canonical.read_bytes())
        self.assertEqual(original_decisions_bytes, (CHANGE / "decisions.jsonl").read_bytes())

    def test_public_url_forms_keep_resource_identity_and_repository_identity_separate(self):
        revision = "c" * 40
        prefix = "https://github.com/review-owner/review-repo"
        cases = [
            ("upper-host", prefix.replace("github.com", "GITHUB.com") + "/blob/" + revision + "/one.md",
             prefix + "/blob/" + revision + "/one.md", "review-owner/review-repo"),
            ("second-file", prefix + "/blob/" + revision + "/two.md",
             prefix + "/blob/" + revision + "/two.md", "review-owner/review-repo"),
            ("tree", prefix + "/tree/" + revision + "/docs", prefix + "/tree/" + revision + "/docs",
             "review-owner/review-repo"),
            ("commit", prefix + "/commit/" + revision, prefix + "/commit/" + revision,
             "review-owner/review-repo"),
            ("git-tree", prefix + ".git/tree/" + revision + "/docs",
             prefix + ".git/tree/" + revision + "/docs", "review-owner/review-repo"),
            ("owner-only", "https://github.com/review-owner", "https://github.com/review-owner", None),
            ("empty-repo", "https://github.com/review-owner/.git/blob/" + revision + "/one.md",
             "https://github.com/review-owner/.git/blob/" + revision + "/one.md", None),
            ("gitlab-subgroups", "https://gitlab.com/group/team/repo.git",
             "https://gitlab.com/group/team/repo", "group/team/repo"),
            ("gitee-control", "https://gitee.com/review-owner/review-repo",
             "https://gitee.com/review-owner/review-repo", "review-owner/review-repo"),
        ]
        source = self.work / "input.jsonl"
        source.write_text("".join(json.dumps({"source_id": name, "url": raw, "revision": revision}) + "\n"
                                  for name, raw, _, _ in cases), encoding="utf-8")
        output = self.work / "candidates.jsonl"
        result = invoke("collect", "--provider", "manual", "--input", source, "--as-of", DATE,
                        "--out", output, "--evidence-out", self.work / "evidence.json")
        self.assertEqual(0, result.returncode, result.stderr)
        indexed = {row["source_id"]: row for row in rows(output)}
        self.assertEqual(len(cases), len(indexed))
        for name, _, url, repository in cases:
            with self.subTest(name=name):
                row = indexed[name]
                self.assertEqual(url, row["canonical_url"])
                self.assertEqual(revision, row["revision"])
                self.assertEqual(repository, row["repository"]["full_name"] if row["repository"] else None)
                expected_id = "epc-" + hashlib.sha256(("manual\n" + url + "\n" + revision).encode()).hexdigest()[:20]
                self.assertEqual(expected_id, row["candidate_id"])
        self.assertNotEqual(indexed["upper-host"]["candidate_id"], indexed["second-file"]["candidate_id"])

    def test_untrusted_host_and_non_https_are_rejected_without_outputs(self):
        for index, url in enumerate(("https://github.com.example.invalid/owner/repo", "http://github.com/owner/repo")):
            with self.subTest(url=url):
                output = self.work / f"rejected-{index}.jsonl"
                evidence = self.work / f"rejected-{index}.json"
                result = invoke("collect", "--provider", "manual", "--url", url, "--as-of", DATE,
                                "--out", output, "--evidence-out", evidence)
                self.assertNotEqual(0, result.returncode)
                self.assertFalse(output.exists())
                self.assertFalse(evidence.exists())

    def test_sources_decisions_and_matrix_remain_one_to_one(self):
        sources = json.loads((CHANGE / "sources.json").read_text())["sources"]
        candidates = rows(CHANGE / "candidates.jsonl")
        decisions = {row["candidate_id"]: row for row in rows(CHANGE / "decisions.jsonl")}
        expected_ids = {source["id"] for source in sources}
        self.assertEqual(expected_ids, {row["source_id"] for row in candidates})
        self.assertEqual({row["candidate_id"] for row in candidates}, set(decisions))
        by_source = {row["source_id"]: decisions[row["candidate_id"]]["decision"] for row in candidates}
        matrix = {}
        for row in rows(ROOT / "subrepos/adoption-matrix.jsonl"):
            match = re.match(r"(EXT-\d{2})：", row["capability"])
            if row["date"] == DATE and match:
                self.assertNotIn(match[1], matrix)
                matrix[match[1]] = row
        self.assertEqual(expected_ids, set(matrix))
        for source_id, row in matrix.items():
            with self.subTest(source=source_id):
                self.assertEqual("adopt" if by_source[source_id] == "ENHANCE" else "observe", row["decision"])
                self.assertEqual("done", row["state"])
                self.assertEqual("llm_agent", row["target"])
                self.assertTrue(all((ROOT / value.strip()).exists() for value in row["evidence"].split(";")))
        self.assertEqual({"EXT-02", "EXT-10", "EXT-12"}, {key for key, value in by_source.items() if value == "OBSERVE"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
