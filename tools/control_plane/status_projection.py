from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


def _git(root: Path, *args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout.strip()


def _kv(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def _md_fields(path: Path) -> dict[str, str]:
    fields: dict[str, str] = {}
    if not path.exists():
        return fields
    pattern = re.compile(r"^- ([A-Za-z0-9_]+):\s*(.+)$")
    for line in path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return fields


def _commit_known(root: Path, commit: str) -> bool:
    if not commit:
        return False
    return (
        subprocess.run(
            ["git", "-C", str(root), "cat-file", "-e", f"{commit}^{{commit}}"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def _ancestry(root: Path, ancestor: str, descendant: str) -> bool | None:
    if not _commit_known(root, ancestor):
        return None
    return (
        subprocess.run(
            ["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def project(root: Path, today: dt.date) -> dict[str, Any]:
    root = root.resolve()
    head = _git(root, "rev-parse", "HEAD")
    index = _git(root, "ls-files", "-s", "agent-dev-kit").split()
    if len(index) < 2 or index[0] != "160000":
        raise RuntimeError("agent-dev-kit is not tracked as a gitlink")
    gitlink = index[1]
    lock = _kv(root / "adk.lock")
    lock_commit = lock.get("agent-dev-kit.commit", "")
    lock_schema = lock.get("schema", "")
    pin_consistent = lock_schema == "llm-agent-adk-lock/v2" and bool(lock_commit) and gitlink == lock_commit

    baseline_path = root / "reports" / "current-status.md"
    baseline = _md_fields(baseline_path)
    baseline_commit = baseline.get("root_product_commit", "")
    baseline_date_text = baseline.get("last_verified_at", "")
    baseline_age_days: int | None = None
    baseline_date_valid = False
    if baseline_date_text:
        try:
            baseline_date = dt.date.fromisoformat(baseline_date_text)
            baseline_age_days = (today - baseline_date).days
            baseline_date_valid = baseline_age_days >= 0
        except ValueError:
            pass

    baseline_ancestor = _ancestry(root, baseline_commit, head) if baseline_commit else None
    if baseline_ancestor is True:
        relationship = "ancestor"
    elif baseline_ancestor is False:
        relationship = "not-ancestor"
    else:
        relationship = "history-unavailable"

    baseline_fresh = (
        baseline_ancestor is True
        and baseline_date_valid
        and baseline_age_days is not None
        and baseline_age_days <= 7
        and baseline_commit == head
    )
    evidence_state = "fresh" if baseline_fresh else "stale-or-historical"

    baseline_integrity = bool(baseline_commit) and baseline_date_valid and baseline_ancestor is not False
    status = "pass" if pin_consistent and baseline_integrity else "fail"

    return {
        "schema": "llm-agent-status-projection/v2",
        "status": status,
        "source": {
            "head": head,
            "adk_gitlink": gitlink,
            "adk_lock_commit": lock_commit,
            "adk_lock_schema": lock_schema,
            "pin_consistent": pin_consistent,
        },
        "last_verified_baseline": {
            "path": "reports/current-status.md",
            "root_product_commit": baseline_commit or None,
            "last_verified_at": baseline_date_text or None,
            "age_days": baseline_age_days,
            "history_available": baseline_ancestor is not None,
            "relationship_to_head": relationship,
            "is_ancestor": baseline_ancestor,
            "fresh_for_current_head": baseline_fresh,
        },
        "current_evidence_state": evidence_state,
        "release_authorized": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Project current source identity without treating historical reports as current SSOT")
    parser.add_argument("--root", default=".")
    parser.add_argument("--today", help="Override YYYY-MM-DD for deterministic tests")
    parser.add_argument("--require-fresh", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        today = dt.date.fromisoformat(args.today) if args.today else dt.date.today()
        result = project(Path(args.root), today)
        if args.require_fresh and not result["last_verified_baseline"]["fresh_for_current_head"]:
            result["status"] = "fail"
            relationship = result["last_verified_baseline"]["relationship_to_head"]
            result["error"] = f"current HEAD lacks a fresh last-verified baseline ({relationship})"
    except (OSError, RuntimeError, ValueError) as exc:
        result = {"schema": "llm-agent-status-projection/v2", "status": "fail", "error": str(exc)}

    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result.get("status") == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
