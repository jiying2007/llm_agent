#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="${ROOT}/scripts/check-current-status-consistency.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${CHECKER}" "${ROOT}" --summary-json >/dev/null

make_fixture() {
  local dest="$1"
  local change_path="docs/changes/adk-v3-1-software-m5-ready"
  mkdir -p \
    "${dest}/reports/architecture" \
    "${dest}/reports/field-evidence" \
    "${dest}/manifests" \
    "${dest}/scripts" \
    "${dest}/subrepos" \
    "${dest}/docs" \
    "${dest}/agent-dev-kit/agents/example" \
    "${dest}/agent-dev-kit/${change_path}"

  cp "${ROOT}/reports/current-status.md" "${dest}/reports/current-status.md"
  cp "${ROOT}/reports/architecture/llm-agent-adk-software-m5-readiness-2026-07-13.md" "${dest}/reports/architecture/"
  cp "${ROOT}/reports/adk-v3-1-software-m5-ready-release-evidence-2026-07-13.json" "${dest}/reports/"
  cp "${ROOT}/reports/field-evidence/software-m5-events.jsonl" "${dest}/reports/field-evidence/"
  cp "${ROOT}/reports/field-evidence/software-m5-self-pilot-start-2026-07-13.json" "${dest}/reports/field-evidence/"
  cp "${ROOT}/manifests/product_maturity_scorecard.json" "${dest}/manifests/"
  cp "${ROOT}/manifests/product_maturity_task_pack.json" "${dest}/manifests/"
  cp "${ROOT}/manifests/report_registry.json" "${dest}/manifests/"
  cp "${ROOT}/manifests/software_m5_policy.json" "${dest}/manifests/"
  cp "${ROOT}/manifests/software_m5_pilot_ledger.json" "${dest}/manifests/"
  cp "${ROOT}/docs/software-m5-certification-plan.md" "${dest}/docs/"
  cp "${ROOT}/adk.lock" "${dest}/adk.lock"
  cp "${ROOT}/scripts/check-subrepo-state.sh" "${dest}/scripts/"
  cp "${ROOT}/scripts/classify-repo-worktree.sh" "${dest}/scripts/"
  chmod +x "${dest}/scripts/check-subrepo-state.sh" "${dest}/scripts/classify-repo-worktree.sh"

  cat >"${dest}/subrepos/registry.csv" <<'CSV'
repo,group,priority,sync_mode,branch,enabled,notes,status,owner,last_reviewed_on,intake_policy,grade
agent-dev-kit,adk-core,P0,pull,main,yes,fixture,active,tester,2026-07-13,adopt-first,S
CSV

  printf '{"version":"3.0.0"}\n' >"${dest}/agent-dev-kit/manifest.json"
  printf 'baseline asset\n' >"${dest}/agent-dev-kit/agents/example/AGENTS.md"
  git -C "${dest}/agent-dev-kit" init -q
  git -C "${dest}/agent-dev-kit" config user.email "fixture@example.invalid"
  git -C "${dest}/agent-dev-kit" config user.name "Fixture"
  git -C "${dest}/agent-dev-kit" add manifest.json agents/example/AGENTS.md
  git -C "${dest}/agent-dev-kit" commit -q -m "fixture baseline"
  local previous_adk
  previous_adk="$(git -C "${dest}/agent-dev-kit" rev-parse HEAD)"

  cp "${ROOT}/agent-dev-kit/manifest.json" "${dest}/agent-dev-kit/manifest.json"
  cp "${ROOT}/agent-dev-kit/${change_path}/release-rehearsal.json" "${dest}/agent-dev-kit/${change_path}/"
  cp "${ROOT}/agent-dev-kit/${change_path}/software-m5-campaign-plan.json" "${dest}/agent-dev-kit/${change_path}/"
  cp "${ROOT}/agent-dev-kit/${change_path}/codex-runtime-smoke.json" "${dest}/agent-dev-kit/${change_path}/"
  git -C "${dest}/agent-dev-kit" add manifest.json "${change_path}"
  git -C "${dest}/agent-dev-kit" commit -q -m "fixture M5-ready candidate"
  local current_adk
  current_adk="$(git -C "${dest}/agent-dev-kit" rev-parse HEAD)"

  python3 - \
    "${dest}/reports/current-status.md" \
    "${dest}/reports/adk-v3-1-software-m5-ready-release-evidence-2026-07-13.json" \
    "${dest}/adk.lock" \
    "${previous_adk}" \
    "${current_adk}" <<'PY'
import json
import pathlib
import re
import sys

status_path, release_path, lock_path, previous_adk, current_adk = sys.argv[1:]
status = pathlib.Path(status_path).read_text(encoding="utf-8")
status = re.sub(r"^- agent_dev_kit_commit: .+$", f"- agent_dev_kit_commit: {current_adk}", status, flags=re.MULTILINE)
status = re.sub(r"^- adk_previous_commit: .+$", f"- adk_previous_commit: {previous_adk}", status, flags=re.MULTILINE)
pathlib.Path(status_path).write_text(status, encoding="utf-8")

release = json.loads(pathlib.Path(release_path).read_text(encoding="utf-8"))
release["agent_dev_kit"]["commit"] = current_adk
release["agent_dev_kit"]["previous_commit"] = previous_adk
pathlib.Path(release_path).write_text(json.dumps(release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

lock = pathlib.Path(lock_path).read_text(encoding="utf-8")
lock = re.sub(r"agent-dev-kit.version=.*", "agent-dev-kit.version=3.1.0-rc.1", lock)
lock = re.sub(r"agent-dev-kit.commit=.*", f"agent-dev-kit.commit={current_adk}", lock)
pathlib.Path(lock_path).write_text(lock, encoding="utf-8")
PY

  git -C "${dest}" init -q
  git -C "${dest}" config user.email "fixture@example.invalid"
  git -C "${dest}" config user.name "Fixture"
  git -C "${dest}" add reports manifests adk.lock subrepos docs
  git -C "${dest}" update-index --add --cacheinfo "160000,${current_adk},agent-dev-kit"
  git -C "${dest}" commit -q -m "fixture product"
  local root_product
  root_product="$(git -C "${dest}" rev-parse HEAD)"

  python3 - "${dest}/reports/current-status.md" "${root_product}" <<'PY'
import pathlib
import re
import sys

status_path, root_product = sys.argv[1:]
status = pathlib.Path(status_path).read_text(encoding="utf-8")
status = re.sub(r"^- root_product_commit: .+$", f"- root_product_commit: {root_product}", status, flags=re.MULTILINE)
pathlib.Path(status_path).write_text(status, encoding="utf-8")
PY
  git -C "${dest}" add reports/current-status.md
  git -C "${dest}" commit -q -m "fixture status"
}

expect_fail_contains() {
  local fixture="$1"
  local expected="$2"
  local output="${fixture}.out"
  if "${CHECKER}" "${fixture}" --summary-json >"${output}" 2>&1; then
    echo "[FAIL] fixture unexpectedly passed: ${fixture}" >&2
    exit 1
  fi
  if ! rg -q --fixed-strings -- "${expected}" "${output}"; then
    echo "[FAIL] expected failure did not include: ${expected}" >&2
    sed -n '1,160p' "${output}" >&2 || true
    exit 1
  fi
}

pass_root="${TMP_DIR}/pass-root"
make_fixture "${pass_root}"
"${CHECKER}" "${pass_root}" --summary-json >/dev/null

mismatch_root="${TMP_DIR}/mismatch-root"
cp -a "${pass_root}" "${mismatch_root}"
python3 - "${mismatch_root}/reports/current-status.md" <<'PY'
import pathlib
import re
import sys
path = pathlib.Path(sys.argv[1])
path.write_text(re.sub(r"^- agent_dev_kit_commit: .+$", "- agent_dev_kit_commit: 0000000", path.read_text(encoding="utf-8"), flags=re.MULTILINE), encoding="utf-8")
PY
expect_fail_contains "${mismatch_root}" "gitlink ADK commit does not match current-status"

stale_root="${TMP_DIR}/stale-root"
cp -a "${pass_root}" "${stale_root}"
python3 - "${stale_root}/reports/current-status.md" <<'PY'
import pathlib
import re
import sys
path = pathlib.Path(sys.argv[1])
path.write_text(re.sub(r"^- last_verified_at: .+$", "- last_verified_at: 2000-01-01", path.read_text(encoding="utf-8"), flags=re.MULTILINE), encoding="utf-8")
PY
expect_fail_contains "${stale_root}" "current-status verification is stale"

terminal_root="${TMP_DIR}/terminal-root"
cp -a "${pass_root}" "${terminal_root}"
python3 - "${terminal_root}/manifests/product_maturity_scorecard.json" <<'PY'
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
value = json.loads(path.read_text(encoding="utf-8"))
value["overall"]["terminal_mature"] = True
path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail_contains "${terminal_root}" "product scorecard must keep terminal_mature=false"

campaign_root="${TMP_DIR}/campaign-root"
cp -a "${pass_root}" "${campaign_root}"
python3 - "${campaign_root}/agent-dev-kit/docs/changes/adk-v3-1-software-m5-ready/software-m5-campaign-plan.json" <<'PY'
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
value = json.loads(path.read_text(encoding="utf-8"))
value["maximum_worst_cost_usd"] = 1
path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
expect_fail_contains "${campaign_root}" "software M5 campaign plan hash does not match content"

knowledge_root="${TMP_DIR}/knowledge-root"
cp -a "${pass_root}" "${knowledge_root}"
python3 - "${knowledge_root}/reports/current-status.md" <<'PY'
import pathlib
import re
import sys
path = pathlib.Path(sys.argv[1])
path.write_text(re.sub(r"^- knowledge_candidate_status: .+$", "- knowledge_candidate_status: active-promotion-applied", path.read_text(encoding="utf-8"), flags=re.MULTILINE), encoding="utf-8")
PY
expect_fail_contains "${knowledge_root}" "knowledge_candidate_status must be not-required-repo-only"

events_root="${TMP_DIR}/events-root"
cp -a "${pass_root}" "${events_root}"
python3 - "${events_root}/reports/field-evidence/software-m5-events.jsonl" <<'PY'
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
value = json.loads(lines[0])
value["summary"] = "tampered"
lines[0] = json.dumps(value, separators=(",", ":"))
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
expect_fail_contains "${events_root}" "software M5 evidence integrity or scorecard declaration is not pass"

mapped_root="${TMP_DIR}/mapped-root"
cp -a "${pass_root}" "${mapped_root}"
printf 'mapped change\n' >>"${mapped_root}/agent-dev-kit/agents/example/AGENTS.md"
git -C "${mapped_root}/agent-dev-kit" add agents/example/AGENTS.md
git -C "${mapped_root}/agent-dev-kit" commit -q -m "fixture mapped change"
mapped_adk="$(git -C "${mapped_root}/agent-dev-kit" rev-parse HEAD)"
python3 - \
  "${mapped_root}/reports/current-status.md" \
  "${mapped_root}/reports/adk-v3-1-software-m5-ready-release-evidence-2026-07-13.json" \
  "${mapped_root}/adk.lock" \
  "${mapped_adk}" <<'PY'
import json
import pathlib
import re
import sys
status_path, release_path, lock_path, mapped_adk = sys.argv[1:]
status = pathlib.Path(status_path).read_text(encoding="utf-8")
status = re.sub(r"^- agent_dev_kit_commit: .+$", f"- agent_dev_kit_commit: {mapped_adk}", status, flags=re.MULTILINE)
pathlib.Path(status_path).write_text(status, encoding="utf-8")
release = json.loads(pathlib.Path(release_path).read_text(encoding="utf-8"))
release["agent_dev_kit"]["commit"] = mapped_adk
pathlib.Path(release_path).write_text(json.dumps(release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
lock = pathlib.Path(lock_path).read_text(encoding="utf-8")
lock = re.sub(r"agent-dev-kit.commit=.*", f"agent-dev-kit.commit={mapped_adk}", lock)
pathlib.Path(lock_path).write_text(lock, encoding="utf-8")
PY
git -C "${mapped_root}" update-index --cacheinfo "160000,${mapped_adk},agent-dev-kit"
expect_fail_contains "${mapped_root}" "mapped ADK asset paths changed"

dirty_root="${TMP_DIR}/dirty-root"
cp -a "${pass_root}" "${dirty_root}"
printf '\n' >>"${dirty_root}/agent-dev-kit/manifest.json"
expect_fail_contains "${dirty_root}" "current subrepo state is not pass"

echo "[PASS] current M5-ready product status consistency checks behave as expected"
