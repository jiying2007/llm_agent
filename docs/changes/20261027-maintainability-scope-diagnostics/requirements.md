# Maintainability scope diagnostics

The existing first-parent complete-population churn candidate currently mixes production code and archived audit evidence. Make it easier to triage real maintenance hotspots without excluding any records, mutating the original evidence digest, introducing an additional CI gate, or promoting an unreviewed baseline.

Acceptance: report-only, stable category boundaries, exact sum of changed-line counts across all classes, active changed-file counts distinct from full population, no new runtime/provider spending or external data capture.
