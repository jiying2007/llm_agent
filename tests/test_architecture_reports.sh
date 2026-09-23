#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="${ROOT}/scripts/check-architecture-reports.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

root_summary="${TMP_DIR}/root-summary.json"
if ! "${CHECKER}" "${ROOT}" --summary-json >"${root_summary}" 2>"${TMP_DIR}/root-summary.err"; then
  echo "[FAIL] current architecture report check failed" >&2
  sed -n '1,160p' "${root_summary}" >&2 || true
  sed -n '1,80p' "${TMP_DIR}/root-summary.err" >&2 || true
  exit 1
fi

python3 - "${ROOT}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
backlog = json.loads((root / "manifests/comprehensive_optimization_backlog.json").read_text(encoding="utf-8"))
g9 = next(item for item in backlog["items"] if item["id"] == "G9")
assert "manifests/history/product_maturity_task_pack-2026-09-16.json" in g9["implementation_evidence"], g9
assert "manifests/product_maturity_task_pack.json" not in g9["implementation_evidence"], g9
assert (root / "manifests/history/product_maturity_task_pack-2026-09-16.json").is_file()
assert not (root / "manifests/product_maturity_task_pack.json").exists()
PY

python3 - "${ROOT}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
backlog = json.loads((root / "manifests/comprehensive_optimization_backlog.json").read_text(encoding="utf-8"))
g19 = next(item for item in backlog["items"] if item["id"] == "G19")
assert "agent-dev-kit/src/agent_dev_kit/execution_policy/__init__.py" in g19["implementation_evidence"], g19
assert "agent-dev-kit/src/agent_dev_kit/execution_policy/engine.py" not in g19["implementation_evidence"], g19
PY

python3 - "${ROOT}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
backlog = json.loads((root / "manifests/comprehensive_optimization_backlog.json").read_text(encoding="utf-8"))
g18 = next(item for item in backlog["items"] if item["id"] == "G18")
assert "agent-dev-kit/src/agent_dev_kit/profile_coherence_contract.py" in g18["implementation_evidence"], g18
assert "agent-dev-kit/scripts/check-profile-coherence.sh" not in g18["implementation_evidence"], g18
PY

python3 - "${ROOT}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
backlog = json.loads((root / "manifests/comprehensive_optimization_backlog.json").read_text(encoding="utf-8"))
lta = json.loads((root / "manifests/long_term_asset_qualification.json").read_text(encoding="utf-8"))
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text(encoding="utf-8"))
items = {item["id"]: item for item in backlog["items"]}

for item_id in ("G13", "G14", "G15", "G17", "G18", "G19", "G20"):
    assert items[item_id]["implementation_status"] == "done", items[item_id]
    assert "blocking_condition" not in items[item_id], items[item_id]

for item_id in ("G9", "G10", "G21", "G22"):
    assert items[item_id]["implementation_status"] == "in_progress", items[item_id]

assert lta["maintainer_model"]["type"] == "solo", lta["maintainer_model"]
assert lta["maintainer_model"]["required_human_approvals"] == 0, lta["maintainer_model"]
assert lta["maintainer_model"]["human_redundancy_required"] is False, lta["maintainer_model"]
assert lta["terminal"]["pending_requirements"] == ["LTA-04"], lta["terminal"]
assert scorecard["overall"]["status"] == "production-qualified", scorecard["overall"]

serialized = json.dumps({"G14": items["G14"], "G15": items["G15"]}, ensure_ascii=False)
for retired in (
    "Claude authentication",
    "second human operator",
    "second-operator maintenance rehearsal",
    "multi-operator maintenance evidence",
):
    assert retired not in serialized, retired
PY

python3 - "${ROOT}" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
registry = json.loads((root / "manifests/report_registry.json").read_text(encoding="utf-8"))
entries = {item["id"]: item for item in registry["reports"]}
for item_id in ("target-architecture-2026-07-11", "software-m5-readiness-2026-07-13"):
    item = entries[item_id]
    assert item["status"] == "archived", item
    assert re.fullmatch(r"[0-9a-f]{40}", item["archive_commit"]), item
    assert re.fullmatch(r"[0-9a-f]{40}", item["archive_blob_sha"]), item
    assert not (root / item["path"]).exists(), item
assert registry["policy"]["archived_reports_may_be_git_history_only"] is True, registry["policy"]
PY

fixture_root="${TMP_DIR}/fixture-root"
mkdir -p "${fixture_root}/reports/architecture" "${fixture_root}/manifests" "${fixture_root}/agent-dev-kit/templates/artifacts"
cp "${ROOT}/reports/architecture/README.md" "${fixture_root}/reports/architecture/README.md"
cp "${ROOT}/reports/architecture/llm-agent-adk-target-architecture-2026-07-30.md" "${fixture_root}/reports/architecture/llm-agent-adk-target-architecture-2026-07-30.md"
cp "${ROOT}/reports/architecture/llm-agent-adk-product-maturity-audit-2026-07-13.md" "${fixture_root}/reports/architecture/llm-agent-adk-product-maturity-audit-2026-07-13.md"
cp "${ROOT}/manifests/comprehensive_optimization_backlog.json" "${fixture_root}/manifests/comprehensive_optimization_backlog.json"
cp "${ROOT}/manifests/product_maturity_scorecard.json" "${fixture_root}/manifests/product_maturity_scorecard.json"
cp "${ROOT}/manifests/report_registry.json" "${fixture_root}/manifests/report_registry.json"
cp "${ROOT}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md" "${fixture_root}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md"
python3 - "${fixture_root}" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
manifest = json.loads(
    (root / "manifests/comprehensive_optimization_backlog.json").read_text(encoding="utf-8")
)
for item in manifest["items"]:
    for relative in item["implementation_evidence"]:
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.touch(exist_ok=True)
PY
fixture_output="${TMP_DIR}/fixture.out"
if ! "${CHECKER}" "${fixture_root}" --summary-json >"${fixture_output}" 2>&1; then
  echo "[FAIL] architecture pass fixture failed" >&2
  sed -n '1,160p' "${fixture_output}" >&2 || true
  exit 1
fi

gap_root="${TMP_DIR}/gap-root"
cp -a "${fixture_root}" "${gap_root}"
python3 - "${gap_root}/manifests/comprehensive_optimization_backlog.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
value = json.loads(path.read_text(encoding="utf-8"))
value["items"][-1]["id"] = "G18"
path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
gap_output="${TMP_DIR}/gap.out"
if "${CHECKER}" "${gap_root}" >"${gap_output}" 2>&1; then
  echo "[FAIL] non-sequential optimization backlog unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "item ids must be unique and sequential" "${gap_output}"; then
  echo "[FAIL] non-sequential backlog failure was not explicit" >&2
  sed -n '1,120p' "${gap_output}" >&2 || true
  exit 1
fi

registry_mismatch_root="${TMP_DIR}/registry-mismatch-root"
cp -a "${fixture_root}" "${registry_mismatch_root}"
python3 - "${registry_mismatch_root}/manifests/report_registry.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
value = json.loads(path.read_text(encoding="utf-8"))
for item in value["reports"]:
    item["status"] = "superseded"
    if item["id"] == "target-architecture-2026-07-11":
        item["status"] = "current"
        item["superseded_by"] = None
path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
registry_mismatch_output="${TMP_DIR}/registry-mismatch.out"
if "${CHECKER}" "${registry_mismatch_root}" >"${registry_mismatch_output}" 2>&1; then
  echo "[FAIL] registry/backlog current report mismatch unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "current report must match" "${registry_mismatch_output}"; then
  echo "[FAIL] registry/backlog mismatch failure was not explicit" >&2
  sed -n '1,120p' "${registry_mismatch_output}" >&2 || true
  exit 1
fi

legacy_root="${TMP_DIR}/legacy-root"
mkdir -p "${legacy_root}/reports/architecture" "${legacy_root}/manifests" "${legacy_root}/agent-dev-kit/templates/artifacts"
cp "${ROOT}/reports/architecture/README.md" "${legacy_root}/reports/architecture/README.md"
cp "${ROOT}/manifests/comprehensive_optimization_backlog.json" "${legacy_root}/manifests/comprehensive_optimization_backlog.json"
cp "${ROOT}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md" "${legacy_root}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md"
python3 - "${ROOT}/reports/architecture/llm-agent-adk-target-architecture-2026-07-30.md" "${legacy_root}/reports/architecture/llm-agent-adk-target-architecture-legacy.md" <<'PY'
import re
import sys

source, target = sys.argv[1:3]
with open(source, "r", encoding="utf-8") as handle:
    content = handle.read()
for heading in (
    "Architecture Operating Model",
    "SSOT Matrix",
    "Structured Requirements Review",
    "Landing Protocol",
    "Runtime Delivery Contract",
    "Knowledge Promotion Contract",
    "State Reconciliation Contract",
    "Status Consistency Gate",
    "Comprehensive Optimization Backlog",
):
    content = re.sub(rf"\n## {re.escape(heading)}\n.*?(?=\n## |\Z)", "\n", content, flags=re.S)
with open(target, "w", encoding="utf-8") as handle:
    handle.write(content)
PY

legacy_out="${TMP_DIR}/legacy.out"
if "${CHECKER}" "${legacy_root}" >"${legacy_out}" 2>&1; then
  echo "[FAIL] legacy architecture report unexpectedly passed" >&2
  exit 1
fi
for expected in \
  "missing heading: ## Architecture Operating Model" \
  "missing heading: ## SSOT Matrix" \
  "missing heading: ## Structured Requirements Review" \
  "missing heading: ## Landing Protocol" \
  "missing heading: ## Runtime Delivery Contract" \
  "missing heading: ## Knowledge Promotion Contract" \
  "missing heading: ## State Reconciliation Contract" \
  "missing heading: ## Status Consistency Gate" \
  "missing heading: ## Comprehensive Optimization Backlog"
do
  if ! rg -q --fixed-strings -- "${expected}" "${legacy_out}"; then
    echo "[FAIL] legacy architecture report failure did not include: ${expected}" >&2
    sed -n '1,120p' "${legacy_out}" >&2 || true
    exit 1
  fi
done

bad_root="${TMP_DIR}/bad-root"
mkdir -p "${bad_root}/reports/architecture" "${bad_root}/manifests" "${bad_root}/agent-dev-kit/templates/artifacts"
cp "${ROOT}/reports/architecture/README.md" "${bad_root}/reports/architecture/README.md"
cp "${ROOT}/manifests/comprehensive_optimization_backlog.json" "${bad_root}/manifests/comprehensive_optimization_backlog.json"
cp "${ROOT}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md" "${bad_root}/agent-dev-kit/templates/artifacts/target-architecture-report-template.md"
cat >"${bad_root}/reports/architecture/bad-target-architecture.md" <<'EOF'
# Bad Architecture Report

## Summary

missing required sections
EOF

bad_out="${TMP_DIR}/bad.out"
if "${CHECKER}" "${bad_root}" >"${bad_out}" 2>&1; then
  echo "[FAIL] bad architecture report unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "missing heading: ## Scope" "${bad_out}"; then
  echo "[FAIL] bad architecture report failure did not name missing heading" >&2
  sed -n '1,80p' "${bad_out}" >&2 || true
  exit 1
fi

bad_summary="${TMP_DIR}/bad-summary.json"
if "${CHECKER}" "${bad_root}" --summary-json >"${bad_summary}" 2>"${TMP_DIR}/bad-summary.err"; then
  echo "[FAIL] bad architecture report summary unexpectedly passed" >&2
  exit 1
fi
python3 - "${bad_summary}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
assert data["status"] == "fail"
assert data["reports"] == 1
assert data["failures"], "expected failures"
PY

missing_manifest_root="${TMP_DIR}/missing-manifest-root"
mkdir -p "${missing_manifest_root}/reports/architecture"
cp "${ROOT}/reports/architecture/README.md" "${missing_manifest_root}/reports/architecture/README.md"
cp "${ROOT}/reports/architecture/llm-agent-adk-target-architecture-2026-07-30.md" "${missing_manifest_root}/reports/architecture/target-architecture-good.md"
missing_manifest_out="${TMP_DIR}/missing-manifest.out"
if "${CHECKER}" "${missing_manifest_root}" >"${missing_manifest_out}" 2>&1; then
  echo "[FAIL] missing manifest fixture unexpectedly passed" >&2
  exit 1
fi
if ! rg -q --fixed-strings -- "missing file: manifests/comprehensive_optimization_backlog.json" "${missing_manifest_out}"; then
  echo "[FAIL] missing manifest failure did not name manifest path" >&2
  sed -n '1,120p' "${missing_manifest_out}" >&2 || true
  exit 1
fi

echo "[PASS] architecture report checks behave as expected"
