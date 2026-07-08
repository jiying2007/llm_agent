#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SUMMARY_JSON=0

if [[ $# -gt 0 && "$1" != --* ]]; then
  ROOT="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary-json)
      SUMMARY_JSON=1
      shift
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-runtime-targets.sh [root] [--summary-json]

Validates manifests/runtime_targets.json against adk.lock, registry.csv and
runtime target check scripts. This is a declaration gate only; it does not
apply assets or modify live runtime directories.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

python3 - "$ROOT" "$SUMMARY_JSON" <<'PY'
import csv
import json
import os
import sys

root = sys.argv[1]
summary_json = sys.argv[2] == "1"
manifest_path = os.path.join(root, "manifests", "runtime_targets.json")
lock_path = os.path.join(root, "adk.lock")
registry_path = os.path.join(root, "subrepos", "registry.csv")
failures = []


def fail(message):
    failures.append(message)


def rel(path):
    return os.path.relpath(path, root)


def read_json(path):
    if not os.path.isfile(path):
        fail(f"missing file: {rel(path)}")
        return None
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except Exception as exc:
        fail(f"invalid JSON in {rel(path)}: {exc}")
        return None


def read_lock(path):
    values = {}
    if not os.path.isfile(path):
        fail(f"missing file: {rel(path)}")
        return values
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key] = value
    return values


def read_registry(path):
    if not os.path.isfile(path):
        fail(f"missing file: {rel(path)}")
        return {}
    with open(path, "r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    return {row.get("repo"): row for row in rows if row.get("repo")}


def script_must_exist(script):
    path = os.path.join(root, script)
    if not os.path.isfile(path):
        fail(f"runtime target script missing: {script}")
    elif not os.access(path, os.X_OK):
        fail(f"runtime target script not executable: {script}")


manifest = read_json(manifest_path)
lock = read_lock(lock_path)
registry = read_registry(registry_path)

target_count = 0
default_target = None
default_runtime = "-"
default_live_root = "-"
supported = set()

required_kinds = {"codex", "claude-code", "hermes-agent", "opencode"}
required_rules = {
    "targets_must_be_declared",
    "live_writes_must_use_declared_apply_chain",
    "llm_agent_must_not_write_live_root",
    "reference_subrepos_must_not_be_runtime_targets",
    "future_targets_require_source_and_live_chain",
}

if manifest:
    if manifest.get("schema_version") != 1:
        fail("runtime_targets.json schema_version must be 1")
    if manifest.get("status") != "active":
        fail("runtime_targets.json status must be active")

    supported = set(manifest.get("supported_runtime_kinds") or [])
    missing_kinds = required_kinds - supported
    if missing_kinds:
        fail(f"runtime_targets.json missing supported runtime kinds: {', '.join(sorted(missing_kinds))}")

    rules = manifest.get("rules")
    if not isinstance(rules, dict):
        fail("runtime_targets.json rules must be an object")
    else:
        for rule in required_rules:
            if rules.get(rule) is not True:
                fail(f"runtime_targets.json rules.{rule} must be true")

    targets = manifest.get("targets")
    if not isinstance(targets, list) or not targets:
        fail("runtime_targets.json targets must be a non-empty array")
        targets = []
    target_count = len(targets)
    target_ids = [item.get("id") for item in targets if isinstance(item, dict)]
    if len(target_ids) != len(set(target_ids)):
        fail("runtime target ids must be unique")

    default_id = manifest.get("default_target")
    default_target = next((item for item in targets if isinstance(item, dict) and item.get("id") == default_id), None)
    if not default_target:
        fail("runtime_targets.json default_target must reference a declared target")

if default_target:
    default_runtime = default_target.get("runtime") or "-"
    default_live_root = default_target.get("live_root") or "-"

    if default_target.get("runtime") != "codex":
        fail("default runtime target must currently be codex")
    if default_target.get("source_repo") != lock.get("codex.source"):
        fail("default runtime source_repo must match adk.lock codex.source")
    if default_target.get("live_root") != lock.get("codex.target"):
        fail("default runtime live_root must match adk.lock codex.target")
    if default_target.get("registry_repo") != "codex":
        fail("default runtime registry_repo must be codex")
    if default_target.get("enabled") is not True:
        fail("default runtime target must be enabled=true")
    if default_target.get("write_policy") != "report-only-from-llm_agent":
        fail("default runtime write_policy must be report-only-from-llm_agent")
    if default_target.get("source_to_live_chain") != ["agent-dev-kit", "~/codex", "~/.codex"]:
        fail("default runtime source_to_live_chain drift")

    for field in ("health_check", "footprint_check", "target_policy_check"):
        script = default_target.get(field)
        if not script:
            fail(f"default runtime missing {field}")
        else:
            script_must_exist(script)

    evidence = set(default_target.get("required_evidence") or [])
    for item in ("~/codex build", "~/codex doctor", "~/codex apply plan", "~/codex apply dry-run", "global runtime health", "runtime live footprint"):
        if item not in evidence:
            fail(f"default runtime required_evidence missing: {item}")

codex_row = registry.get("codex")
if not codex_row:
    fail("registry.csv missing codex row")
else:
    if codex_row.get("group") != "runtime-target":
        fail("codex registry group must be runtime-target")
    if codex_row.get("enabled") != "no":
        fail("codex registry enabled must remain no")
    if codex_row.get("status") != "disabled":
        fail("codex registry status must remain disabled")
    if codex_row.get("intake_policy") != "pilot-first":
        fail("codex registry intake_policy must be pilot-first")
    notes = codex_row.get("notes") or ""
    for token in ("~/codex", "~/.codex"):
        if token not in notes:
            fail(f"codex registry notes must mention {token}")

if os.path.isdir(os.path.join(root, "codex")):
    fail("workspace-local codex/ directory must not exist")

if failures:
    if summary_json:
        print(json.dumps({
            "status": "fail",
            "targets": target_count,
            "default_target": manifest.get("default_target") if manifest else None,
            "default_runtime": default_runtime,
            "default_live_root": default_live_root,
            "supported_runtime_kinds": sorted(supported),
            "failures": failures,
        }, ensure_ascii=False, separators=(",", ":")))
    else:
        for message in failures:
            print(f"[FAIL] {message}", file=sys.stderr)
    sys.exit(1)

if summary_json:
    print(json.dumps({
        "status": "pass",
        "targets": target_count,
        "default_target": manifest.get("default_target"),
        "default_runtime": default_runtime,
        "default_live_root": default_live_root,
        "supported_runtime_kinds": sorted(supported),
        "failures": [],
    }, ensure_ascii=False, separators=(",", ":")))
else:
    print(f"[PASS] runtime targets ready: targets={target_count} default={manifest.get('default_target')} runtime={default_runtime} live_root={default_live_root}")
PY
