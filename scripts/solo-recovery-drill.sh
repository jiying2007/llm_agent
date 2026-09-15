#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${RUNNER_TEMP:-/tmp}/solo-maintainer-recovery-receipt.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || { echo "[FAIL] --output requires a path" >&2; exit 2; }
      OUTPUT="$2"
      shift 2
      ;;
    *)
      echo "[FAIL] unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "[FAIL] git is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[FAIL] python3 is required" >&2; exit 1; }

RUN_ROOT="$(mktemp -d "${RUNNER_TEMP:-/tmp}/llm-agent-solo-recovery.XXXXXX")"
trap 'rm -rf "$RUN_ROOT"' EXIT
TARGET="$RUN_ROOT/isolated-target"
PLAN1="$RUN_ROOT/install-1.json"
PLAN2="$RUN_ROOT/install-2.json"
FIRST_STATE="$RUN_ROOT/first-state.json"
ADK_DIR="$ROOT_DIR/agent-dev-kit"
RECEIPT="$TARGET/.adk-install-receipt.json"
VENV="$RUN_ROOT/venv"

cd "$ROOT_DIR"

# Reconstruct the authoritative ADK source from the tracked gitlink rather than
# reusing an existing local ADK checkout.
rm -rf "$ADK_DIR"
git submodule update --init --depth=1 agent-dev-kit
bash scripts/check-adk-lock.sh .

python3 -m venv "$VENV"
PYTHON="$VENV/bin/python"
"$PYTHON" -m pip install --disable-pip-version-check --quiet -e "$ADK_DIR"
export ADK_PYTHON_BIN="$PYTHON"
export ADK_REQUIRE_SUPPORTED_PYTHON=1

# Validate the reconstructed component before touching the isolated target.
bash "$ADK_DIR/scripts/devkit.sh" validate --strict --summary-json > "$RUN_ROOT/adk-validate.json"

install_plan() {
  local output="$1"
  bash "$ADK_DIR/scripts/devkit.sh" install plan \
    --tool claude-code \
    --target "$TARGET" \
    --asset-kind skill \
    --mode copy \
    --output "$output" \
    --ttl-minutes 30 \
    --summary-json
}

install_plan "$PLAN1" > "$RUN_ROOT/plan-1-summary.json"
bash "$ADK_DIR/scripts/devkit.sh" install apply --plan "$PLAN1" --summary-json > "$RUN_ROOT/apply-1.json"
[[ -f "$RECEIPT" ]] || { echo "[FAIL] first install receipt missing" >&2; exit 1; }

"$PYTHON" - "$RECEIPT" "$FIRST_STATE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

receipt_path = Path(sys.argv[1])
out = Path(sys.argv[2])
data = json.loads(receipt_path.read_text(encoding="utf-8"))
assert data["schema"] == "adk-install-receipt/v3", data
assert data["installed"], data
out.write_text(json.dumps({
    "receipt_file_sha256": hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
    "receipt_sha256": data["receipt_sha256"],
    "installed": {item["destination"]: item["installed_sha256"] for item in data["installed"]},
}, sort_keys=True) + "\n", encoding="utf-8")
PY

# Apply the same authoritative bundle a second time. This exercises the
# replace-managed path and creates a previous-receipt/backup chain.
install_plan "$PLAN2" > "$RUN_ROOT/plan-2-summary.json"
bash "$ADK_DIR/scripts/devkit.sh" install apply --plan "$PLAN2" --summary-json > "$RUN_ROOT/apply-2.json"
[[ -f "$RECEIPT" ]] || { echo "[FAIL] second install receipt missing" >&2; exit 1; }

# First rollback must restore the exact first receipt and managed asset state.
bash "$ADK_DIR/scripts/devkit.sh" install rollback --receipt "$RECEIPT" --summary-json > "$RUN_ROOT/rollback-2.json"
[[ -f "$RECEIPT" ]] || { echo "[FAIL] previous receipt was not restored" >&2; exit 1; }
"$PYTHON" - "$TARGET" "$RECEIPT" "$FIRST_STATE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
receipt = Path(sys.argv[2])
state = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
assert hashlib.sha256(receipt.read_bytes()).hexdigest() == state["receipt_file_sha256"]
restored = json.loads(receipt.read_text(encoding="utf-8"))
assert restored["receipt_sha256"] == state["receipt_sha256"]
for relative, expected in state["installed"].items():
    path = target / relative
    assert path.is_file(), relative
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest == expected, (relative, digest, expected)
PY

# Second rollback returns the isolated target to the pre-install state.
bash "$ADK_DIR/scripts/devkit.sh" install rollback --receipt "$RECEIPT" --summary-json > "$RUN_ROOT/rollback-1.json"
[[ ! -e "$RECEIPT" ]] || { echo "[FAIL] final receipt still exists after rollback" >&2; exit 1; }
"$PYTHON" - "$TARGET" "$FIRST_STATE" <<'PY'
import json
import sys
from pathlib import Path

target = Path(sys.argv[1])
state = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
leftovers = [relative for relative in state["installed"] if (target / relative).exists()]
assert not leftovers, leftovers
PY

mkdir -p "$(dirname "$OUTPUT")"
ROOT_COMMIT="$(git rev-parse HEAD)"
ADK_COMMIT="$(git -C "$ADK_DIR" rev-parse HEAD)"
ADK_TREE="$(git -C "$ADK_DIR" rev-parse 'HEAD^{tree}')"
ADK_VERSION="$(awk -F= '$1=="agent-dev-kit.version" {print $2}' adk.lock)"
LOCKED_ADK_COMMIT="$(awk -F= '$1=="agent-dev-kit.commit" {print $2}' adk.lock)"
LOCKED_ADK_TREE="$(awk -F= '$1=="agent-dev-kit.tree" {print $2}' adk.lock)"

"$PYTHON" - "$OUTPUT" "$FIRST_STATE" "$ROOT_COMMIT" "$ADK_VERSION" "$ADK_COMMIT" "$ADK_TREE" "$LOCKED_ADK_COMMIT" "$LOCKED_ADK_TREE" <<'PY'
import datetime
import json
import os
import platform
import sys
from pathlib import Path

out, state_path, root_commit, adk_version, adk_commit, adk_tree, locked_commit, locked_tree = sys.argv[1:]
assert adk_commit == locked_commit
assert adk_tree == locked_tree
state = json.loads(Path(state_path).read_text(encoding="utf-8"))
receipt = {
    "schema": "llm-agent-solo-recovery-receipt/v1",
    "status": "pass",
    "generated_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "source": {
        "llm_agent_commit": root_commit,
        "agent_dev_kit_version": adk_version,
        "agent_dev_kit_commit": adk_commit,
        "agent_dev_kit_tree": adk_tree,
        "lock_identity_match": True,
    },
    "environment": {
        "runner_os": os.environ.get("RUNNER_OS", platform.system()),
        "python": platform.python_version(),
        "github_run_id": os.environ.get("GITHUB_RUN_ID"),
        "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "github_sha": os.environ.get("GITHUB_SHA"),
    },
    "drill": {
        "fresh_dependency_materialization": True,
        "isolated_virtual_environment": True,
        "isolated_target": True,
        "adk_strict_validation": "pass",
        "transaction_target_contract": "claude-code",
        "runtime_invoked": False,
        "first_receipt_sha256": state["receipt_sha256"],
        "managed_asset_count": len(state["installed"]),
        "replace_managed_apply": "pass",
        "previous_receipt_restore": "pass",
        "restored_asset_digest_check": "pass",
        "final_rollback": "pass",
        "final_target_managed_assets_absent": True,
    },
    "qualification_boundary": "This receipt proves clean-source reconstruction and transactional install/rollback recovery only; it is not native runtime evidence and does not satisfy multi-runtime portability.",
}
Path(out).write_text(json.dumps(receipt, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

cat "$OUTPUT"
