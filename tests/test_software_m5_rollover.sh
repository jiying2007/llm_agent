#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
GOOD="$TMP/good"
BAD="$TMP/bad"

python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
ledger = json.loads((root / "manifests/software_m5_pilot_ledger.json").read_text(encoding="utf-8"))
policy = json.loads((root / "manifests/software_m5_policy.json").read_text(encoding="utf-8"))
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
# Historical pilot-start evidence is immutable hash-bound evidence and is not
# rewritten by this current-ledger policy ratchet.
assert (root / "reports/field-evidence/software-m5-independent-pilot-start-2026-09-12.json").is_file()
PY

cp -a "$ROOT" "$GOOD"
cp -a "$ROOT" "$BAD"

make_evidence() {
  local repo="$1"
  local out="$2"
  local gate="$3"
  python3 - "$repo" "$out" "$gate" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
out = Path(sys.argv[2])
gate = sys.argv[3] == "true"
lock = {}
for line in (root / "adk.lock").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value

evidence = {
    "schema": "llm-agent-runtime-smoke-evidence/v1",
    "evidence_id": "synthetic-rollover-selftest-only",
    "generated_at": "2026-09-12T00:00:00Z",
    "review_after": "2026-10-12",
    "runtime": "codex",
    "runtime_version": "codex-cli selftest",
    "runtime_binary_sha256": "1" * 64,
    "requested_model": "gpt-5.5",
    "adk_commit": lock["agent-dev-kit.commit"],
    "adk_tree": lock["agent-dev-kit.tree"],
    "manifest_blob": lock["agent-dev-kit.manifest_blob"],
    "manifest_version": lock["agent-dev-kit.version"],
    "manifest_sha256": "2" * 64,
    "raw_result_sha256": "3" * 64,
    "collection": {"collector": "selftest", "task_limit": 1, "raw_report_retained_in_repository": False},
    "result": {
        "schema_version": 1,
        "suite": "runtime-routing",
        "runtime": "codex",
        "runtime_version": "codex-cli selftest",
        "requested_model": "gpt-5.5",
        "condition": "adk",
        "status": "pass",
        "quality_gate": {
            "success_rate": gate,
            "route_accuracy": True,
            "safety_accuracy": True,
            "runtime_errors": True,
        },
    },
    "raw_content_stored": False,
}
payload = json.dumps(evidence, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
evidence["evidence_sha256"] = hashlib.sha256(payload).hexdigest()
out.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
}

make_evidence "$GOOD" "$TMP/good-evidence.json" true
(
  cd "$GOOD"
  if ! python3 -m tools.codex_assets.software_m5_rollover \
    --root . \
    --runtime-evidence "$TMP/good-evidence.json" \
    --root-integration-run-id 34703075857 \
    --qualification-time 2026-09-12T00:10:00Z \
    --apply \
    --summary-json >"$TMP/rollover-summary.json"; then
    echo "[FAIL] Software M5 rollover command failed" >&2
    cat "$TMP/rollover-summary.json" >&2 || true
    exit 1
  fi
  if ! bash scripts/software-m5.sh certify --summary-json >"$TMP/certification.json"; then
    echo "[FAIL] Software M5 certification failed after rollover" >&2
    cat "$TMP/certification.json" >&2 || true
    exit 1
  fi
  if ! python3 -m tools.control_plane.status_projection \
    --root . \
    --today 2026-09-12 \
    --require-fresh \
    --summary-json >"$TMP/projection.json"; then
    echo "[FAIL] status projection failed after rollover" >&2
    cat "$TMP/projection.json" >&2 || true
    exit 1
  fi
)

python3 - "$GOOD" "$TMP/rollover-summary.json" "$TMP/certification.json" "$TMP/projection.json" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
summary = json.loads(Path(sys.argv[2]).read_text())
cert = json.loads(Path(sys.argv[3]).read_text())
projection = json.loads(Path(sys.argv[4]).read_text())
policy = json.loads((root / "manifests/software_m5_policy.json").read_text())
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text())
status = (root / "reports/current-status.md").read_text()
lock = {}
for line in (root / "adk.lock").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value
expected_version = lock["agent-dev-kit.version"]
expected_commit = lock["agent-dev-kit.commit"]
release_train_token = expected_version.replace(".", "_").replace("-", "_").replace("+", "_") + "_release_train"

assert summary["status"] == "pass", summary
assert summary["candidate_version"] == expected_version, summary
assert summary["release_authorized"] is True, summary
assert summary["software_m5_certified"] is True, summary
assert len(summary["changed_paths"]) == 5, summary
assert policy["release"]["candidate_version"] == expected_version, policy
assert policy["release"]["candidate_commit"] == expected_commit, policy
assert policy["runtime_qualification"]["measured_evidence"] == [summary["runtime_evidence"]], policy
assert policy["qualification_record"] == summary["qualification_record"], policy
assert expected_version in Path(summary["qualification_record"]).name
assert scorecard["software_m5"]["candidate_version"] == expected_version, scorecard
assert scorecard["working_candidate"]["version"] == expected_version, scorecard
assert release_train_token not in scorecard["software_m5"]["advisory_followups"], scorecard
assert cert["software_m5_certified"] is True and cert["declaration_status"] == "pass", cert
assert projection["status"] == "pass" and projection["release_authorized"] is True, projection
assert projection["current_evidence_state"] == "verified-for-current-source", projection
assert projection["last_verified_baseline"]["fresh_for_current_source"] is True, projection
assert "- release_evidence_relation: current" in status
assert "- release_authorized: true" in status
assert "- baseline_release_authorized: true" in status
PY

# Exercise the same review-bundle contract used by the manual hosted workflow.
BUNDLE="$TMP/rollover-candidate"
mkdir -p "$BUNDLE"
python3 - "$GOOD" "$TMP/rollover-summary.json" "$BUNDLE" <<'PY'
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
summary = json.loads(Path(sys.argv[2]).read_text())
bundle = Path(sys.argv[3])
for relative in summary["changed_paths"]:
    src = root / relative
    dst = bundle / relative
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
PY
mapfile -t CHANGED_PATHS < <(python3 - "$TMP/rollover-summary.json" <<'PY'
import json
import sys
from pathlib import Path
for relative in json.loads(Path(sys.argv[1]).read_text())["changed_paths"]:
    print(relative)
PY
)
(
  cd "$GOOD"
  git add -N -- "${CHANGED_PATHS[@]}"
  git diff --binary >"$TMP/rollover.patch"
  git reset --mixed HEAD >/dev/null
)
if [[ "${#CHANGED_PATHS[@]}" -ne 5 ]]; then
  echo "[FAIL] rollover changed_paths count expected=5 actual=${#CHANGED_PATHS[@]}" >&2
  printf '  %s\n' "${CHANGED_PATHS[@]}" >&2
  exit 1
fi
if [[ ! -s "$TMP/rollover.patch" ]]; then
  echo "[FAIL] rollover patch is empty" >&2
  exit 1
fi
bundle_count="$(find "$BUNDLE" -type f | wc -l)"
if [[ "$bundle_count" -ne 5 ]]; then
  echo "[FAIL] rollover review bundle file count expected=5 actual=$bundle_count" >&2
  find "$BUNDLE" -type f -printf '  %P\n' >&2
  exit 1
fi

make_evidence "$BAD" "$TMP/bad-evidence.json" false
before="$(git -C "$BAD" status --porcelain=v1)"
if (
  cd "$BAD"
  python3 -m tools.codex_assets.software_m5_rollover \
    --root . \
    --runtime-evidence "$TMP/bad-evidence.json" \
    --root-integration-run-id 34703075857 \
    --apply >/dev/null 2>&1
); then
  echo "[FAIL] rollover accepted failed measured-runtime quality gate" >&2
  exit 1
fi
after="$(git -C "$BAD" status --porcelain=v1)"
[[ "$before" == "$after" ]] || {
  echo "[FAIL] rejected rollover left repository mutations" >&2
  diff -u <(printf '%s\n' "$before") <(printf '%s\n' "$after") || true
  exit 1
}

echo "[PASS] Software M5 rollover is current-source, certifier-backed, fresh, bundle-ready and transactional"
