from __future__ import annotations

import argparse
import datetime as dt
import json
import shlex
import sys
from pathlib import Path
from typing import Any

SCHEMA = "llm-agent-active-contract-check/v1"


def _date(value: Any, field: str) -> dt.date:
    if not isinstance(value, str):
        raise ValueError(f"{field} must be YYYY-MM-DD")
    try:
        return dt.date.fromisoformat(value)
    except ValueError as exc:
        raise ValueError(f"{field} must be YYYY-MM-DD") from exc


def _current_report(root: Path) -> str:
    registry = json.loads((root / "manifests" / "report_registry.json").read_text(encoding="utf-8"))
    current = [item for item in registry.get("reports", []) if item.get("status") == "current"]
    if len(current) != 1:
        raise ValueError(f"report registry requires exactly one current report, got {len(current)}")
    path = current[0].get("path")
    if not isinstance(path, str) or not path:
        raise ValueError("current report path is missing")
    return path


def _command_paths(command: str) -> list[str]:
    try:
        tokens = shlex.split(command)
    except ValueError as exc:
        raise ValueError(f"invalid verification command: {command}: {exc}") from exc
    paths: list[str] = []
    for token in tokens:
        token = token.rstrip(";,)")
        if token.startswith("~/") or "<" in token or ">" in token:
            continue
        if token.startswith(("scripts/", "tests/", "tools/", "agent-dev-kit/")):
            paths.append(token)
    return paths


def validate(root: Path, as_of: dt.date) -> dict[str, Any]:
    root = root.resolve()
    backlog_path = root / "manifests" / "comprehensive_optimization_backlog.json"
    backlog = json.loads(backlog_path.read_text(encoding="utf-8"))
    interface = json.loads((root / "manifests" / "adk_interface.lock.json").read_text(encoding="utf-8"))
    failures: list[str] = []
    adk_checkout_available = (root / "agent-dev-kit" / "manifest.json").is_file()

    try:
        last_updated = _date(backlog.get("last_updated"), "last_updated")
        review_after = _date(backlog.get("review_after"), "review_after")
        if review_after < as_of:
            failures.append(
                f"optimization backlog review expired: review_after={review_after.isoformat()} as_of={as_of.isoformat()}"
            )
        if last_updated > review_after:
            failures.append("optimization backlog last_updated is later than review_after")
    except ValueError as exc:
        failures.append(str(exc))

    try:
        current_report = _current_report(root)
        if backlog.get("source_report") != current_report:
            failures.append(
                f"optimization backlog source_report is not current: {backlog.get('source_report')} != {current_report}"
            )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        failures.append(str(exc))

    deprecated = interface.get("deprecated_surfaces", [])
    if not isinstance(deprecated, list) or not all(isinstance(item, str) and item for item in deprecated):
        failures.append("interface deprecated_surfaces must be a non-empty string list")
        deprecated = []

    active_texts = {
        "README.md": (root / "README.md").read_text(encoding="utf-8"),
        "manifests/comprehensive_optimization_backlog.json": backlog_path.read_text(encoding="utf-8"),
    }
    for label, text in active_texts.items():
        for token in deprecated:
            if token in text:
                failures.append(f"active surface {label} references deprecated ADK surface: {token}")

    for item in backlog.get("items", []):
        if not isinstance(item, dict):
            failures.append("optimization backlog contains a non-object item")
            continue
        item_id = str(item.get("id") or "<missing>")
        if item.get("implementation_status") == "blocked" and not str(item.get("blocking_condition") or "").strip():
            failures.append(f"{item_id} is blocked without blocking_condition")
        verification = item.get("verification")
        if not isinstance(verification, list) or not verification:
            failures.append(f"{item_id} requires verification commands")
            continue
        for command in verification:
            if not isinstance(command, str) or not command.startswith("rtk "):
                failures.append(f"{item_id} verification must start with rtk: {command!r}")
                continue
            for path_text in _command_paths(command):
                path = root / path_text
                if path_text.startswith("agent-dev-kit/") and not adk_checkout_available:
                    # A shallow root checkout can materialize the gitlink path as an
                    # empty directory. Treat ADK as available only when its canonical
                    # manifest is present. Deprecated cross-repo paths are still
                    # rejected above from the pinned interface lock.
                    continue
                if not path.exists():
                    failures.append(f"{item_id} verification references missing path: {path_text}")

    return {
        "schema": SCHEMA,
        "status": "pass" if not failures else "fail",
        "as_of": as_of.isoformat(),
        "backlog": str(backlog_path.relative_to(root)),
        "source_report": backlog.get("source_report"),
        "item_count": len(backlog.get("items", [])) if isinstance(backlog.get("items"), list) else 0,
        "adk_checkout_available": adk_checkout_available,
        "failures": failures,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate freshness and executable references for active governance contracts")
    parser.add_argument("--root", default=".")
    parser.add_argument("--as-of", help="Reproducible YYYY-MM-DD validation clock; defaults to today")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        as_of = dt.date.fromisoformat(args.as_of) if args.as_of else dt.date.today()
        result = validate(Path(args.root), as_of)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        result = {"schema": SCHEMA, "status": "fail", "failures": [str(exc)]}
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        if result["status"] == "pass":
            print("[PASS] active governance contracts are fresh and executable")
        else:
            for failure in result.get("failures", []):
                print(f"[FAIL] {failure}", file=sys.stderr)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
