#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 -m tools.control_plane.reference_pins --root "$ROOT" --summary-json >"$TMP/check.json"
python3 -m tools.control_plane.reference_pins \
  --root "$ROOT" \
  --plan OpenSpec \
  --cache-root "$TMP/cache" \
  --summary-json >"$TMP/plan.json"

python3 - "$TMP/check.json" "$TMP/plan.json" <<'PY'
import json
import sys
from pathlib import Path

check = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
plan = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

assert check["status"] == "pass", check
assert check["reference_repo_count"] == 8, check
assert set(check["reference_repos"]) == {
    "OpenSpec",
    "digital-worker",
    "mattpocock-skills",
    "oh-my-codex",
    "planning-with-files",
    "scale-engine",
    "superpowers",
    "vibeflow",
}, check

assert plan["status"] == "pass", plan
assert plan["id"] == "OpenSpec", plan
assert plan["commit"] == "3c7a05c5dc88b2397c478805890b55ed392b19e8", plan
assert plan["url"] == "https://github.com/Fission-AI/OpenSpec", plan
assert plan["runtime_enablement"] is False, plan
assert plan["target"].endswith("OpenSpec/3c7a05c5dc88b2397c478805890b55ed392b19e8"), plan
assert not Path(plan["target"]).exists(), plan
PY

if python3 -m tools.control_plane.reference_pins \
  --root "$ROOT" \
  --plan hermes \
  --cache-root "$TMP/cache" \
  >/dev/null 2>&1; then
  echo '[FAIL] non-repository opaque pin unexpectedly produced a materialization plan' >&2
  exit 1
fi

if [[ -e "$TMP/cache/OpenSpec" ]]; then
  echo '[FAIL] plan-only command unexpectedly materialized a repository' >&2
  exit 1
fi

# Repository-governance identity must remain exact after physical gitlink removal.
TAMPERED="$TMP/tampered"
cp -a "$ROOT" "$TAMPERED"
python3 - "$TAMPERED/manifests/reference_pins.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for pin in data["pins"]:
    if pin.get("id") == "digital-worker":
        pin["commit"] = "0" * 40
        break
else:
    raise SystemExit("digital-worker reference pin missing")
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

if (
  cd "$TAMPERED"
  bash scripts/software-m5.sh check --summary-json >/dev/null 2>&1
); then
  echo '[FAIL] Software M5 accepted a digital-worker reference pin that no longer matches hash-bound pilot evidence' >&2
  exit 1
fi

echo '[PASS] reference repositories are exact-pin, cache-only, explicit materialization inputs and M5 field identity stays fail-closed'
