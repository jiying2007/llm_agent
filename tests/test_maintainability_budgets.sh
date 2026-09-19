#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

set +e
"$ROOT/scripts/check-maintainability-budgets.sh" --strict --summary-json >"$TMP_DIR/root.json"
root_rc=$?
"$ROOT/scripts/check-maintainability-budgets.sh" "$ROOT" --strict --summary-json >"$TMP_DIR/root-positional.json"
positional_rc=$?
set -e
if [[ "$root_rc" -ne 0 || "$positional_rc" -ne 0 ]]; then
  echo "[FAIL] canonical maintainability budget is not strict-pass" >&2
  cat "$TMP_DIR/root.json" >&2 || true
  cat "$TMP_DIR/root-positional.json" >&2 || true
  exit 1
fi
python3 - "$TMP_DIR/root.json" "$TMP_DIR/root-positional.json" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
positional = json.load(open(sys.argv[2], encoding="utf-8"))
assert report.pop("elapsed_ms") >= 0, report
assert positional.pop("elapsed_ms") >= 0, positional
assert report == positional, (report, positional)
assert report["schema"] == "llm-agent-maintainability-budget-report/v2", report
assert report["status"] == "pass", report
assert report["strict"] is True, report
assert report["budget_count"] == 11, report
assert report["evidence_metric_count"] == 3, report
assert not report["failures"], report
assert not report["warnings"], report
assert all(item["hotspots"] for item in report["budgets"]), report
assert report["semantic_axes"]["coupling"] == {
    "status": "measured", "method": "max-import-fan-out"
}, report
for name in ("churn", "owner_concentration", "inactive_assets"):
    axis = report["semantic_axes"][name]
    assert axis["status"] == "not-available", axis
    assert axis["observed"] is None, axis
    assert axis["source"] is None, axis
    assert axis["enforcement"] == "report-only", axis
    assert axis["unavailable_reason"], axis
PY

mkdir -p "$TMP_DIR/fixture/scripts"
printf '#!/usr/bin/env bash\n' >"$TMP_DIR/fixture/scripts/a.sh"
git -C "$TMP_DIR/fixture" init -q
git -C "$TMP_DIR/fixture" config user.name fixture
git -C "$TMP_DIR/fixture" config user.email fixture@example.invalid
git -C "$TMP_DIR/fixture" add scripts/a.sh
git -C "$TMP_DIR/fixture" commit -q -m initial
printf '#!/usr/bin/env bash\nprintf test\n' >"$TMP_DIR/fixture/scripts/b.sh"
git -C "$TMP_DIR/fixture" add scripts/b.sh
git -C "$TMP_DIR/fixture" commit -q -m second

python3 - "$TMP_DIR/fixture" "$TMP_DIR/fail.json" "$TMP_DIR/warn.json" \
  "$TMP_DIR/bad-hash.json" "$TMP_DIR/bad-window.json" \
  "$TMP_DIR/evidence-budget.json" <<'PY'
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path

fixture = Path(sys.argv[1])
evidence_dir = fixture / "evidence"
evidence_dir.mkdir()
revision_start = subprocess.check_output(
    ["git", "-C", str(fixture), "rev-list", "--max-parents=0", "HEAD"], text=True
).strip()
revision_end = subprocess.check_output(
    ["git", "-C", str(fixture), "rev-parse", "HEAD"], text=True
).strip()
window = {
    "started_at": "2026-07-01T00:00:00Z",
    "ended_at": "2026-08-01T00:00:00Z",
    "revision_start": revision_start,
    "revision_end": revision_end,
}
evidence_values = {
    "churn": {
        "source_kind": "git-history-numstat",
        "records": [
            {"path": "scripts/a.sh", "additions": 7, "deletions": 3},
            {"path": "scripts/b.sh", "additions": 2, "deletions": 1},
        ],
    },
    "owner_concentration": {
        "source_kind": "reviewed-ownership-snapshot",
        "records": [
            {"scope_id": "scope-a", "owner_id": "owner-a"},
            {"scope_id": "scope-b", "owner_id": "owner-a"},
            {"scope_id": "scope-c", "owner_id": "owner-b"},
        ],
    },
    "inactive_assets": {
        "source_kind": "sanitized-invocation-ledger",
        "records": [
            {"asset_id": "asset-{0:02d}".format(index), "invocations": 0 if index == 0 else 1}
            for index in range(32)
        ],
    },
}

def population(metric, records):
    if metric == "churn":
        identifiers = [item["path"] for item in records]
    elif metric == "owner_concentration":
        identifiers = [item["scope_id"] for item in records]
    else:
        identifiers = [item["asset_id"] for item in records]
    raw = json.dumps(sorted(identifiers), separators=(",", ":")).encode("utf-8")
    return {
        "count": len(identifiers),
        "digest": hashlib.sha256(raw).hexdigest(),
        "coverage": "complete",
    }

sources = {}
populations = {}
for metric, details in evidence_values.items():
    path = evidence_dir / (metric + ".json")
    value = {
        "schema": "llm-agent-maintainability-evidence/v1",
        "metric": metric,
        "repository_id": "fixture-repo",
        "source_kind": details["source_kind"],
        "window": window,
        "population": population(metric, details["records"]),
        "generated_at": "2026-08-02T00:00:00Z",
        "records": details["records"],
    }
    path.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")
    sources[metric] = {
        "path": path.relative_to(fixture).as_posix(),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "schema": "llm-agent-maintainability-evidence/v1",
        "repository_id": "fixture-repo",
        "source_kind": details["source_kind"],
        "window": window,
    }
    populations[metric] = value["population"]

def evidence_metric(metric, risk):
    return {
        "id": "fixture-" + metric.replace("_", "-"),
        "metric": metric,
        "risk": risk,
        "enforcement": "report-only",
        "enforcement_rationale": "fixture evidence is report-only without a reviewed baseline",
        "source": sources[metric],
        "expected_repository_id": "fixture-repo",
        "expected_population": populations[metric],
        "max_age_days": 60,
        "owner": "fixture-owner",
        "next_action": "review fixture evidence",
    }

base = {
    "schema_version": 2,
    "maintainability_budgets": {
        "schema": "llm-agent-maintainability-budgets/v2",
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
        ],
        "evidence_metrics": [
            evidence_metric("churn", "medium"),
            evidence_metric("owner_concentration", "high"),
            evidence_metric("inactive_assets", "high"),
        ],
    }
}
with open(sys.argv[3], "w", encoding="utf-8") as stream:
    json.dump(base, stream)
failed = copy.deepcopy(base)
failed["maintainability_budgets"]["budgets"][0]["baseline"] = 0
failed["maintainability_budgets"]["budgets"][0]["warning_limit"] = 0
failed["maintainability_budgets"]["budgets"][0]["hard_limit"] = 1
with open(sys.argv[2], "w", encoding="utf-8") as stream:
    json.dump(failed, stream)
bad_hash = copy.deepcopy(base)
bad_hash["maintainability_budgets"]["evidence_metrics"][0]["source"]["sha256"] = "0" * 64
with open(sys.argv[4], "w", encoding="utf-8") as stream:
    json.dump(bad_hash, stream)
bad_window = copy.deepcopy(base)
bad_window["maintainability_budgets"]["evidence_metrics"][0]["source"]["window"] = dict(window)
bad_window["maintainability_budgets"]["evidence_metrics"][0]["source"]["window"]["revision_end"] = "other-rev"
with open(sys.argv[5], "w", encoding="utf-8") as stream:
    json.dump(bad_window, stream)
evidence_budget = copy.deepcopy(base)
evidence_budget["maintainability_budgets"]["budgets"][0].update({
    "baseline": 2,
    "warning_limit": 3,
    "hard_limit": 4,
})
churn_budget = evidence_budget["maintainability_budgets"]["evidence_metrics"][0]
churn_budget["enforcement"] = "budget"
churn_budget.update({"baseline": 5, "warning_limit": 8, "hard_limit": 20})
with open(sys.argv[6], "w", encoding="utf-8") as stream:
    json.dump(evidence_budget, stream)
PY

python3 - "$TMP_DIR/fixture" "$TMP_DIR/warn.json" "$TMP_DIR" <<'PY'
import copy
import hashlib
import json
import sys
from pathlib import Path

fixture = Path(sys.argv[1])
base = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
output = Path(sys.argv[3])
source_path = fixture / "evidence/churn.json"
source = json.loads(source_path.read_text(encoding="utf-8"))
secrets = [
    "s" + "k-fixtureSecret123456",
    "gh" + "p_fixtureSecret123456",
    "Bear" + "er fixture.secret.token",
    "AK" + "IA1234567890ABCDEF",
    "-----BEGIN PRIVATE" + " KEY-----",
    "xo" + "xb-fixture-secret-token",
    "pass" + "word=fixture-value",
    "raw" + " prompt tool payload",
]
for index, secret in enumerate(secrets):
    evidence = copy.deepcopy(source)
    evidence["records"][0]["path"] = secret
    evidence_path = fixture / "evidence" / ("secret-{0}.json".format(index))
    evidence_path.write_text(json.dumps(evidence, sort_keys=True), encoding="utf-8")
    config = copy.deepcopy(base)
    source_contract = config["maintainability_budgets"]["evidence_metrics"][0]["source"]
    source_contract["path"] = evidence_path.relative_to(fixture).as_posix()
    source_contract["sha256"] = hashlib.sha256(evidence_path.read_bytes()).hexdigest()
    (output / ("secret-{0}.json".format(index))).write_text(
        json.dumps(config), encoding="utf-8"
    )

sensitive_field = copy.deepcopy(source)
sensitive_field["records"][0]["api" + "_key"] = "fixture-value"
sensitive_path = fixture / "evidence/secret-8.json"
sensitive_path.write_text(json.dumps(sensitive_field, sort_keys=True), encoding="utf-8")
sensitive_config = copy.deepcopy(base)
sensitive_contract = sensitive_config["maintainability_budgets"]["evidence_metrics"][0]["source"]
sensitive_contract["path"] = sensitive_path.relative_to(fixture).as_posix()
sensitive_contract["sha256"] = hashlib.sha256(sensitive_path.read_bytes()).hexdigest()
(output / "secret-8.json").write_text(json.dumps(sensitive_config), encoding="utf-8")

def write_variant(name, metric_index, evidence):
    evidence_path = fixture / "evidence" / (name + ".json")
    evidence_path.write_text(json.dumps(evidence, sort_keys=True), encoding="utf-8")
    config = copy.deepcopy(base)
    definition = config["maintainability_budgets"]["evidence_metrics"][metric_index]
    definition["source"]["path"] = evidence_path.relative_to(fixture).as_posix()
    definition["source"]["sha256"] = hashlib.sha256(evidence_path.read_bytes()).hexdigest()
    definition["source"]["repository_id"] = evidence["repository_id"]
    definition["source"]["window"] = evidence["window"]
    (output / (name + ".json")).write_text(json.dumps(config), encoding="utf-8")
    return config

stale = copy.deepcopy(source)
stale["window"] = {
    **stale["window"],
    "started_at": "2020-01-01T00:00:00Z",
    "ended_at": "2020-02-01T00:00:00Z",
}
stale["generated_at"] = "2020-02-02T00:00:00Z"
write_variant("stale", 0, stale)

regenerated_old_window = copy.deepcopy(stale)
regenerated_old_window["generated_at"] = "2026-08-15T00:00:00Z"
write_variant("regenerated-old-window", 0, regenerated_old_window)

foreign = copy.deepcopy(source)
foreign["repository_id"] = "foreign-repo"
foreign_config = write_variant("foreign-repo", 0, foreign)
foreign_definition = foreign_config["maintainability_budgets"]["evidence_metrics"][0]
foreign_definition["expected_repository_id"] = "foreign-repo"
(output / "foreign-repo.json").write_text(json.dumps(foreign_config), encoding="utf-8")

inactive_source = json.loads(
    (fixture / "evidence/inactive_assets.json").read_text(encoding="utf-8")
)
incomplete = copy.deepcopy(inactive_source)
incomplete["records"] = incomplete["records"][:-1]
write_variant("incomplete-population", 2, incomplete)

reverse = copy.deepcopy(source)
reverse["window"] = {
    **reverse["window"],
    "revision_start": reverse["window"]["revision_end"],
    "revision_end": reverse["window"]["revision_start"],
}
write_variant("reverse-ancestry", 0, reverse)

evidence_link = fixture / "evidence/churn-link.json"
evidence_link.symlink_to("churn.json")
internal_link_config = copy.deepcopy(base)
internal_source = internal_link_config["maintainability_budgets"]["evidence_metrics"][0]["source"]
internal_source["path"] = "evidence/churn-link.json"
(output / "internal-symlink.json").write_text(
    json.dumps(internal_link_config), encoding="utf-8"
)

parent_link = fixture / "evidence-link"
parent_link.symlink_to("evidence", target_is_directory=True)
parent_link_config = copy.deepcopy(base)
parent_source = parent_link_config["maintainability_budgets"]["evidence_metrics"][0]["source"]
parent_source["path"] = "evidence-link/churn.json"
(output / "parent-symlink.json").write_text(
    json.dumps(parent_link_config), encoding="utf-8"
)

legacy = copy.deepcopy(base)
legacy["maintainability_budgets"]["schema"] = "llm-agent-maintainability-budgets/v1"
(output / "legacy-v1.json").write_text(json.dumps(legacy), encoding="utf-8")
PY

set +e
PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
  --root "$TMP_DIR/fixture" --repository-id fixture-repo \
  --as-of 2026-08-30T00:00:00Z --config "$TMP_DIR/fail.json" \
  --summary-json >"$TMP_DIR/fail.out"
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
  --root "$TMP_DIR/fixture" --repository-id fixture-repo \
  --as-of 2026-08-30T00:00:00Z --config "$TMP_DIR/warn.json" \
  --summary-json >"$TMP_DIR/warn.out"
python3 - "$TMP_DIR/warn.out" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["status"] == "needs-review", report
assert report["warnings"] == ["fixture-script-count"], report
axes = report["semantic_axes"]
assert axes["churn"]["status"] == "measured", axes
assert axes["churn"]["observed"] == 10, axes
assert axes["owner_concentration"]["observed"] == 6667, axes
assert axes["inactive_assets"]["observed"] == 313, axes
for name in ("churn", "owner_concentration", "inactive_assets"):
    source = axes[name]["source"]
    assert source["repository_id"] == "fixture-repo", source
    assert len(source["sha256"]) == 64, source
    assert len(source["window"]["revision_start"]) == 40, source
    assert source["population"]["coverage"] == "complete", source
PY

set +e
PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
  --root "$TMP_DIR/fixture" --repository-id fixture-repo \
  --as-of 2026-08-30T00:00:00Z --config "$TMP_DIR/warn.json" \
  --strict --summary-json >/dev/null
strict_rc=$?
set -e
[[ "$strict_rc" -eq 1 ]] || {
  echo "[FAIL] strict warning should return 1, got $strict_rc" >&2
  exit 1
}

for invalid in bad-hash bad-window; do
  set +e
  PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
    --root "$TMP_DIR/fixture" --repository-id fixture-repo \
    --as-of 2026-08-30T00:00:00Z --config "$TMP_DIR/${invalid}.json" --summary-json \
    >"$TMP_DIR/${invalid}.out" 2>"$TMP_DIR/${invalid}.err"
  invalid_rc=$?
  set -e
  [[ "$invalid_rc" -eq 2 ]] || {
    echo "[FAIL] ${invalid} evidence should return 2, got $invalid_rc" >&2
    exit 1
  }
done
rg -q 'evidence source digest mismatch' "$TMP_DIR/bad-hash.err"
rg -q 'evidence source window mismatch' "$TMP_DIR/bad-window.err"

for invalid in stale regenerated-old-window foreign-repo incomplete-population reverse-ancestry \
  internal-symlink parent-symlink legacy-v1; do
  set +e
  PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
    --root "$TMP_DIR/fixture" --repository-id fixture-repo \
    --as-of 2026-08-30T00:00:00Z --config "$TMP_DIR/${invalid}.json" --summary-json \
    >"$TMP_DIR/${invalid}.out" 2>"$TMP_DIR/${invalid}.err"
  invalid_rc=$?
  set -e
  [[ "$invalid_rc" -eq 2 ]] || {
    echo "[FAIL] ${invalid} evidence should return 2, got $invalid_rc" >&2
    exit 1
  }
done
rg -q 'exceeds max_age_days' "$TMP_DIR/stale.err"
rg -q 'evidence window exceeds max_age_days' "$TMP_DIR/regenerated-old-window.err"
rg -q 'CLI repository identity does not match' "$TMP_DIR/foreign-repo.err"
rg -q 'reviewed population count' "$TMP_DIR/incomplete-population.err"
rg -q 'ancestor window' "$TMP_DIR/reverse-ancestry.err"
rg -q 'budget path contains a symlink' "$TMP_DIR/internal-symlink.err"
rg -q 'budget path contains a symlink' "$TMP_DIR/parent-symlink.err"
rg -q 'unsupported maintainability budget schema' "$TMP_DIR/legacy-v1.err"

for index in 0 1 2 3 4 5 6 7 8; do
  set +e
  PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
    --root "$TMP_DIR/fixture" --repository-id fixture-repo \
    --as-of 2026-08-30T00:00:00Z --config "$TMP_DIR/secret-${index}.json" --summary-json \
    >"$TMP_DIR/secret-${index}.out" 2>"$TMP_DIR/secret-${index}.err"
  secret_rc=$?
  set -e
  [[ "$secret_rc" -eq 2 ]] || {
    echo "[FAIL] secret fixture ${index} should return 2, got $secret_rc" >&2
    exit 1
  }
  rg -q 'maintainability evidence contains (a )?forbidden (secret material|sensitive field)' \
    "$TMP_DIR/secret-${index}.err"
done

set +e
PYTHONPATH="$ROOT" python3 -m tools.codex_assets.maintainability_budget \
  --root "$TMP_DIR/fixture" --repository-id fixture-repo \
  --as-of 2026-08-30T00:00:00Z --config "$TMP_DIR/evidence-budget.json" \
  --strict --summary-json >"$TMP_DIR/evidence-budget.out"
evidence_budget_rc=$?
set -e
[[ "$evidence_budget_rc" -eq 1 ]] || {
  echo "[FAIL] strict evidence budget warning should return 1, got $evidence_budget_rc" >&2
  exit 1
}
python3 - "$TMP_DIR/evidence-budget.out" <<'PY'
import json
import sys

report = json.load(open(sys.argv[1], encoding="utf-8"))
assert report["status"] == "fail", report
assert report["warnings"] == ["fixture-churn"], report
churn = report["semantic_axes"]["churn"]
assert churn["status"] == "needs-review", churn
assert churn["enforcement"] == "budget", churn
assert churn["baseline"] == 5, churn
assert churn["warning_limit"] == 8, churn
assert churn["hard_limit"] == 20, churn
PY

PYTHONPATH="$ROOT" python3 - <<'PY'
from tools.codex_assets.maintainability_budget import BudgetError, _reject_secrets

try:
    _reject_secrets({"root": "/tmp/" + "s" + "k-secret-root-value"}, "maintainability report")
except BudgetError as exc:
    assert "forbidden secret material" in str(exc), exc
else:
    raise AssertionError("final report secret scan accepted a secret-like root path")
PY

echo "[PASS] maintainability budgets enforce static and evidence metrics with honest availability"
