#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
workflow_root = root / ".github" / "workflows"
workflows = sorted(workflow_root.glob("*.yml")) + sorted(workflow_root.glob("*.yaml"))
assert workflows, "no GitHub workflows found"

expected = {
    "actions/checkout": "3d3c42e5aac5ba805825da76410c181273ba90b1",  # v7.0.1
    "actions/setup-python": "5fda3b95a4ea91299a34e894583c3862153e4b97",  # v7.0.0
    "actions/upload-artifact": "043fb46d1a93c77aae656e7c1c64a875d1fc6a0a",  # v7.0.1
    "sigstore/cosign-installer": "6f9f17788090df1f26f669e9d70d6ae9567deba6",  # v4.1.2
}
seen = {name: 0 for name in expected}
failures = []
uses_re = re.compile(r"^\s*-?\s*uses:\s*([^\s@]+)@([^\s#]+)")

for path in workflows:
    text = path.read_text(encoding="utf-8")
    if "ubuntu-latest" in text:
        failures.append(f"{path.relative_to(root)} uses floating ubuntu-latest")
    for lineno, line in enumerate(text.splitlines(), 1):
        match = uses_re.match(line)
        if not match:
            continue
        action, ref = match.groups()
        if re.fullmatch(r"[0-9a-f]{40}", ref) is None:
            failures.append(f"{path.relative_to(root)}:{lineno} action is not exact-SHA pinned: {action}@{ref}")
            continue
        if action in expected:
            seen[action] += 1
            if ref != expected[action]:
                failures.append(
                    f"{path.relative_to(root)}:{lineno} stale action identity: "
                    f"{action}@{ref}, expected {expected[action]}"
                )

for action in ("actions/checkout", "actions/setup-python", "actions/upload-artifact"):
    if seen[action] == 0:
        failures.append(f"required workflow action not found: {action}")

if failures:
    raise SystemExit("\n".join(failures))

print(
    "[PASS] Root workflows use pinned Node24-generation action identities "
    + " ".join(f"{name}={count}" for name, count in sorted(seen.items()))
)
PY
