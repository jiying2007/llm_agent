from __future__ import annotations

import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from tools.codex_assets.maintainability_budget import BudgetError, evaluate
from tools.codex_assets.maintainability_evidence import generate_churn_candidate, write_candidate


UTC = timezone.utc
WINDOW_START = datetime(2026, 8, 29, 10, 0, tzinfo=UTC)
WINDOW_END = datetime(2026, 8, 29, 13, 0, tzinfo=UTC)
AS_OF = datetime(2026, 8, 29, 18, 0, tzinfo=UTC)


def run(root: Path, *args: str, env=None) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args], check=True, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env,
    )
    return result.stdout.strip()


class MaintainabilityEvidenceCandidateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "repo"
        self.root.mkdir()
        run(self.root, "init", "-q")
        run(self.root, "config", "user.name", "Fixture")
        run(self.root, "config", "user.email", "fixture@example.invalid")
        (self.root / "a.txt").write_text("one\n", encoding="utf-8")
        run(self.root, "add", "a.txt")
        first_env = dict(os.environ, GIT_AUTHOR_DATE="2026-08-29T11:00:00Z", GIT_COMMITTER_DATE="2026-08-29T11:00:00Z")
        run(self.root, "commit", "-q", "-m", "first", env=first_env)
        self.start = run(self.root, "rev-parse", "HEAD")
        (self.root / "a.txt").write_text("one\ntwo\n", encoding="utf-8")
        (self.root / "b.txt").write_text("new\n", encoding="utf-8")
        run(self.root, "add", "a.txt", "b.txt")
        second_env = dict(os.environ, GIT_AUTHOR_DATE="2026-08-29T12:00:00Z", GIT_COMMITTER_DATE="2026-08-29T12:00:00Z")
        run(self.root, "commit", "-q", "-m", "second", env=second_env)
        self.end = run(self.root, "rev-parse", "HEAD")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def candidate(self):
        return generate_churn_candidate(
            self.root, "fixture-repo", self.start, self.end,
            WINDOW_START, WINDOW_END, generated_at=AS_OF,
        )

    def test_candidate_is_complete_review_required_and_round_trips_evaluator(self) -> None:
        candidate = self.candidate()
        self.assertEqual("review-required", candidate["status"])
        self.assertFalse(candidate["review"]["backlog_mutation_performed"])
        self.assertEqual("none-candidate-only", candidate["review"]["promotion_authority"])
        evidence = candidate["evidence"]
        self.assertEqual(2, evidence["population"]["count"])
        self.assertEqual({"a.txt", "b.txt"}, {item["path"] for item in evidence["records"]})
        self.assertEqual(evidence["population"]["digest"], hashlib.sha256(
            json.dumps(["a.txt", "b.txt"], separators=(",", ":")).encode("utf-8")
        ).hexdigest())

        evidence_dir = self.root / "evidence"
        evidence_dir.mkdir()
        evidence_path = evidence_dir / "churn.json"
        evidence_path.write_text(json.dumps(evidence, sort_keys=True), encoding="utf-8")
        source = {
            "path": "evidence/churn.json",
            "sha256": hashlib.sha256(evidence_path.read_bytes()).hexdigest(),
            "schema": evidence["schema"],
            "repository_id": "fixture-repo",
            "source_kind": "git-history-numstat",
            "window": evidence["window"],
        }

        def axis(metric, source_value=None, population=None):
            return {
                "id": "fixture-" + metric.replace("_", "-"), "metric": metric,
                "risk": "medium", "enforcement": "report-only",
                "enforcement_rationale": "fixture report only", "source": source_value,
                "expected_repository_id": "fixture-repo", "expected_population": population,
                "max_age_days": 30,
                **({} if source_value else {"unavailable_reason": "fixture source unavailable"}),
                "owner": "fixture-owner", "next_action": "review candidate",
            }

        config = {
            "schema_version": 2,
            "maintainability_budgets": {
                "schema": "llm-agent-maintainability-budgets/v2", "baseline_date": "2026-08-29",
                "budgets": [{
                    "id": "text-count", "metric": "file_count", "scope_paths": ["."],
                    "include_patterns": ["*.txt"], "exclude_prefixes": [".git"],
                    "baseline": 2, "warning_limit": 3, "hard_limit": 4,
                    "owner": "fixture-owner", "next_action": "review",
                }],
                "evidence_metrics": [
                    axis("churn", source, evidence["population"]),
                    axis("owner_concentration"), axis("inactive_assets"),
                ],
            },
        }
        config_path = self.root / "config.json"
        config_path.write_text(json.dumps(config), encoding="utf-8")
        report = evaluate(self.root, config_path, False, "fixture-repo", as_of=AS_OF)
        self.assertEqual("measured", report["semantic_axes"]["churn"]["status"])
        self.assertEqual(1, report["semantic_axes"]["churn"]["observed"])

    def test_ancestry_window_privacy_and_output_fail_closed(self) -> None:
        with self.assertRaisesRegex(BudgetError, "ancestor window"):
            generate_churn_candidate(
                self.root, "fixture-repo", self.end, self.start,
                WINDOW_START, WINDOW_END, generated_at=AS_OF,
            )
        with self.assertRaisesRegex(BudgetError, "does not contain"):
            generate_churn_candidate(
                self.root, "fixture-repo", self.start, self.end,
                datetime(2026, 8, 29, 11, 30, tzinfo=UTC), WINDOW_END, generated_at=AS_OF,
            )
        with self.assertRaisesRegex(BudgetError, "secret"):
            generate_churn_candidate(
                self.root, "sk-abcdefghijklmnop", self.start, self.end,
                WINDOW_START, WINDOW_END, generated_at=AS_OF,
            )

        candidate = self.candidate()
        output = Path(self.temporary.name) / "candidate.json"
        self.assertEqual(output, write_candidate(candidate, output, self.root))
        with self.assertRaisesRegex(BudgetError, "already exists"):
            write_candidate(candidate, output, self.root)

        target_dir = Path(self.temporary.name) / "target"
        target_dir.mkdir()
        link = Path(self.temporary.name) / "output-link"
        link.symlink_to(target_dir, target_is_directory=True)
        with self.assertRaisesRegex(BudgetError, "symlink"):
            write_candidate(candidate, link / "candidate.json", self.root)


if __name__ == "__main__":
    unittest.main()
