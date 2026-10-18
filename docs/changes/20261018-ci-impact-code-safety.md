# CI impact: require deep integration for changed implementation surfaces

Date: 2026-10-18

## Problem

The canonical `tools.control_plane.impact.calculate_impact` requires deep integration only when a **direct** matching Gate owns an `integration-deep` group. The existing `root-regression` Gate owned executable and test surfaces (`tools/`, `tests/`, `scripts/`, `manifests/`) but lacked that group. A high-risk reader or its test could report `NOT_REQUIRED` despite downstream impact.

## Decision

Tag the existing `root-regression` Gate as `integration-deep`, without adding a path matcher, a new Gate, a duplicate SSOT or modifying Python impact semantics. Direct changes in `tools/`, `tests/`, `scripts/` and `manifests/` now require the existing full `integration-extra` profile and exact-source consumer evidence. Pure `docs/` changes and unrelated README edits retain fast CI. This intentionally prioritizes safety over CI time until real measurements justify finer declarative policy.

## Verification

The always-run `tests/test_ci_incremental_gate_dag.sh` asserts positive cases for practice intake, runtime smoke evidence, longitudinal certifier, representative tests, scripts and manifests, and retains documentation-only negative cases. Both protected PR and post-merge main must pass required checks, including `integration-impact`, `integration-summary` and `software-m5-certify`.

## Non-claims

No new Software M5 runtime or field certification, G21/G22 evidence, LTA-04 observation, or Owner approval is implied. The `release_authorized=false` boundary remains unchanged.

## Rollback

Revert through a protected PR only after a replacement declarative impact strategy proves that critical code changes cannot silently produce `NOT_REQUIRED`.
