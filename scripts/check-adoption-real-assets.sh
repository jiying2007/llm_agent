#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SUMMARY_JSON=0

if [[ "${2:-}" == "--summary-json" ]]; then
  SUMMARY_JSON=1
fi

python3 - "$ROOT" "$SUMMARY_JSON" <<'PY'
import json
import os
import re
import sys

root = sys.argv[1]
summary_json = sys.argv[2] == "1"

matrix_paths = [
    os.path.join(root, "subrepos/adoption-matrix.md"),
    os.path.join(root, "agent-dev-kit/docs/reference-adoption-matrix.md"),
]

excluded_asset_paths = {
    "agent-dev-kit/docs/reference-adoption.md",
    "agent-dev-kit/docs/reference-adoption-matrix.md",
}

failures = []
checked = 0
real_asset_ok = 0
matrix_asset_exceptions = 0


def clean_cell(value):
    return value.strip().strip("`")


def split_row(line):
    cells = [clean_cell(part) for part in line.strip().strip("|").split("|")]
    return cells if len(cells) >= 11 else []


def evidence_items(evidence):
    for item in re.split(r"[;,]", evidence):
        item = item.strip().strip("`")
        if not item or "://" in item:
            continue
        yield item


def normalize_path(item):
    path = item.split("#", 1)[0].strip()
    return path


def is_matrix_asset_exception(capability, evidence_paths):
    if len(evidence_paths) != 1:
        return False
    if evidence_paths[0] != "agent-dev-kit/docs/reference-adoption-matrix.md":
        return False
    return any(token in capability for token in ("评估矩阵", "采纳矩阵", "adoption matrix"))


def existing_real_assets(evidence_paths):
    assets = []
    for path in evidence_paths:
        if not path.startswith("agent-dev-kit/"):
            continue
        if path in excluded_asset_paths:
            continue
        if os.path.exists(os.path.join(root, path)):
            assets.append(path)
    return assets


for matrix in matrix_paths:
    if not os.path.exists(matrix):
        failures.append(f"missing matrix: {os.path.relpath(matrix, root)}")
        continue
    rel_matrix = os.path.relpath(matrix, root)
    with open(matrix, "r", encoding="utf-8") as handle:
        for lineno, line in enumerate(handle, 1):
            if not line.startswith("| 20"):
                continue
            cells = split_row(line)
            if not cells:
                continue
            (
                _date,
                repo,
                category,
                capability,
                _value,
                _cost,
                _risk,
                decision,
                state,
                target,
                evidence,
            ) = cells[:11]
            if "agent-dev-kit" not in target:
                continue
            if state != "done" or decision not in {"adopt", "observe"}:
                continue

            checked += 1
            paths = [normalize_path(item) for item in evidence_items(evidence)]
            paths = [path for path in paths if path]
            real_assets = existing_real_assets(paths)
            if real_assets:
                real_asset_ok += 1
                continue
            if is_matrix_asset_exception(capability, paths):
                matrix_asset_exceptions += 1
                continue
            failures.append(
                f"{rel_matrix}:{lineno} repo={repo} category={category}: "
                "agent-dev-kit done row lacks a real asset evidence path"
            )

if summary_json:
    status = "fail" if failures else "pass"
    print(
        json.dumps(
            {
                "status": status,
                "checked": checked,
                "real_asset_ok": real_asset_ok,
                "matrix_asset_exceptions": matrix_asset_exceptions,
                "failures": failures,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )
    )
elif failures:
    print("[FAIL] adoption real asset checks failed", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
else:
    print(
        "[PASS] adoption real asset checks passed "
        f"checked={checked} real_asset_ok={real_asset_ok} "
        f"matrix_asset_exceptions={matrix_asset_exceptions}"
    )

if failures:
    sys.exit(1)
PY
