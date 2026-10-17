#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
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
PY
