"""Deterministic maintainability growth budgets for llm_agent and agent-dev-kit."""

from __future__ import annotations

import argparse
import fnmatch
import json
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Mapping, Sequence, Tuple


ALLOWED_METRICS = {"file_count", "max_lines"}


class BudgetError(ValueError):
    """Raised when the budget contract is invalid."""


def _relative(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def _contained_path(root: Path, raw_path: str) -> Path:
    candidate = (root / raw_path).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise BudgetError("budget scope escapes root: {0}".format(raw_path)) from exc
    return candidate


def _matches(path: Path, root: Path, patterns: Sequence[str]) -> bool:
    relative = _relative(root, path)
    return any(
        fnmatch.fnmatch(relative, pattern) or fnmatch.fnmatch(path.name, pattern)
        for pattern in patterns
    )


def _excluded(path: Path, root: Path, prefixes: Sequence[str]) -> bool:
    relative = _relative(root, path)
    return any(relative == prefix or relative.startswith(prefix.rstrip("/") + "/") for prefix in prefixes)


def _iter_files(
    root: Path,
    scope_paths: Sequence[str],
    include_patterns: Sequence[str],
    exclude_prefixes: Sequence[str],
) -> Iterable[Path]:
    seen = set()
    for raw_scope in scope_paths:
        scope = _contained_path(root, raw_scope)
        if not scope.exists():
            raise BudgetError("budget scope does not exist: {0}".format(raw_scope))
        candidates = [scope] if scope.is_file() else scope.rglob("*")
        for candidate in candidates:
            if not candidate.is_file() or candidate.is_symlink():
                continue
            if candidate in seen or _excluded(candidate, root, exclude_prefixes):
                continue
            if _matches(candidate, root, include_patterns):
                seen.add(candidate)
                yield candidate


def _line_count(path: Path) -> int:
    with path.open("r", encoding="utf-8", errors="replace") as stream:
        return sum(1 for _ in stream)


def _validate_budget(raw: Mapping[str, object], index: int) -> Dict[str, object]:
    context = "maintainability budget #{0}".format(index + 1)
    required = {
        "id",
        "metric",
        "scope_paths",
        "include_patterns",
        "baseline",
        "warning_limit",
        "hard_limit",
        "owner",
        "next_action",
    }
    missing = sorted(required - set(raw))
    if missing:
        raise BudgetError("{0} missing fields: {1}".format(context, ", ".join(missing)))

    budget_id = raw["id"]
    metric = raw["metric"]
    scope_paths = raw["scope_paths"]
    include_patterns = raw["include_patterns"]
    exclude_prefixes = raw.get("exclude_prefixes", [])
    owner = raw["owner"]
    next_action = raw["next_action"]
    if not isinstance(budget_id, str) or not budget_id.strip():
        raise BudgetError("{0} has invalid id".format(context))
    if metric not in ALLOWED_METRICS:
        raise BudgetError("{0} has unsupported metric: {1}".format(context, metric))
    for field, value in (
        ("scope_paths", scope_paths),
        ("include_patterns", include_patterns),
        ("exclude_prefixes", exclude_prefixes),
    ):
        if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
            raise BudgetError("{0} has invalid {1}".format(context, field))
    if not scope_paths or not include_patterns:
        raise BudgetError("{0} requires non-empty scope_paths and include_patterns".format(context))
    for field in ("baseline", "warning_limit", "hard_limit"):
        if not isinstance(raw[field], int) or raw[field] < 0:
            raise BudgetError("{0} has invalid {1}".format(context, field))
    if not raw["baseline"] <= raw["warning_limit"] < raw["hard_limit"]:
        raise BudgetError("{0} requires baseline <= warning_limit < hard_limit".format(context))
    if not isinstance(owner, str) or not owner.strip():
        raise BudgetError("{0} has invalid owner".format(context))
    if not isinstance(next_action, str) or not next_action.strip():
        raise BudgetError("{0} has invalid next_action".format(context))
    return dict(raw)


def _load_contract(config_path: Path) -> Tuple[Dict[str, object], List[Dict[str, object]]]:
    try:
        raw = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BudgetError("cannot load maintainability contract: {0}".format(exc)) from exc
    if raw.get("schema_version") != 2:
        raise BudgetError("maintainability contract requires backlog schema_version=2")
    contract = raw.get("maintainability_budgets")
    if not isinstance(contract, dict):
        raise BudgetError("backlog missing maintainability_budgets")
    if contract.get("schema") != "llm-agent-maintainability-budgets/v1":
        raise BudgetError("unsupported maintainability budget schema")
    budgets = contract.get("budgets")
    if not isinstance(budgets, list) or not budgets:
        raise BudgetError("maintainability_budgets.budgets must be a non-empty list")
    validated = [_validate_budget(item, index) for index, item in enumerate(budgets)]
    ids = [item["id"] for item in validated]
    if len(ids) != len(set(ids)):
        raise BudgetError("maintainability budget IDs must be unique")
    return contract, validated


def _measure(root: Path, budget: Mapping[str, object]) -> Dict[str, object]:
    files = sorted(
        _iter_files(
            root,
            budget["scope_paths"],
            budget["include_patterns"],
            budget.get("exclude_prefixes", []),
        ),
        key=lambda item: _relative(root, item),
    )
    metric = budget["metric"]
    if metric == "file_count":
        observed = len(files)
        hotspots = [{"path": _relative(root, path), "value": 1} for path in files[:5]]
    else:
        measured = sorted(
            ((_line_count(path), _relative(root, path)) for path in files),
            key=lambda item: (-item[0], item[1]),
        )
        observed = measured[0][0] if measured else 0
        hotspots = [{"path": path, "value": value} for value, path in measured[:5]]

    if observed > budget["hard_limit"]:
        status = "fail"
    elif observed > budget["warning_limit"]:
        status = "needs-review"
    else:
        status = "pass"
    return {
        "id": budget["id"],
        "metric": metric,
        "status": status,
        "observed": observed,
        "baseline": budget["baseline"],
        "drift": observed - budget["baseline"],
        "warning_limit": budget["warning_limit"],
        "hard_limit": budget["hard_limit"],
        "files_scanned": len(files),
        "owner": budget["owner"],
        "next_action": budget["next_action"],
        "hotspots": hotspots,
    }


def evaluate(root: Path, config_path: Path, strict: bool) -> Dict[str, object]:
    root = root.resolve()
    contract, budgets = _load_contract(config_path)
    results = [_measure(root, budget) for budget in budgets]
    failures = [item["id"] for item in results if item["status"] == "fail"]
    warnings = [item["id"] for item in results if item["status"] == "needs-review"]
    if failures or (strict and warnings):
        status = "fail"
    elif warnings:
        status = "needs-review"
    else:
        status = "pass"
    return {
        "schema": "llm-agent-maintainability-budget-report/v1",
        "status": status,
        "strict": strict,
        "baseline_date": contract.get("baseline_date"),
        "root": str(root),
        "budget_count": len(results),
        "failures": failures,
        "warnings": warnings,
        "budgets": results,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check repository maintainability growth budgets.")
    parser.add_argument("--root", default=".", help="Workspace root.")
    parser.add_argument(
        "--config",
        help="Budget contract; defaults to manifests/comprehensive_optimization_backlog.json.",
    )
    parser.add_argument("--strict", action="store_true", help="Treat warning-limit drift as failure.")
    parser.add_argument("--summary-json", action="store_true", help="Emit compact JSON.")
    return parser


def main(argv: Sequence[str] = ()) -> int:
    args = _parser().parse_args(list(argv) if argv else None)
    root = Path(args.root).resolve()
    config_path = Path(args.config).resolve() if args.config else root / "manifests/comprehensive_optimization_backlog.json"
    try:
        report = evaluate(root, config_path, args.strict)
    except BudgetError as exc:
        print("[FAIL] {0}".format(exc), file=sys.stderr)
        return 2

    if args.summary_json:
        print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
    else:
        for item in report["budgets"]:
            print(
                "[{0}] {1}: observed={2} baseline={3} warning={4} hard={5}".format(
                    item["status"].upper(),
                    item["id"],
                    item["observed"],
                    item["baseline"],
                    item["warning_limit"],
                    item["hard_limit"],
                )
            )
        print(
            "[SUMMARY] status={0} budgets={1} warnings={2} failures={3}".format(
                report["status"],
                report["budget_count"],
                len(report["warnings"]),
                len(report["failures"]),
            )
        )
    return 1 if report["status"] == "fail" else 0


if __name__ == "__main__":
    raise SystemExit(main())
