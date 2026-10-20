# Retained validation evidence

This directory preserves the actual execution output, capture metadata, source identities and bounded diagnostic summaries used by the final delivery review of [Root PR #265](https://github.com/jiying2007/llm_agent/pull/265). The interpretation is in [verification](../verify-report.md) and [negative results](../negative-results.md).

The frozen validation source was Root C1 `5170d970e3a69ba8d8938e968fb82bee1ff37a7d` plus the six staged promotion paths, with ADK `42ae95d146ceb441ff91ea33dbbed581c33de305` / v8.0.36. C2 remote tree `92e835c84609cbb3ab82cc0b6ee227e7470e5e7a` contains that source and promotion. This later evidence/documentation increment changes Root's snapshot. The earlier capture identities therefore describe their actual execution checkpoint, rather than a future final-head or main receipt.

## Original bytes and storage mapping

[retention-manifest.json](retention-manifest.json) records all 55 retained files, their original execution paths, original bytes/SHA-256, stored bytes/SHA-256 and encoding. Most files retain their exact original UTF-8 bytes. Original absolute paths describe where execution happened; the manifest maps them to the files retained here.

Two transformations are explicit and lossless:

- Two originals with significant retained whitespace use base64. `check-all-host-nocaps.log.base64` decodes to the original 22,206-byte log, SHA-256 `e466fbbc07a017952d9857a61304a48cb62de4dd8edcb02e726da07a18dc9185`. `host-pid-probe.json.base64` decodes to the original 243-byte probe, SHA-256 `22c9a68f515c7221986b596dc2a9253fc53158d0ed0fd9c0255079b24d51dde8`, including its final blank line. Base64 preserves these original bytes without changing the repository's whitespace rules. The original capture metadata continues to name and hash the decoded originals.
- Original `g22-before.json` and final `check-all-host-nocaps-after.json` were independently captured as identical 892,851-byte files, SHA-256 `24a936111d3d6cbd2965b4e0149c3c57e8a22d9c32925d7f7ad43d918cfadc09`. Only `g22-before.json` is stored here; the manifest maps the identical final observation to it. `source-identity-summary.json` retains each run's original before/after digest and the exact status deltas for the two nonidentical observations.

The JSON files retain their original schemas. Some are execution captures, retention inventories or read-only source/artifact inspection summaries authored during this task. Their timestamps and hashes do not turn those summaries into signed runtime, human field or qualification observations.

## Evidence groups

| Group | Primary retained files | Meaning |
| --- | --- | --- |
| Full Root regression and formal-pin G22 | `root-full*.log`, matching `*-run.json`, `root-tests*-timing.json`, `g22.log`, `g22-run.json` | Three actual full attempts and the original G22 contract run; the third full has 79/79 PASS, canonical exit 0 and separate capture exit 3. |
| Source identity and exact cleanup | `g22-before.json`, `source-identity-summary.json`, `root-full-host-nocaps-restoration.json`, the two `synthetic-native-fixture-*.json` files | 2,387 tracked entries remain identical. Each retained canary is test-generated diagnostic residue, and the original `source_unchanged=false` reports remain unchanged. |
| Environment and aggregate results | `check-all-host-nocaps.log.base64`, `check-all-results.json`, checker diagnostics, `root-l4-local-ci-parity*`, canonical policy/provider captures | Actual 47/52 aggregate PASS, five failures, sandbox PID mismatch, root DAC override and unavailable Docker/Hub integrations. |
| Baseline failure diagnosis | `reference-dirty-triage-baseline*`, `root-m5-readiness-inspection-20261020.json` | Bounded original-checker reproduction and byte comparisons for references; read-only M5 Git/artifact inspection. The M5 summary does not claim a new certifier or runtime execution. |
| Component delivery and candidate qualification | `adk-final-regression*`, `adk-main-quick*`, `root-l4-adk-release*`, `root-promotion-signature*`, `root-adk-8.0.36-promotion.json`, `root-candidate-qualification*` | Actual component tests, clean-commit build/rehearsal, signature check, unmodified six-file transaction receipt and original candidate collector. |

Canonical promotion evidence and its original Sigstore bundle remain in `reports/promotion/agent-dev-kit/` at the Root repository level. Formal release/archive identities and immutable workflow links are recorded in the verification report. The candidate transaction's embedded receipt digest is distinct from the SHA-256 of its complete file; both are preserved and labeled there.

## Integrity check

The following Python code verifies stored bytes and then the decoded original bytes without changing any file. Run it with the Root checkout as the current directory:

```python
import base64
import hashlib
import json
from pathlib import Path

directory = Path("docs/changes/20261020-delegated-auto-review/evidence")
manifest = json.loads((directory / "retention-manifest.json").read_text())
for item in manifest["files"]:
    stored = (directory / item["path"]).read_bytes()
    assert len(stored) == item["stored_bytes"]
    assert hashlib.sha256(stored).hexdigest() == item["stored_sha256"]
    original = base64.decodebytes(stored) if item["encoding"] == "base64" else stored
    assert len(original) == item["original_bytes"]
    assert hashlib.sha256(original).hexdigest() == item["original_sha256"]
```

The final independent review, protected final-head merge, clean-commit aggregate result, main CI and original fresh-main qualification readback are recorded after this snapshot in the final PR body. Only the actual current canonical qualification result can support closing the corresponding tracker. The existing Native, effect, longitudinal and conditional Product M5 boundaries remain in force.
