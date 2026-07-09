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

Validates manifests/runtime_targets.json and runtime_health_adapters.json
against adk.lock, registry.csv and runtime target check scripts. This is a
declaration gate only; it does not apply assets or modify live directories.
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
adapters_path = os.path.join(root, "manifests", "runtime_health_adapters.json")
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


def evidence_has(evidence, *tokens):
    text = " | ".join(str(item).lower() for item in evidence)
    return all(token.lower() in text for token in tokens)


manifest = read_json(manifest_path)
adapters_manifest = read_json(adapters_path)
lock = read_lock(lock_path)
registry = read_registry(registry_path)

target_count = 0
adapter_count = 0
default_target = None
default_runtime = "-"
default_live_root = "-"
enabled_count = 0
candidate_count = 0
enabled_adapter_count = 0
candidate_adapter_count = 0
supported = set()
adapter_by_id = {}
target_by_id = {}
enabled_target_ids = set()

required_kinds = {"codex", "claude-code", "hermes-agent", "opencode"}
required_rules = {
    "targets_must_be_declared",
    "live_writes_must_use_declared_apply_chain",
    "llm_agent_must_not_write_live_root",
    "reference_subrepos_must_not_be_runtime_targets",
    "future_targets_require_source_and_live_chain",
}
required_adapter_rules = {
    "targets_must_reference_adapter_id",
    "enabled_adapters_must_be_read_only",
    "enabled_adapters_must_have_executable_script",
    "disabled_adapters_must_not_dispatch",
    "adapter_runtime_must_match_target_runtime",
}

if adapters_manifest:
    if adapters_manifest.get("schema_version") != 1:
        fail("runtime_health_adapters.json schema_version must be 1")
    if adapters_manifest.get("status") != "active":
        fail("runtime_health_adapters.json status must be active")

    adapter_rules = adapters_manifest.get("rules")
    if not isinstance(adapter_rules, dict):
        fail("runtime_health_adapters.json rules must be an object")
    else:
        for rule in required_adapter_rules:
            if adapter_rules.get(rule) is not True:
                fail(f"runtime_health_adapters.json rules.{rule} must be true")

    adapters = adapters_manifest.get("adapters")
    if not isinstance(adapters, list) or not adapters:
        fail("runtime_health_adapters.json adapters must be a non-empty array")
        adapters = []
    adapter_count = len(adapters)
    adapter_ids = [item.get("id") for item in adapters if isinstance(item, dict)]
    if len(adapter_ids) != len(set(adapter_ids)):
        fail("runtime health adapter ids must be unique")
    adapter_by_id = {item.get("id"): item for item in adapters if isinstance(item, dict)}
    adapter_runtimes = {item.get("runtime") for item in adapters if isinstance(item, dict)}
    missing_adapter_kinds = required_kinds - adapter_runtimes
    if missing_adapter_kinds:
        fail(f"runtime_health_adapters.json missing adapter for runtime kinds: {', '.join(sorted(missing_adapter_kinds))}")

    for item in adapters:
        if not isinstance(item, dict):
            fail("runtime health adapter entries must be objects")
            continue
        adapter_id = item.get("id")
        runtime = item.get("runtime")
        if runtime not in required_kinds:
            fail(f"runtime health adapter uses unsupported runtime kind: {runtime}")
        if item.get("read_only") is not True:
            fail(f"runtime health adapter must be read_only=true: {adapter_id}")
        enabled = item.get("enabled")
        if enabled is True:
            enabled_adapter_count += 1
            if item.get("status") != "active":
                fail(f"enabled runtime health adapter must use status=active: {adapter_id}")
            script = item.get("script")
            if not script:
                fail(f"enabled runtime health adapter missing script: {adapter_id}")
            else:
                script_must_exist(script)
            target_ids = item.get("target_ids")
            if not isinstance(target_ids, list) or not target_ids:
                fail(f"enabled runtime health adapter must bind at least one target: {adapter_id}")
            profiles = set(item.get("profiles") or [])
            for profile in ("minimal", "security", "strict"):
                if profile not in profiles:
                    fail(f"enabled runtime health adapter missing profile: {adapter_id} -> {profile}")
        elif enabled is False:
            candidate_adapter_count += 1
            if item.get("status") != "candidate":
                fail(f"disabled runtime health adapter must use status=candidate: {adapter_id}")
            if item.get("script") is not None:
                fail(f"disabled runtime health adapter must not declare script: {adapter_id}")
            if item.get("target_ids") != []:
                fail(f"disabled runtime health adapter target_ids must be empty: {adapter_id}")
            if item.get("profiles") != []:
                fail(f"disabled runtime health adapter profiles must be empty: {adapter_id}")
            requirements = item.get("activation_requirements") or []
            for required in ("declare active runtime target", "add executable read-only health script", "bind target.health_adapter to this adapter id", "pass disabled target negative gate before activation"):
                if required not in requirements:
                    fail(f"disabled runtime health adapter missing activation requirement: {adapter_id} -> {required}")
        else:
            fail(f"runtime health adapter enabled must be boolean: {adapter_id}")

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
    target_by_id = {item.get("id"): item for item in targets if isinstance(item, dict)}
    by_runtime = {item.get("runtime"): item for item in targets if isinstance(item, dict)}
    for runtime in required_kinds:
        if runtime not in by_runtime:
            fail(f"runtime_targets.json missing target or candidate for runtime: {runtime}")

    for item in targets:
        if not isinstance(item, dict):
            fail("runtime target entries must be objects")
            continue
        runtime = item.get("runtime")
        if runtime not in supported:
            fail(f"runtime target uses unsupported runtime kind: {runtime}")
        if "health_check" in item:
            fail(f"runtime target must not declare health_check; use health_adapter: {item.get('id')}")
        enabled = item.get("enabled")
        if enabled is True:
            enabled_count += 1
            target_id = item.get("id")
            enabled_target_ids.add(target_id)
            if item.get("role") == "target-candidate":
                fail(f"enabled runtime target must not use role=target-candidate: {target_id}")
            for field in ("source_repo", "live_root", "registry_repo", "health_adapter"):
                if not item.get(field):
                    fail(f"enabled runtime target missing {field}: {target_id}")
            if item.get("write_policy") == "not-enabled":
                fail(f"enabled runtime target must not use write_policy=not-enabled: {target_id}")
            source_chain = item.get("source_to_live_chain")
            if not isinstance(source_chain, list) or not source_chain:
                fail(f"enabled runtime target source_to_live_chain must be non-empty: {target_id}")
            health_adapter_id = item.get("health_adapter")
            adapter = adapter_by_id.get(health_adapter_id)
            if health_adapter_id and not adapter:
                fail(f"enabled runtime target health_adapter not declared: {target_id} -> {health_adapter_id}")
            elif adapter:
                if adapter.get("enabled") is not True:
                    fail(f"enabled runtime target health_adapter must be enabled: {target_id} -> {health_adapter_id}")
                if adapter.get("runtime") != runtime:
                    fail(f"enabled runtime target health_adapter runtime mismatch: {target_id} -> {health_adapter_id}")
                if target_id not in (adapter.get("target_ids") or []):
                    fail(f"enabled runtime target health_adapter missing target binding: {target_id} -> {health_adapter_id}")
            for field in ("footprint_check", "target_policy_check"):
                script = item.get(field)
                if not script:
                    fail(f"enabled runtime target missing {field}: {target_id}")
                else:
                    script_must_exist(script)
            evidence = set(item.get("required_evidence") or [])
            required_evidence_classes = {
                "dry-run apply evidence": ("dry-run",),
                "rollback evidence": ("rollback",),
                "runtime health": ("runtime", "health"),
                "runtime live footprint": ("runtime", "live", "footprint"),
            }
            for required, tokens in required_evidence_classes.items():
                if not evidence_has(evidence, *tokens):
                    fail(f"enabled runtime target required_evidence missing: {target_id} -> {required}")
        elif enabled is False:
            candidate_count += 1
            if item.get("role") != "target-candidate":
                fail(f"disabled runtime target must use role=target-candidate: {item.get('id')}")
            if item.get("write_policy") != "not-enabled":
                fail(f"disabled runtime target must use write_policy=not-enabled: {item.get('id')}")
            for field in ("source_repo", "live_root", "registry_repo", "health_adapter", "footprint_check", "target_policy_check"):
                if item.get(field) is not None:
                    fail(f"disabled runtime target must not declare active {field}: {item.get('id')}")
            if item.get("source_to_live_chain") != []:
                fail(f"disabled runtime target source_to_live_chain must be empty: {item.get('id')}")
            requirements = item.get("activation_requirements") or []
            for required in ("declare source_repo and live_root", "add read-only health adapter", "add source-to-live apply and rollback evidence", "pass runtime target gate with enabled=true"):
                if required not in requirements:
                    fail(f"disabled runtime target missing activation requirement: {item.get('id')} -> {required}")
        else:
            fail(f"runtime target enabled must be boolean: {item.get('id')}")

    default_id = manifest.get("default_target")
    default_target = next((item for item in targets if isinstance(item, dict) and item.get("id") == default_id), None)
    if not default_target:
        fail("runtime_targets.json default_target must reference a declared target")

for adapter_id, adapter in adapter_by_id.items():
    if adapter.get("enabled") is not True:
        continue
    for target_id in adapter.get("target_ids") or []:
        target = target_by_id.get(target_id)
        if not target:
            fail(f"enabled runtime health adapter target_id not declared: {adapter_id} -> {target_id}")
            continue
        if target.get("enabled") is not True:
            fail(f"enabled runtime health adapter target_id is not enabled: {adapter_id} -> {target_id}")
        if target.get("runtime") != adapter.get("runtime"):
            fail(f"enabled runtime health adapter target runtime mismatch: {adapter_id} -> {target_id}")

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

    health_adapter_id = default_target.get("health_adapter")
    if not health_adapter_id:
        fail("default runtime missing health_adapter")

    evidence = set(default_target.get("required_evidence") or [])
    for item in ("~/codex build", "~/codex doctor", "~/codex apply plan", "~/codex apply dry-run", "rollback evidence", "global runtime health", "runtime live footprint"):
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
            "health_adapters": adapter_count,
            "enabled_targets": enabled_count,
            "candidate_targets": candidate_count,
            "enabled_health_adapters": enabled_adapter_count,
            "candidate_health_adapters": candidate_adapter_count,
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
        "health_adapters": adapter_count,
        "enabled_targets": enabled_count,
        "candidate_targets": candidate_count,
        "enabled_health_adapters": enabled_adapter_count,
        "candidate_health_adapters": candidate_adapter_count,
        "default_target": manifest.get("default_target"),
        "default_runtime": default_runtime,
        "default_live_root": default_live_root,
        "supported_runtime_kinds": sorted(supported),
        "failures": [],
    }, ensure_ascii=False, separators=(",", ":")))
else:
    print(f"[PASS] runtime targets ready: targets={target_count} enabled={enabled_count} candidates={candidate_count} adapters={adapter_count} enabled_adapters={enabled_adapter_count} default={manifest.get('default_target')} runtime={default_runtime} live_root={default_live_root}")
PY
