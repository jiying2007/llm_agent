#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 - <<'PY'
import json
from pathlib import Path

ledger = json.loads(Path("manifests/software_m5_pilot_ledger.json").read_text(encoding="utf-8"))
policy = json.loads(Path("manifests/software_m5_policy.json").read_text(encoding="utf-8"))

assert ledger["schema"] == "llm-agent-software-m5-pilot-ledger/v1"
assert policy["operational_advisories"]["second_human_operator"] is False

pilots = {item["id"]: item for item in ledger["pilots"]}
independent = pilots["software-m5-v5-independent-pilot-20260912"]
assert independent["environment_class"] == "independent"
assert independent["status"] == "active"
assert independent["started_at"] == "2026-09-12T04:19:00Z"
assert independent["repositories"] == ["digital-worker"]

objective = independent["objective"].lower()
assert "solo-maintainer" in objective
assert "second-human" not in objective
assert "second human" not in objective

# Historical start evidence is immutable hash-bound field evidence. It may preserve
# the policy language that was true when recorded; this ratchet applies only to the
# current active ledger projection and must not rewrite historical evidence.
historical = Path("reports/field-evidence/software-m5-independent-pilot-start-2026-09-12.json")
assert historical.is_file()

print("[PASS] active independent pilot ledger follows current solo-maintainer policy without rewriting historical field evidence")
PY
