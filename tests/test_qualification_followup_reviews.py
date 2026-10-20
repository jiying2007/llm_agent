"""Delegated-review consumer contracts using isolated synthetic evidence only."""
from __future__ import annotations

import copy
import io
import json
import subprocess
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest import mock

from delegated_review_fixtures import policy_fixture, review_fixture, sha, timestamp, write_json

from tools.control_plane import effect_readiness as effect
from tools.control_plane import longitudinal_operation as longitudinal


class EffectDelegatedReviewTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="effect-delegated-review-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.adk = self.root / "agent-dev-kit"
        self.now = datetime.now(UTC).replace(microsecond=0) - timedelta(seconds=2)
        policy_fixture(self.adk, self.now)
        self.names = ("campaign", "comparison", "authority_contract", "authority_registry", "receipts",
                      "measurement", "preregistration_package", "preregistration_bundle")
        self.paths = {name: self.root / "reports/fixture" / (name + ".json") for name in self.names}
        for name, path in self.paths.items():
            write_json(path, {"synthetic_only": True, "name": name})
        self.owner_path = self.root / "reports/fixture/owner-review.json"
        self.record_path = self.root / "reports/fixture/review-evidence.json"
        self.assets = {("skill", "fixture-skill")}
        self.observed = {"success": True, "failure": True, "wrong_route": True, "abstain": True}
        self.review = {
            "schema": effect.OWNER_REVIEW_SCHEMA, "status": "approved", "campaign_id": "fixture-campaign",
            **{name + "_sha256": sha(path) for name, path in self.paths.items()},
            "reviewed_at": timestamp(self.now), "reviewed_by": "fixture-ai-reviewer",
            "reviewer_role": "owner-delegated-ai", "automation_generated": True,
            "observed_cases": self.observed.copy(),
            "asset_decisions": [{"asset_id": "fixture-skill", "asset_kind": "skill", "decision": "retain"}],
            "raw_content_stored": False, "release_authorized": False,
            "lifecycle_authority": "owner-review-recorded-execution-separate",
        }
        self.completed = self.now - timedelta(seconds=1)
        self.refresh()

    def refresh(self) -> None:
        write_json(self.owner_path, self.review)
        self.record = review_fixture(self.root, self.record_path, subject="fixture-campaign", scope="effect-value-review",
                                     sources=[*self.paths.values(), self.owner_path], reviewed_at=self.now,
                                     completed_at=self.completed, policy_root=self.adk)
        self.record_sha = sha(self.record_path)

    def write_record(self) -> None:
        write_json(self.record_path, self.record)
        self.record_sha = sha(self.record_path)

    def validate(self) -> dict[tuple[str, str], str]:
        return effect._validate_owner_review(
            self.review, root=self.root, adk=self.adk, review_evidence_path=self.record_path,
            review_evidence_sha256=self.record_sha,
            reviewed_sources={path: sha(path) for path in (*self.paths.values(), self.owner_path)},
            campaign_id="fixture-campaign", **{name + "_sha256": sha(path) for name, path in self.paths.items()},
            evidence_completed_at=self.completed, observed_cases=self.observed, measurement_assets=self.assets,
        )

    def test_delegated_review_accepts_complete_bound_effect_decisions(self) -> None:
        self.assertEqual(self.validate(), {("skill", "fixture-skill"): "retain"})

    def test_uninstalled_optional_adk_fails_closed_at_runtime(self):
        with (
            mock.patch("tools.control_plane.adk_interface.importlib.import_module", side_effect=ModuleNotFoundError("fixture missing ADK")),
            self.assertRaisesRegex(ValueError, "unavailable or unsafe"),
        ):
            self.validate()

    def test_shared_review_api_must_return_a_string_keyed_object(self):
        for result in (None, [], {1: "invalid key"}):
            with (
                self.subTest(result=result),
                mock.patch("agent_dev_kit.review_evidence.validate_review", return_value=result),
                self.assertRaisesRegex(ValueError, "invalid result object"),
            ):
                self.validate()

    def test_installed_validator_must_equal_all_three_pinned_modules(self) -> None:
        for name in ("review_evidence", "strict_json", "readiness_evidence"):
            with self.subTest(module=name):
                path = self.adk / "src/agent_dev_kit" / (name + ".py")
                original = path.read_bytes()
                path.write_bytes(original + b"\n# synthetic pin drift\n")
                with self.assertRaisesRegex(ValueError, "differs from the pinned source"):
                    self.validate()
                path.write_bytes(original)

    def test_missing_or_symlinked_pinned_module_fails_closed(self) -> None:
        path = self.adk / "src/agent_dev_kit/review_evidence.py"
        original = path.read_bytes()
        path.unlink()
        with self.assertRaises(ValueError):
            self.validate()
        other = self.root / "copy.py"
        other.write_bytes(original)
        path.symlink_to(other)
        with self.assertRaises(ValueError):
            self.validate()

    def test_policy_bytes_cannot_drift_after_review(self) -> None:
        policy = self.adk / ".adk/review-policy.json"
        policy.write_bytes(policy.read_bytes() + b"\n")
        with self.assertRaises(ValueError):
            self.validate()

    def test_rehashed_dirty_policy_is_not_the_committed_authority(self) -> None:
        path = self.adk / ".adk/review-policy.json"
        path.write_bytes(path.read_bytes() + b"\n")
        self.record["policy_sha256"] = sha(path)
        self.write_record()
        with self.assertRaisesRegex(ValueError, "worktree differs from the exact pin"):
            self.validate()

    def test_rehashed_authorization_cannot_replace_the_pinned_owner_grant(self) -> None:
        policy_path = self.adk / ".adk/review-policy.json"
        policy = json.loads(policy_path.read_text(encoding="utf-8"))
        authorization = self.adk / policy["authorization"]["path"]
        authorization.write_text("Different synthetic grant; not committed at the pin.\n", encoding="utf-8")
        policy["authorization"]["sha256"] = sha(authorization)
        write_json(policy_path, policy)
        self.record["policy_sha256"] = sha(policy_path)
        self.write_record()
        with self.assertRaisesRegex(ValueError, "worktree differs from the exact pin"):
            self.validate()

    def test_staged_authority_is_not_the_committed_pin(self) -> None:
        path = self.adk / ".adk/review-policy.json"
        path.write_bytes(path.read_bytes() + b"\n")
        subprocess.run(["git", "-C", str(self.adk), "add", "--", ".adk/review-policy.json"], check=True, capture_output=True)
        self.record["policy_sha256"] = sha(path)
        self.write_record()
        with self.assertRaisesRegex(ValueError, "not committed at the exact pin"):
            self.validate()

    def test_rehashed_loaded_validator_still_requires_its_committed_blob(self) -> None:
        from agent_dev_kit import review_evidence

        path = self.adk / "src/agent_dev_kit/review_evidence.py"
        path.write_bytes(path.read_bytes() + b"\n# synthetic installed source drift\n")
        with mock.patch.object(review_evidence, "__file__", str(path)):
            self.record["validator_sha256"] = review_evidence.validator_fingerprints()
            self.write_record()
            with self.assertRaisesRegex(ValueError, "worktree differs from the exact pin"):
                self.validate()

    def test_unmatched_adk_commit_is_not_the_parent_gitlink(self) -> None:
        subprocess.run(["git", "-C", str(self.adk), "-c", "user.name=Synthetic Fixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "--allow-empty", "-qm", "Unpinned synthetic ADK commit"], check=True, capture_output=True)
        with self.assertRaisesRegex(ValueError, "HEAD differs from the parent Git pin"):
            self.validate()

    def test_author_cannot_act_as_independent_reviewer(self) -> None:
        self.record["author_id"] = self.record["reviewer"]["id"]
        self.write_record()
        with self.assertRaises(ValueError):
            self.validate()

    def test_review_must_bind_all_original_material_and_decision_bytes(self) -> None:
        sources = copy.deepcopy(self.record["sources"])
        for index in range(len(sources)):
            with self.subTest(omitted=index):
                self.record["sources"] = sources[:index] + sources[index + 1:]
                self.write_record()
                with self.assertRaisesRegex(ValueError, "complete effect decision and evidence"):
                    self.validate()

    def test_changed_decision_is_not_covered_by_an_older_review(self) -> None:
        self.review["asset_decisions"][0]["decision"] = "reject-change"
        write_json(self.owner_path, self.review)
        with self.assertRaises(ValueError):
            self.validate()

    def test_review_identity_and_timestamp_match_the_decision(self) -> None:
        original = copy.deepcopy(self.review)
        for field, value in (("reviewed_by", "ai/different-reviewer"),
                             ("reviewed_at", timestamp(self.now + timedelta(seconds=1)))):
            with self.subTest(field=field):
                self.review = copy.deepcopy(original)
                self.review[field] = value
                self.refresh()
                with self.assertRaisesRegex(ValueError, "identity or timestamp differs"):
                    self.validate()

    def test_delegated_review_cannot_predate_completed_evidence(self) -> None:
        self.record["evidence_completed_at"] = timestamp(self.completed - timedelta(seconds=1))
        self.write_record()
        with self.assertRaisesRegex(ValueError, "predates completed effect evidence"):
            self.validate()

    def test_ai_review_cannot_claim_to_be_human_or_unautomated(self) -> None:
        for field, value in (("reviewer_role", "owner"), ("automation_generated", False)):
            with self.subTest(field=field):
                original = self.review[field]
                self.review[field] = value
                self.refresh()
                with self.assertRaisesRegex(ValueError, "honestly identify"):
                    self.validate()
                self.review[field] = original

    def test_wrong_scope_or_record_digest_fails(self) -> None:
        self.record["scope"] = "longitudinal-review"
        self.write_record()
        with self.assertRaises(ValueError):
            self.validate()
        self.refresh()
        self.record_sha = "0" * 64
        with self.assertRaisesRegex(ValueError, "digest differs from index"):
            self.validate()

    def test_observed_cases_must_still_cover_actual_verified_receipts(self) -> None:
        self.review["observed_cases"]["failure"] = False
        self.refresh()
        with self.assertRaisesRegex(ValueError, "observed cases"):
            self.validate()

    def test_every_measured_asset_still_requires_a_decision(self) -> None:
        self.assets.add(("agent", "fixture-second-agent"))
        with self.assertRaisesRegex(ValueError, "cover every measured asset"):
            self.validate()


class LongitudinalDelegatedReviewTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory(prefix="lta-delegated-review-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.now = datetime.now(UTC).replace(microsecond=0) - timedelta(seconds=2)
        self.started = self.now - timedelta(days=31)
        self.through = self.now - timedelta(hours=1)
        self.adk = self.root / "agent-dev-kit"
        policy_fixture(self.adk, self.now)
        self.summary_path = self.root / "reports/long-term-assets/longitudinal-operation-current.json"
        self.record_path = self.root / "reports/long-term-assets/review-evidence.json"
        self.event_log = self.root / "reports/field-evidence/events.jsonl"
        self.manifest_path = self.root / "manifests/long_term_asset_qualification.json"
        self.ledger_path = self.root / "manifests/software_m5_pilot_ledger.json"
        self.requirement = {
            "id": "LTA-04", "status": "observation_window_in_progress", "implementation_status": "certifier-ready",
            "pilot_id": "fixture-independent", "repository_id": "fixture-repo", "minimum_calendar_days": 30,
            "default_evidence_path": self.summary_path.relative_to(self.root).as_posix(),
        }
        write_json(self.manifest_path, {"schema": longitudinal.LTA_SCHEMA, "qualification_requirements": [self.requirement]})
        write_json(self.ledger_path, {
            "schema": longitudinal.LEDGER_SCHEMA, "event_log": self.event_log.relative_to(self.root).as_posix(),
            "repositories": [{"id": "fixture-repo", "path": "external", "classification": "independent", "real_software": True}],
            "operators": [{"id": "fixture-human", "operator_type": "human", "role": "repository-owner", "independent_reviewer": False}],
            "pilots": [{"id": "fixture-independent", "environment_class": "independent", "status": "active",
                        "started_at": timestamp(self.started), "ended_at": None, "repositories": ["fixture-repo"],
                        "operators": ["fixture-human"]}],
        })
        self.events = []
        for event_id, event_type, occurred in (("fixture-start", "pilot_started", self.started),
                                                ("fixture-final", "pilot_observed", self.through)):
            path = self.root / "reports/field-evidence" / (event_id + ".json")
            write_json(path, {"synthetic_fixture_only": True, "event": event_id})
            relative = path.relative_to(self.root).as_posix()
            self.events.append({
                "schema": longitudinal.EVENT_SCHEMA, "sequence": len(self.events) + 1, "event_id": event_id,
                "pilot_id": "fixture-independent", "repository_id": "fixture-repo", "event_type": event_type,
                "occurred_at": timestamp(occurred), "recorded_at": timestamp(occurred), "evidence_layer": "field",
                "operator_id": "fixture-human", "summary": "Synthetic isolated fixture only", "evidence": [relative],
                "evidence_sha256": {relative: sha(path)}, "metrics": {},
            })
        self.summary = {
            "schema": longitudinal.EVIDENCE_SCHEMA, "qualification": "LTA-04", "status": "complete",
            "pilot_id": "fixture-independent", "repository_id": "fixture-repo",
            "observation": {"started_at": timestamp(self.started), "observed_through": timestamp(self.through)},
            "source": {}, "outcomes": {"incidents": {"count": 0, "event_ids": []},
                                        "regressions": {"count": 0, "event_ids": []},
                                        "recoveries": {"count": 0, "event_ids": []}, "unresolved_risks": []},
            "review": {"mode": "owner-delegated-ai", "reviewer_id": "fixture-ai-reviewer",
                       "standard": "owner-delegated-ai-review-v1", "decision": "approve", "reviewed_at": timestamp(self.now),
                       "evidence_path": self.record_path.relative_to(self.root).as_posix()},
        }
        self.refresh()

    def refresh(self) -> None:
        previous = longitudinal.ZERO_HASH
        for event in self.events:
            event.pop("event_hash", None)
            event["previous_hash"] = previous
            event["event_hash"] = longitudinal._digest(event)
            previous = event["event_hash"]
        self.event_log.write_text("".join(json.dumps(event, sort_keys=True) + "\n" for event in self.events), encoding="utf-8")
        self.summary["source"] = {"event_log": self.event_log.relative_to(self.root).as_posix(), "event_log_sha256": sha(self.event_log),
                                  "event_chain_head": previous, "event_count": len(self.events)}
        self.summary.pop("summary_sha256", None)
        self.summary["summary_sha256"] = longitudinal._digest(self.summary)
        write_json(self.summary_path, self.summary)
        self.record = review_fixture(self.root, self.record_path, subject="lta-04/fixture-independent", scope="longitudinal-review",
                                     sources=[self.summary_path, self.ledger_path, self.manifest_path], reviewed_at=self.now,
                                     completed_at=self.through, policy_root=self.adk)

    def validate(self) -> dict:
        return longitudinal.check(self.root, as_of=self.now)

    def test_ai_summary_review_has_a_reachable_valid_path(self) -> None:
        result = self.validate()
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["review_mode"], "owner-delegated-ai")
        self.assertEqual(result["reviewer_id"], "fixture-ai-reviewer")
        self.assertIn(self.record_path.relative_to(self.root).as_posix(), result["review_evidence_files"])

    def test_time_travel_cli_cannot_claim_terminal_qualification(self) -> None:
        output = io.StringIO()
        with redirect_stdout(output):
            code = longitudinal.main(["--root", str(self.root), "--as-of", timestamp(self.now), "--summary-json"])
        result = json.loads(output.getvalue())
        self.assertEqual(code, 0)
        self.assertEqual(result["status"], "simulated_pass")
        self.assertIs(result["terminal_qualified"], False)

    def test_ai_review_cannot_replace_a_terminal_field_observation(self) -> None:
        self.events.pop()
        self.refresh()
        with self.assertRaisesRegex(longitudinal.LongitudinalBlocked, "end-window-field-evidence-missing"):
            self.validate()

    def test_ai_reviewer_does_not_become_a_registered_field_actor(self) -> None:
        self.events[-1]["operator_id"] = "fixture-ai-reviewer"
        self.refresh()
        with self.assertRaises(longitudinal.LongitudinalError):
            self.validate()

    def test_synthetic_layer_is_rejected_even_with_rehashed_ai_review(self) -> None:
        self.events[-1]["evidence_layer"] = "synthetic"
        self.refresh()
        with self.assertRaises(longitudinal.LongitudinalError):
            self.validate()

    def test_field_material_digest_drift_cannot_be_approved_by_summary_review(self) -> None:
        path = self.root / self.events[-1]["evidence"][0]
        path.write_bytes(path.read_bytes() + b"\n")
        with self.assertRaises(longitudinal.LongitudinalError):
            self.validate()

    def test_summary_pilot_and_review_scope_must_match(self) -> None:
        self.summary["pilot_id"] = "wrong-pilot"
        self.refresh()
        with self.assertRaises(longitudinal.LongitudinalError):
            self.validate()
        self.summary["pilot_id"] = "fixture-independent"
        self.refresh()
        self.record["subject_id"] = "lta-04/wrong-pilot"
        write_json(self.record_path, self.record)
        with self.assertRaises(longitudinal.LongitudinalError):
            self.validate()

    def test_review_must_bind_summary_and_both_source_contracts(self) -> None:
        sources = copy.deepcopy(self.record["sources"])
        for index in range(len(sources)):
            with self.subTest(omitted=index):
                self.record["sources"] = sources[:index] + sources[index + 1:]
                write_json(self.record_path, self.record)
                with self.assertRaisesRegex(longitudinal.LongitudinalError, "omits its summary or source contracts"):
                    self.validate()

    def test_review_identity_completion_and_hold_remain_enforced(self) -> None:
        self.record["reviewer"]["id"] = "ai/other-reviewer"
        write_json(self.record_path, self.record)
        with self.assertRaises(longitudinal.LongitudinalError):
            self.validate()
        self.refresh()
        self.record["evidence_completed_at"] = timestamp(self.through - timedelta(seconds=1))
        write_json(self.record_path, self.record)
        with self.assertRaisesRegex(longitudinal.LongitudinalError, "predates completed field evidence"):
            self.validate()
        self.summary["review"]["decision"] = "hold"
        self.refresh()
        with self.assertRaisesRegex(longitudinal.LongitudinalBlocked, "review-hold"):
            self.validate()

    def test_live_review_requires_exact_adk_and_committed_review_inputs(self) -> None:
        with (
            mock.patch("tools.control_plane.adk_interface.validate", return_value={"status": "fail"}),
            self.assertRaisesRegex(longitudinal.LongitudinalError, "exact pinned ADK"),
        ):
            longitudinal.check(self.root)
        with (
            mock.patch("tools.control_plane.adk_interface.validate", return_value={"status": "pass"}),
            mock.patch.object(longitudinal, "_verify_committed_evidence") as committed,
        ):
            result = longitudinal.check(self.root)
        self.assertEqual(result["status"], "pass")
        checked_paths = committed.call_args.args[1]
        self.assertTrue({self.record_path, self.summary_path, self.ledger_path, self.manifest_path} <= checked_paths)
        for event in self.events:
            self.assertTrue({self.root / path for path in event["evidence"]} <= checked_paths)


if __name__ == "__main__":
    unittest.main()
