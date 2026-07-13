#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/docs/product-maturity-model.md" ]] || {
  echo "[FAIL] product maturity model missing" >&2
  exit 1
}

[[ -f "$ROOT/manifests/product_maturity_scorecard.json" ]] || {
  echo "[FAIL] product maturity scorecard missing" >&2
  exit 1
}

[[ -f "$ROOT/manifests/product_maturity_task_pack.json" ]] || {
  echo "[FAIL] product maturity task pack missing" >&2
  exit 1
}

[[ -f "$ROOT/manifests/report_registry.json" ]] || {
  echo "[FAIL] report registry missing" >&2
  exit 1
}

python3 - "$ROOT" <<'PY'
import json
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
scorecard = json.loads((root / "manifests/product_maturity_scorecard.json").read_text(encoding="utf-8"))
adk_initialized = (root / "agent-dev-kit/manifest.json").is_file()
assert scorecard["schema"] == "llm-agent-product-maturity-scorecard/v1", scorecard
assert len(scorecard["dimensions"]) == 12, scorecard
assert [item["id"] for item in scorecard["dimensions"]] == [f"D{i:02d}" for i in range(1, 13)]
assert len({item["name"] for item in scorecard["dimensions"]}) == 12, scorecard
assert scorecard["overall"]["terminal_mature"] is False
assert scorecard["overall"]["field_status"] == "field_not_verified"
assert scorecard["release_gates"]["status"] == "conditional-pass", scorecard
levels = {f"M{i}" for i in range(6)}
statuses = {
    "verified",
    "verified_local",
    "partially_verified",
    "implemented",
    "field_not_verified",
}
for dimension in scorecard["dimensions"]:
    assert dimension["priority"] in {"P0", "P1", "P2"}, dimension
    assert dimension["level"] in levels, dimension
    assert dimension["status"] in statuses, dimension
    evidence = dimension.get("evidence")
    assert isinstance(evidence, list) and len(evidence) >= 2, dimension
    for value in evidence:
        path = pathlib.PurePosixPath(value)
        assert not path.is_absolute() and ".." not in path.parts, (dimension, value)
        if path.parts[0] == "agent-dev-kit" and not adk_initialized:
            continue
        assert (root / path).exists(), (dimension, value)
    if dimension["status"] in {"verified", "verified_local"}:
        assert int(dimension["level"][1:]) >= 3, dimension

task_pack = json.loads((root / "manifests/product_maturity_task_pack.json").read_text(encoding="utf-8"))
assert task_pack["schema"] == "llm-agent-product-maturity-task-pack/v1", task_pack
assert all(task_pack["rules"].values()), task_pack
assert [item["id"] for item in task_pack["tasks"]] == [f"PM-{i:02d}" for i in range(1, 11)]
task_statuses = {
    "implemented",
    "in_progress",
    "pending",
    "pending_approval",
    "field_not_verified",
    "blocked_external",
    "not_required",
    "ready",
}
for task in task_pack["tasks"]:
    assert task["status"] in task_statuses, task
    commands = task.get("verify", [])
    assert isinstance(commands, list), task
    assert all(isinstance(command, str) and command.startswith("rtk ") for command in commands), task
    if task["status"] == "implemented":
        assert commands, task
assert next(item for item in task_pack["tasks"] if item["id"] == "PM-09")["status"] == "field_not_verified"

registry = json.loads((root / "manifests/report_registry.json").read_text(encoding="utf-8"))
assert registry["schema"] == "llm-agent-report-registry/v1", registry
current = [item for item in registry["reports"] if item["status"] == "current"]
assert len(current) == 1, registry
ids = {item["id"] for item in registry["reports"]}
for item in registry["reports"]:
    assert item["status"] in {"current", "superseded"}, item
    assert (root / item["path"]).is_file(), item
    if item["status"] == "superseded":
        assert item["superseded_by"] in ids, item
    else:
        assert item["superseded_by"] is None, item
assert registry["policy"]["machine_state_source"] == "manifests/product_maturity_scorecard.json"

github_ci = root / ".github/workflows/ci.yml"
assert github_ci.is_file(), "GitHub is the delivery remote but its blocking CI workflow is missing"
workflow = github_ci.read_text(encoding="utf-8")
assert re.search(r"(?m)^permissions:\n  contents: read$", workflow), workflow
assert "submodules: false" in workflow, workflow
assert "bash tests/test_reference_source_integrity.sh" in workflow, workflow
assert "bash scripts/check-doc-sync.sh ." in workflow, workflow
for action in re.findall(r"(?m)^\s*uses:\s*([^\s#]+)", workflow):
    if action.startswith("./"):
        continue
    assert re.fullmatch(r"[^@]+@[0-9a-f]{40}", action), action

index = subprocess.run(
    ["git", "-C", str(root), "ls-files", "-s", "agent-dev-kit"],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.strip().split()
assert len(index) >= 2 and index[0] == "160000", index
lock = {}
for line in (root / "adk.lock").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        lock[key] = value
assert lock.get("agent-dev-kit.commit") == index[1], (lock, index)
PY

if rg -q 'auto-absorb\.sh' "$ROOT/scripts/pipeline-subrepo-update.sh"; then
  echo "[FAIL] target pipeline still invokes legacy auto-absorb" >&2
  exit 1
fi

if rg -q '待 AI Agent 补充|待评' "$ROOT/scripts/analyze-repo.sh"; then
  echo "[FAIL] analyzer still emits placeholder completion claims" >&2
  exit 1
fi

if rg -q '^[[:space:]]*allow_failure:[[:space:]]*true' "$ROOT/.gitlab-ci.yml"; then
  echo "[FAIL] blocking CI jobs still allow failure" >&2
  exit 1
fi

[[ ! -e "$ROOT/scripts/auto-absorb.sh" ]] || {
  echo "[FAIL] legacy automatic absorption writer still exists" >&2
  exit 1
}

rg -q 'tools\.codex_assets\.intake_pipeline' "$ROOT/scripts/analyze-repo.sh" || {
  echo "[FAIL] analyzer is not routed through the structured intake core" >&2
  exit 1
}

rg -q 'tools\.codex_assets\.update_pipeline' "$ROOT/scripts/pipeline-subrepo-update.sh" || {
  echo "[FAIL] update pipeline is not routed through the fail-fast core" >&2
  exit 1
}

echo "[PASS] llm_agent product maturity contracts hold"
