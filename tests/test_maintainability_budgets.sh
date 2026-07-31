#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

"$ROOT/scripts/check-maintainability-budgets.sh" --strict --summary-json >"$TMP_DIR/root.json"
"$ROOT/scripts/check-maintainability-budgets.sh" "$ROOT" --strict --summary-json >"$TMP_DIR/root-positional.json"
cmp "$TMP_DIR/root.json" "$TMP_DIR/root-positional.json"
python3 - "$TMP_DIR/root.json" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["schema"] == "llm-agent-maintainability-budget-report/v1", report
assert report["status"] == "pass", report
assert report["strict"] is True, report
assert report["budget_count"] == 7, report
assert not report["failures"], report
assert not report["warnings"], report
assert all(item["hotspots"] for item in report["budgets"]), report
PY

mkdir -p "$TMP_DIR/fixture/scripts"
printf '#!/usr/bin/env bash\n' >"$TMP_DIR/fixture/scripts/a.sh"
printf '#!/usr/bin/env bash\nprintf test\n' >"$TMP_DIR/fixture/scripts/b.sh"

python3 - "$TMP_DIR/fail.json" "$TMP_DIR/warn.json" <<'PY'
import json
import sys

base = {
    "schema_version": 2,
    "maintainability_budgets": {
        "schema": "llm-agent-maintainability-budgets/v1",
        "baseline_date": "2026-07-30",
        "budgets": [
            {
                "id": "fixture-script-count",
                "metric": "file_count",
                "scope_paths": ["scripts"],
                "include_patterns": ["*.sh"],
                "exclude_prefixes": [],
                "baseline": 1,
                "warning_limit": 1,
                "hard_limit": 3,
                "owner": "fixture-owner",
                "next_action": "consolidate fixture wrappers"
            }
        ]
    }
}
with open(sys.argv[2], "w", encoding="utf-8") as stream:
    json.dump(base, stream)
base["maintainability_budgets"]["budgets"][0]["baseline"] = 0
base["maintainability_budgets"]["budgets"][0]["warning_limit"] = 0
base["maintainability_budgets"]["budgets"][0]["hard_limit"] = 1
with open(sys.argv[1], "w", encoding="utf-8") as stream:
    json.dump(base, stream)
PY

set +e
PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
  --root "$TMP_DIR/fixture" --config "$TMP_DIR/fail.json" --summary-json >"$TMP_DIR/fail.out"
fail_rc=$?
set -e
[[ "$fail_rc" -eq 1 ]] || {
  echo "[FAIL] hard budget breach should return 1, got $fail_rc" >&2
  exit 1
}
python3 - "$TMP_DIR/fail.out" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["status"] == "fail", report
assert report["failures"] == ["fixture-script-count"], report
PY

PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
  --root "$TMP_DIR/fixture" --config "$TMP_DIR/warn.json" --summary-json >"$TMP_DIR/warn.out"
python3 - "$TMP_DIR/warn.out" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["status"] == "needs-review", report
assert report["warnings"] == ["fixture-script-count"], report
PY

set +e
PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
  --root "$TMP_DIR/fixture" --config "$TMP_DIR/warn.json" --strict --summary-json >/dev/null
strict_rc=$?
set -e
[[ "$strict_rc" -eq 1 ]] || {
  echo "[FAIL] strict warning should return 1, got $strict_rc" >&2
  exit 1
}

echo "[PASS] maintainability budgets enforce pass, warning, strict, and hard-limit semantics"
