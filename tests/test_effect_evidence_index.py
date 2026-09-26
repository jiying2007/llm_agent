from __future__ import annotations

import copy
import hashlib
import json
import runpy
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.control_plane import effect_readiness as readiness

ROOT = Path(__file__).resolve().parents[1]
ADK = ROOT / "agent-dev-kit"


def write_json(path: Path, value: dict) -> str:
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )
    return hashlib.sha256(path.read_bytes()).hexdigest()


class EffectEvidenceIndexTest(unittest.TestCase):
    def setUp(self) -> None:
        evidence_root = ROOT / "reports" / "effect-evidence"
        evidence_root.mkdir(parents=True, exist_ok=True)
        self.temp = Path(
            tempfile.mkdtemp(prefix="evidence-index-test-", dir=evidence_root)
        )
        self.addCleanup(lambda: shutil.rmtree(self.temp, ignore_errors=True))

        effect = runpy.run_path(str(ADK / "tests" / "test_effect_trials.py"))
        value = runpy.run_path(str(ADK / "tests" / "test_agent_value.py"))

        self.trial = effect["document"]()
        self.comparison = effect["compare_effect_trials"](
            self.trial, effect["MANIFEST"]
        )
        candidate_bundle = self.trial["plan"]["bundles"]["candidate"]

        receipts = []
        for asset_id, asset_kind, signal in (
            ("requirements-analyst", "agent", "retain"),
            ("adk-runtime-router", "skill", "consolidate-candidate"),
        ):
            item = value["receipt"](
                asset_id,
                asset_kind,
                marker="8" if asset_kind == "agent" else "9",
                evidence_layer="runtime",
            )
            item["asset_bundle_sha256"] = candidate_bundle
            item["retirement_signal"] = signal
            receipts.append(value["attest"](item))

        profile = value["receipt"](
            "core", "profile", marker="a", evidence_layer="runtime"
        )
        profile["asset_bundle_sha256"] = candidate_bundle
        profile["routing"] = {
            "routed": False,
            "abstained": True,
            "wrong_route": False,
        }
        profile["outcome"] = "abstained"
        profile.pop("first_pass")
        profile["abstain_correct"] = True
        profile["retirement_signal"] = "retain"
        receipts.append(value["attest"](profile))
        self.receipts = receipts

        managed = value["managed_contract"]()
        self.measurement = value["emit"](
            receipts, contract=managed, evidence_verifier=value["test_verifier"]
        )
        self.assertEqual(self.measurement["evidence_scope"], "runtime-verified")
        self.assertFalse(self.measurement["quality_evidence_eligible"])

        self.trial_path = self.temp / "trial-input.json"
        self.comparison_path = self.temp / "comparison.json"
        self.measurement_path = self.temp / "measurement.json"
        self.trial_sha = write_json(self.trial_path, self.trial)
        self.comparison_sha = write_json(self.comparison_path, self.comparison)
        self.measurement_sha = write_json(self.measurement_path, self.measurement)

        self.receipt_refs = []
        for index, receipt in enumerate(receipts):
            path = self.temp / f"receipt-{index}.json"
            digest = write_json(path, receipt)
            self.receipt_refs.append(
                {"path": path.relative_to(ROOT).as_posix(), "sha256": digest}
            )

        self.review_path = self.temp / "owner-review.json"
        self.review = {
            "schema": "llm-agent-effect-owner-review/v1",
            "campaign_id": self.trial["plan"]["campaign_id"],
            "decision": "accept-evidence",
            "owner": "fixture-owner",
            "reviewed_at": "2026-09-25T00:00:00Z",
            "evidence": {
                "trial_input_sha256": self.trial_sha,
                "comparison_sha256": self.comparison_sha,
                "measurement_sha256": self.measurement_sha,
                "candidate_bundle_sha256": candidate_bundle,
            },
            "lifecycle_reviews": [
                {
                    "asset_kind": "agent",
                    "asset_id": "requirements-analyst",
                    "decision": "retain",
                    "rationale": "Measured runtime evidence supports retaining this agent for the reviewed campaign.",
                },
                {
                    "asset_kind": "skill",
                    "asset_id": "adk-runtime-router",
                    "decision": "consolidate-candidate",
                    "rationale": "Measured runtime evidence records this skill as a consolidation candidate for owner follow-up.",
                },
                {
                    "asset_kind": "profile",
                    "asset_id": "core",
                    "decision": "retain",
                    "rationale": "Measured abstain evidence supports retaining the reviewed core profile without automatic mutation.",
                },
            ],
            "rationale": "The fixture accepts the bounded evidence chain only to verify readiness state transitions.",
            "auto_apply": False,
            "release_authorized": False,
        }
        self.review_sha = write_json(self.review_path, self.review)

    def evidence_ref(self, path: Path, digest: str) -> dict:
        return {"path": path.relative_to(ROOT).as_posix(), "sha256": digest}

    def index(self, review_sha: str | None = None) -> dict:
        return {
            "schema": "llm-agent-effect-value-evidence-index/v1",
            "status": "active",
            "policy": {
                "evidence_root": "reports/effect-evidence",
                "required_asset_kinds": ["agent", "skill", "profile"],
                "minimum_accepted_campaigns": 1,
                "require_decisive_trial_verdict": True,
                "require_runtime_or_field_measurement": True,
                "require_owner_review": True,
                "auto_lifecycle_mutation": False,
                "release_authorized": False,
            },
            "campaigns": [
                {
                    "id": "evc-11111111111111111111",
                    "campaign_id": self.trial["plan"]["campaign_id"],
                    "trial_input": self.evidence_ref(
                        self.trial_path, self.trial_sha
                    ),
                    "comparison": self.evidence_ref(
                        self.comparison_path, self.comparison_sha
                    ),
                    "receipts": list(self.receipt_refs),
                    "measurement": self.evidence_ref(
                        self.measurement_path, self.measurement_sha
                    ),
                    "owner_review": self.evidence_ref(
                        self.review_path, review_sha or self.review_sha
                    ),
                }
            ],
        }

    def evaluate(self, index: dict) -> dict:
        with patch.object(
            readiness, "_canonical_measurement", return_value=self.measurement
        ):
            return readiness._evaluate_evidence_index(
                ROOT, ADK, index, authority_enabled=True
            )

    def test_complete_chain_can_transition_to_ready(self) -> None:
        result = self.evaluate(self.index())
        self.assertTrue(result["ready"], result)
        self.assertEqual(result["accepted_campaign_count"], 1)
        self.assertEqual(
            set(result["asset_kinds_covered"]), {"agent", "skill", "profile"}
        )
        self.assertTrue(all(result["signal_coverage"].values()), result)
        self.assertTrue(result["retirement_signal_observed"])
        campaign = result["campaigns"][0]
        self.assertTrue(campaign["accepted"], campaign)
        self.assertEqual(campaign["comparison_verdict"], "improved")
        self.assertTrue(campaign["measurement_verified"])
        self.assertEqual(campaign["receipt_count"], 3)

    def test_rejected_owner_review_is_valid_but_not_ready(self) -> None:
        review = copy.deepcopy(self.review)
        review["decision"] = "reject-evidence"
        review["rationale"] = (
            "The owner rejects this bounded fixture evidence and therefore it must not close readiness."
        )
        digest = write_json(self.review_path, review)
        result = self.evaluate(self.index(digest))
        self.assertFalse(result["ready"], result)
        self.assertEqual(result["accepted_campaign_count"], 0)
        self.assertFalse(result["campaigns"][0]["accepted"])

    def test_digest_and_owner_coverage_fail_closed(self) -> None:
        corrupted = self.index()
        corrupted["campaigns"][0]["measurement"]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            self.evaluate(corrupted)

        review = copy.deepcopy(self.review)
        review["lifecycle_reviews"].pop()
        digest = write_json(self.review_path, review)
        with self.assertRaisesRegex(ValueError, "does not cover exactly"):
            self.evaluate(self.index(digest))


if __name__ == "__main__":
    unittest.main()
