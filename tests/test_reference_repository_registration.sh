#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT/tools/codex_assets/reference_repository.py" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
for retired in ('["rtk", "git"', '["rtk", "proxy", "git"'):
    assert retired not in text, retired
PY
CHECK="${ROOT}/scripts/check-reference-repository-registration.sh"
ONBOARD="${ROOT}/scripts/onboard-reference-repository.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${CHECK}" "${ROOT}" --summary-json >/dev/null

"${ONBOARD}" "${ROOT}" \
  --candidates "${ROOT}/fixtures/external-practice/registration/candidates.jsonl" \
  --decisions "${ROOT}/fixtures/external-practice/registration/decisions.jsonl" \
  --candidate-id epc-34d27bd9c1f6bcea6e95 \
  --analysis "${ROOT}/reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md" \
  --duplicate-check "${ROOT}/reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md" \
  --security-review "${ROOT}/reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md" \
  --out-json "${TMP_DIR}/plan.json" \
  --out-md "${TMP_DIR}/plan.md" >/dev/null

"${CHECK}" "${ROOT}" --no-fixtures --plan "${TMP_DIR}/plan.json" >/dev/null

"${ONBOARD}" "${ROOT}" \
  --candidates "${ROOT}/fixtures/external-practice/registration/candidates.jsonl" \
  --decisions "${ROOT}/fixtures/external-practice/registration/decisions.jsonl" \
  --candidate-id epc-34d27bd9c1f6bcea6e95 \
  --analysis "${ROOT}/reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md" \
  --duplicate-check "${ROOT}/reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md" \
  --security-review "${ROOT}/reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md" \
  --repo-name agent-harness-alias \
  --target-path agent-harness-alias \
  --out-json "${TMP_DIR}/alias-plan.json" \
  --out-md "${TMP_DIR}/alias-plan.md" >/dev/null

python3 - "${TMP_DIR}/alias-plan.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    plan = json.load(stream)
assert plan["candidate"]["repo"] == "example/agent-harness"
assert plan["planned_changes"]["registry"]["repo"] == "agent-harness-alias"
assert plan["planned_changes"]["gitmodules"]["path"] == "agent-harness-alias"
PY

python3 - "${TMP_DIR}/plan.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    plan = json.load(stream)
assert plan["schema"] == "reference-repository-onboarding/v1"
assert plan["candidate"]["candidate_id"] == "epc-34d27bd9c1f6bcea6e95"
assert plan["candidate"]["provider"] == "github"
assert plan["decision"]["decision"] == "ADOPT"
assert plan["decision"]["target"] == "reference-repository"
assert all(plan["gates"].values())
assert plan["mode"] == "dry-run"
assert plan["boundaries"]["agent_dev_kit_modified"] is False
PY

if "${ONBOARD}" "${ROOT}" \
  --candidates "${ROOT}/fixtures/external-practice/negative/old-oss-candidate.jsonl" \
  --decisions "${ROOT}/fixtures/external-practice/registration/decisions.jsonl" \
  --candidate-id epc-34d27bd9c1f6bcea6e95 \
  --analysis "${ROOT}/reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md" \
  --duplicate-check "${ROOT}/reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md" \
  --security-review "${ROOT}/reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md" \
  --out-json "${TMP_DIR}/legacy-plan.json" \
  --out-md "${TMP_DIR}/legacy-plan.md" >/dev/null 2>&1; then
  echo "[FAIL] legacy candidate schema reached repository onboarding" >&2
  exit 1
fi

if "${ONBOARD}" "${ROOT}" \
  --candidates "${ROOT}/fixtures/external-practice/registration/candidates.jsonl" \
  --decisions "${ROOT}/fixtures/external-practice/registration/decision-curator-owner.jsonl" \
  --candidate-id epc-34d27bd9c1f6bcea6e95 \
  --analysis "${ROOT}/reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md" \
  --duplicate-check "${ROOT}/reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md" \
  --security-review "${ROOT}/reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md" \
  --out-json "${TMP_DIR}/self-approved-plan.json" \
  --out-md "${TMP_DIR}/self-approved-plan.md" >/dev/null 2>&1; then
  echo "[FAIL] curator self-approval reached repository onboarding" >&2
  exit 1
fi

if "${ONBOARD}" "${ROOT}" \
  --candidates "${ROOT}/fixtures/external-practice/registration/candidates.jsonl" \
  --decisions "${ROOT}/fixtures/external-practice/registration/decisions.jsonl" \
  --candidate-id epc-34d27bd9c1f6bcea6e95 \
  --analysis "${ROOT}/reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md" \
  --duplicate-check "${ROOT}/reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md" \
  --security-review "${ROOT}/reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md" \
  --out-json "${TMP_DIR}/unsafe-apply.json" \
  --out-md "${TMP_DIR}/unsafe-apply.md" \
  --apply >/dev/null 2>&1; then
  echo "[FAIL] metadata-only apply passed without a reviewed local source" >&2
  exit 1
fi

python3 - "${TMP_DIR}/plan.json" "${TMP_DIR}/tampered-plan.json" <<'PY'
import json
import pathlib
import sys
value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
value["artifact_sha256"]["security_review"] = "0" * 64
pathlib.Path(sys.argv[2]).write_text(json.dumps(value), encoding="utf-8")
PY
if "${CHECK}" "${ROOT}" --no-fixtures --plan "${TMP_DIR}/tampered-plan.json" >/dev/null 2>&1; then
  echo "[FAIL] stale artifact digest passed registration plan validation" >&2
  exit 1
fi

APPLY_ROOT="${TMP_DIR}/apply-root"
SOURCE_ROOT="${TMP_DIR}/reviewed-source"
mkdir -p \
  "${APPLY_ROOT}/manifests" \
  "${APPLY_ROOT}/subrepos" \
  "${APPLY_ROOT}/fixtures/external-practice/registration" \
  "${APPLY_ROOT}/reports/wechat-account-research-2026-07-16" \
  "${APPLY_ROOT}/agent-dev-kit/manifests" \
  "${SOURCE_ROOT}"
cp "${ROOT}/manifests/external_practice_sources.json" "${APPLY_ROOT}/manifests/"
cp "${ROOT}/manifests/reference_repository_lifecycle_policy.json" "${APPLY_ROOT}/manifests/"
cp "${ROOT}/manifests/subrepo_lifecycle.json" "${APPLY_ROOT}/manifests/"
cp "${ROOT}/subrepos/registry.csv" "${APPLY_ROOT}/subrepos/"
cp "${ROOT}/subrepos/adoption-matrix.md" "${APPLY_ROOT}/subrepos/"
cp "${ROOT}/subrepos/adoption-matrix.jsonl" "${APPLY_ROOT}/subrepos/"
cp "${ROOT}/subrepos/phase-gate.env" "${APPLY_ROOT}/subrepos/"
cp "${ROOT}/fixtures/external-practice/registration/candidates.jsonl" "${APPLY_ROOT}/fixtures/external-practice/registration/"
cp "${ROOT}/fixtures/external-practice/registration/decisions.jsonl" "${APPLY_ROOT}/fixtures/external-practice/registration/"
cp "${ROOT}/agent-dev-kit/manifests/official_docs_freshness_gates.json" "${APPLY_ROOT}/agent-dev-kit/manifests/"
cp "${ROOT}/reports/wechat-account-research-2026-07-16/catalog.jsonl" "${APPLY_ROOT}/reports/wechat-account-research-2026-07-16/"
for report in \
  oss-analysis-example-runtime-policy-gates-2026-06-16.md \
  oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md \
  oss-security-review-example-runtime-policy-gates-2026-06-16.md; do
  cp "${ROOT}/reports/${report}" "${APPLY_ROOT}/reports/${report}"
done

git -C "${SOURCE_ROOT}" init >/dev/null
git -C "${SOURCE_ROOT}" symbolic-ref HEAD refs/heads/main
git -C "${SOURCE_ROOT}" config user.name fixture
git -C "${SOURCE_ROOT}" config user.email fixture@example.invalid
python3 - "${SOURCE_ROOT}/README.md" <<'PY'
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_text("# reviewed source\n", encoding="utf-8")
PY
git -C "${SOURCE_ROOT}" add README.md
git -C "${SOURCE_ROOT}" commit -m "fixture source" >/dev/null 2>&1
git -C "${SOURCE_ROOT}" remote add origin https://github.com/example/agent-harness

git -C "${APPLY_ROOT}" init >/dev/null
git -C "${APPLY_ROOT}" symbolic-ref HEAD refs/heads/main
git -C "${APPLY_ROOT}" config user.name fixture
git -C "${APPLY_ROOT}" config user.email fixture@example.invalid
git -C "${APPLY_ROOT}" add .
git -C "${APPLY_ROOT}" commit -m "fixture baseline" >/dev/null 2>&1

REACTIVATE_ROOT="${TMP_DIR}/reactivate-root"
git clone "${APPLY_ROOT}" "${REACTIVATE_ROOT}" >/dev/null 2>&1
python3 - "${REACTIVATE_ROOT}" <<'PY'
import csv
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
registry_path = root / "subrepos/registry.csv"
with registry_path.open(encoding="utf-8", newline="") as stream:
    rows = list(csv.DictReader(stream))
rows.append({
    "repo": "agent-harness",
    "group": "agent-ecosystem",
    "priority": "P1",
    "sync_mode": "fetch",
    "branch": "main",
    "enabled": "no",
    "notes": "previously removed after method absorption",
    "status": "disabled",
    "owner": "fixture-owner",
    "last_reviewed_on": "2026-06-25",
    "intake_policy": "observe-first",
    "grade": "A",
})
with registry_path.open("w", encoding="utf-8", newline="") as stream:
    writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)

lifecycle_path = root / "manifests/subrepo_lifecycle.json"
lifecycle = json.loads(lifecycle_path.read_text(encoding="utf-8"))
lifecycle["entries"].append({
    "repo": "agent-harness",
    "state": "watch",
    "owner": "fixture-owner",
    "review_window": "manual",
    "automation_eligible": False,
    "watch_reason": "previous method-only absorption",
    "evidence": ["reports/previous-agent-harness-review.md"],
})
lifecycle_path.write_text(json.dumps(lifecycle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
git -C "${REACTIVATE_ROOT}" add subrepos/registry.csv manifests/subrepo_lifecycle.json
git -C "${REACTIVATE_ROOT}" commit -m "fixture disabled reference" >/dev/null 2>&1

PYTHONPATH="${ROOT}" python3 -m tools.codex_assets.reference_repository \
  --root "${REACTIVATE_ROOT}" plan \
  --candidates fixtures/external-practice/registration/candidates.jsonl \
  --decisions fixtures/external-practice/registration/decisions.jsonl \
  --candidate-id epc-34d27bd9c1f6bcea6e95 \
  --analysis reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md \
  --duplicate-check reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md \
  --security-review reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md \
  --out-json reports/reactivate-plan.json \
  --out-md reports/reactivate-plan.md \
  --apply \
  --materialization local-submodule \
  --submodule-source "${SOURCE_ROOT}" >/dev/null

python3 - "${REACTIVATE_ROOT}" <<'PY'
import csv
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
with (root / "subrepos/registry.csv").open(encoding="utf-8", newline="") as stream:
    rows = [row for row in csv.DictReader(stream) if row.get("repo") == "agent-harness"]
assert len(rows) == 1
assert rows[0]["enabled"] == "yes"
assert rows[0]["status"] == "active"
lifecycle = json.loads((root / "manifests/subrepo_lifecycle.json").read_text(encoding="utf-8"))
entries = [item for item in lifecycle["entries"] if item.get("repo") == "agent-harness"]
assert len(entries) == 1
assert entries[0]["state"] == "active-reference"
assert entries[0]["reactivated_from"] == "watch"
assert entries[0]["review_window"] == "monthly"
assert "reports/previous-agent-harness-review.md" in entries[0]["evidence"]
PY
[[ "$(git -C "${REACTIVATE_ROOT}" config -f .gitmodules --get submodule.agent-harness.url)" == "https://github.com/example/agent-harness" ]]
[[ "$(git -C "${REACTIVATE_ROOT}/agent-harness" config --get remote.origin.url)" == "https://github.com/example/agent-harness" ]]

FAIL_ROOT="${TMP_DIR}/apply-failure-root"
git clone "${APPLY_ROOT}" "${FAIL_ROOT}" >/dev/null 2>&1
chmod 555 "${FAIL_ROOT}/manifests"
if PYTHONPATH="${ROOT}" python3 -m tools.codex_assets.reference_repository \
  --root "${FAIL_ROOT}" plan \
  --candidates fixtures/external-practice/registration/candidates.jsonl \
  --decisions fixtures/external-practice/registration/decisions.jsonl \
  --candidate-id epc-34d27bd9c1f6bcea6e95 \
  --analysis reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md \
  --duplicate-check reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md \
  --security-review reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md \
  --out-json reports/failure-plan.json \
  --out-md reports/failure-plan.md \
  --apply \
  --materialization local-submodule \
  --submodule-source "${SOURCE_ROOT}" >/dev/null 2>&1; then
  chmod 755 "${FAIL_ROOT}/manifests"
  echo "[FAIL] forced metadata transaction failure unexpectedly applied" >&2
  exit 1
fi
chmod 755 "${FAIL_ROOT}/manifests"
if [[ -e "${FAIL_ROOT}/agent-harness" ]] || rg -q '^agent-harness,' "${FAIL_ROOT}/subrepos/registry.csv"; then
  echo "[FAIL] failed apply left a submodule or registry residue" >&2
  exit 1
fi
if [[ -f "${FAIL_ROOT}/.gitmodules" ]] && rg -q 'agent-harness' "${FAIL_ROOT}/.gitmodules"; then
  echo "[FAIL] failed apply left a .gitmodules residue" >&2
  exit 1
fi

PYTHONPATH="${ROOT}" python3 -m tools.codex_assets.reference_repository \
  --root "${APPLY_ROOT}" plan \
  --candidates fixtures/external-practice/registration/candidates.jsonl \
  --decisions fixtures/external-practice/registration/decisions.jsonl \
  --candidate-id epc-34d27bd9c1f6bcea6e95 \
  --analysis reports/oss-analysis-example-runtime-policy-gates-2026-06-16.md \
  --duplicate-check reports/oss-duplicate-check-example-runtime-policy-gates-2026-06-16.md \
  --security-review reports/oss-security-review-example-runtime-policy-gates-2026-06-16.md \
  --out-json reports/apply-plan.json \
  --out-md reports/apply-plan.md \
  --apply \
  --materialization local-submodule \
  --submodule-source "${SOURCE_ROOT}" >/dev/null

python3 - "${APPLY_ROOT}" <<'PY'
import json
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
plan = json.loads((root / "reports/apply-plan.json").read_text(encoding="utf-8"))
assert plan["status"] == "applied"
assert plan["mode"] == "apply"
assert plan["materialization"]["source_clean"] is True
assert plan["planned_changes"]["adoption_matrix"]["decision"] == "adopt"
assert plan["planned_changes"]["adoption_matrix"]["state"] == "done"
assert (root / "agent-harness/.git").exists()
assert "agent-harness,agent-ecosystem" in (root / "subrepos/registry.csv").read_text(encoding="utf-8")
matrix = (root / "subrepos/adoption-matrix.md").read_text(encoding="utf-8")
assert "| agent-harness |" in matrix
assert "| adopt | done | llm_agent |" in matrix
assert matrix.index("| agent-harness |") < matrix.index("\n## 模板")
assert '"repo":"agent-harness"' in (root / "subrepos/adoption-matrix.jsonl").read_text(encoding="utf-8")
lifecycle = json.loads((root / "manifests/subrepo_lifecycle.json").read_text(encoding="utf-8"))
assert any(item.get("repo") == "agent-harness" and item.get("state") == "active-reference" for item in lifecycle["entries"])
PY
[[ "$(git -C "${APPLY_ROOT}" config -f .gitmodules --get submodule.agent-harness.url)" == "https://github.com/example/agent-harness" ]]
[[ "$(git -C "${APPLY_ROOT}/agent-harness" config --get remote.origin.url)" == "https://github.com/example/agent-harness" ]]

echo "[PASS] reference repository onboarding requires v1 candidate, independent ADOPT decision, and safe reactivation"
