#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
git -C "$TMP" config user.name Fixture
git -C "$TMP" config user.email fixture@example.invalid
printf 'bounded fixture\n' >"$TMP/a.txt"
git -C "$TMP" add a.txt
git -C "$TMP" commit -qm "bounded Git collector fixture"

PYTHONPATH="$ROOT" python3 - "$TMP" <<'PY'
import sys
from pathlib import Path
from unittest.mock import patch

from tools.codex_assets import maintainability_evidence as collector
from tools.codex_assets.maintainability_budget import BudgetError

repository = Path(sys.argv[1])
with patch.object(collector, "run_bounded", wraps=collector.run_bounded) as bounded:
    revision = collector._git(repository, ["rev-parse", "HEAD"]).strip()
    assert len(revision) == 40, revision
    raw = collector._git(repository, ["ls-tree", "-r", "-z", "--name-only", "HEAD"], text=False)
    assert isinstance(raw, bytes) and b"a.txt\0" in raw, raw
    assert bounded.call_count == 2, bounded.call_count
    assert bounded.call_args.kwargs["max_stdout"] == collector.MAX_GIT_OUTPUT_BYTES
    assert bounded.call_args.kwargs["max_stderr"] == collector.MAX_GIT_STDERR_BYTES
    assert bounded.call_args.kwargs["timeout"] == collector.MAX_GIT_SECONDS

# Deliberately lower the enforced budget below the 41-byte Git commit SHA.
# The child must be stopped by bounded streaming, not post-read allocation.
with patch.object(collector, "MAX_GIT_OUTPUT_BYTES", 32):
    try:
        collector._git(repository, ["rev-parse", "HEAD"])
    except BudgetError as exc:
        assert "runtime or output budget" in str(exc), str(exc)
    else:
        raise AssertionError("Git stdout byte cap did not fail closed")

try:
    collector._git(repository, ["rev-parse", "--verify", "does-not-exist^{commit}"])
except BudgetError as exc:
    assert "Git evidence command failed" in str(exc), str(exc)
else:
    raise AssertionError("nonzero Git exit must not produce evidence")
PY

echo '[PASS] Git history evidence subprocess I/O and runtime budgets'
