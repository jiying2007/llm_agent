# Dirty Baseline Review

Date: 2026-06-26
Mode: explicit-review
Status: pass

## Scope

Reviewed observe-mode dirty baselines that were due on 2026-06-29:

| Repo | Decision | Change count | Fingerprint | Next review |
|---|---|---:|---|---|
| `OpenSpec` | renew observe baseline | 655 | `385f220663e442f93e150c5b1397cb334f3c99c0dbc83a44e0b7a9c475f99d23` | 2026-07-10 |
| `superpowers` | renew observe baseline | 115 | `de009e378c682c59be9ee534ac63bcfbcda952068b0ff1186cff0404f2f109a2` | 2026-07-10 |
| `vibeflow` | renew observe baseline | 216 | `d5c55b29c57e876243e20868252b49e13ec7cd06759bef596f87e03d067260cd` | 2026-07-10 |

## Evidence

- `rtk scripts/check-subrepo-state.sh .`: pass
- `rtk scripts/check-subrepo-state.sh . --summary-json`: `{"status":"pass","clean":2,"dirty":3,"known_dirty":3,"unexpected_dirty":0,"stale_baseline":0,"uninitialized":0,"missing":0,"strict":0}`

## Decision Rationale

The current dirty state is unchanged from the registered observe baseline:

- No fingerprint mismatch was reported.
- `unexpected_dirty=0`, so the baseline is not hiding a new unreviewed dirty state.
- `agent-dev-kit` remains strict and clean.
- `scale-engine` remains observe and clean.

The baseline is renewed for 14 days only. This keeps the local reference repositories available for absorption while preserving a short review window.

## Boundary

This review does not clean, revert, sync, absorb, install, execute upstream code, or change reference repository contents. It only records the current known-dirty state and extends the explicit review window in `subrepos/dirty-baseline.tsv`.
