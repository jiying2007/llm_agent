#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
import tempfile
import tomllib

root = Path(sys.argv[1])
config = tomllib.loads((root / "pyproject.toml").read_text(encoding="utf-8"))
files = config["tool"]["mypy"]["files"]
required = {
    "tools/control_plane/cli.py",
    "tools/control_plane/impact.py",
    "tools/control_plane/process_budget.py",
    "tools/control_plane/receipts.py",
}
assert required <= set(files), files
assert config["tool"]["mypy"]["strict"] is True
workflow = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
assert "python -m mypy --config-file pyproject.toml" in workflow
assert "python -m pip install '.[quality]'" in workflow

# Regression: typed gate parsing must reject a scalar root instead of
# dereferencing it (before mypy this was an unchecked Any).
from tools.control_plane.impact import _load_manifest
with tempfile.TemporaryDirectory(prefix="typed-gate-root-") as dirname:
    invalid = Path(dirname) / "manifests"
    invalid.mkdir()
    (invalid / "gates.json").write_text("null\n", encoding="utf-8")
    try:
        _load_manifest(Path(dirname))
    except ValueError as exc:
        assert "gate manifest root must be an object" in str(exc), str(exc)
    else:
        raise AssertionError("scalar gate root must be rejected")
PY
