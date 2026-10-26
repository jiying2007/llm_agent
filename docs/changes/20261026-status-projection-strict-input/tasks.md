# Delivery checklist

- [x] Use existing strict JSON decoder for status source inputs.
- [x] Reject duplicate lock and projected-status field keys.
- [x] Add JSON ambiguity, bounds, symlink and duplicate-field regression tests.
- [x] Recompute generated projection digest from exact content SHA.
- [ ] Pass Root protected CI including all status projection and source-split regressions.
- [ ] Merge with exact-head and verify fresh-main CI.
- [ ] Preserve G21/G22/LTA-04 and current-source Product M5 genuine evidence requirements.
