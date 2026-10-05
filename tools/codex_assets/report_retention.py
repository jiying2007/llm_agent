"""Read-only report retention planning with dependency and content bindings."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlsplit

SCOPES = ("docs", "scripts", "tests", "tools", "fixtures", "manifests", "subrepos", "reports", ".github")
SCAN_FILE_BYTES = 256 * 1024
SCAN_TOTAL_BYTES = 32 * 1024 * 1024


def plan(root: Path, days: int = 30, now: datetime | None = None) -> dict[str, Any]:
    if isinstance(days, bool) or not isinstance(days, int) or not 0 <= days <= 3650:
        raise ValueError("days must be between 0 and 3650")
    root = root.resolve()
    reports = root / "reports"
    if reports.is_symlink():
        raise ValueError("report directory must not be a symlink")
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError("retention time must include a timezone")
    candidates = []
    if reports.is_dir():
        for visited, path in enumerate(reports.iterdir(), 1):
            if visited > 10000:
                raise ValueError("report directory enumeration exceeds budget")
            if path.suffix == ".md":
                candidates.append(path)
    if len(candidates) > 1000:
        raise ValueError("report candidate population exceeds budget")
    candidates.sort()
    references: dict[str, list[str]] = {p.relative_to(root).as_posix(): [] for p in candidates}
    scanned = total_bytes = 0
    incomplete = False
    roots = [root / scope for scope in SCOPES] + [root / "README.md", root / "AGENTS.md"]
    visited = 0
    exhausted = False
    for base in roots:
        if base.is_symlink():
            incomplete = True
            continue
        paths = base.rglob("*") if base.is_dir() else [base] if base.is_file() else []
        for path in paths:
            visited += 1
            if visited > 10000 or scanned >= 5000:
                incomplete = exhausted = True
                break
            if path.is_symlink():
                incomplete = True
                continue
            if not path.is_file() or path.suffix not in {".md", ".json", ".jsonl", ".py", ".sh", ".csv", ".tsv", ".yml", ".yaml"}:
                continue
            if path.stat().st_size > SCAN_FILE_BYTES:
                incomplete = True
                continue
            with path.open("rb") as stream:
                raw = stream.read(SCAN_FILE_BYTES + 1)
            if len(raw) > SCAN_FILE_BYTES:
                incomplete = True
                continue
            total_bytes += len(raw)
            if total_bytes > SCAN_TOTAL_BYTES:
                incomplete = exhausted = True
                break
            text = raw.decode("utf-8", errors="replace")
            relative = path.relative_to(root).as_posix()
            scanned += 1
            for ref in references:
                if relative != ref and ref in text:
                    references[ref].append(relative)
            if path.suffix == ".md":
                for link in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
                    raw_target = link.strip().strip("<>").split(" ", 1)[0]
                    parsed = urlsplit(raw_target)
                    if parsed.scheme or parsed.netloc or not parsed.path:
                        continue
                    target = (path.parent / unquote(parsed.path)).resolve()
                    try:
                        ref = target.relative_to(root).as_posix()
                    except ValueError:
                        incomplete = True
                        continue
                    if ref in references and relative != ref:
                        references[ref].append(relative)
        if exhausted:
            break
    items = []
    for path in candidates:
        ref = path.relative_to(root).as_posix()
        reasons = []
        age = (now.timestamp() - path.lstat().st_mtime) / 86400
        if path.name in {"README.md", "current-status.md"} or path.name.endswith(".template.md"):
            reasons.append("protected-entry-or-template")
        if path.is_symlink():
            reasons.append("symlink")
        if age < days:
            reasons.append("inside-retention-window")
        if references[ref]:
            reasons.append("has-evidence-consumers")
        if incomplete:
            reasons.append("dependency-scan-incomplete")
        digest = ""
        if not path.is_symlink() and path.is_file() and path.stat().st_size <= SCAN_FILE_BYTES:
            with path.open("rb") as stream:
                payload = stream.read(SCAN_FILE_BYTES + 1)
            if len(payload) > SCAN_FILE_BYTES:
                reasons.append("content-not-bound")
            else:
                digest = hashlib.sha256(payload).hexdigest()
        else:
            reasons.append("content-not-bound")
        items.append({"path": ref, "sha256": digest, "age_days": round(age, 2),
                      "eligible_for_review": not reasons, "blocking_reasons": reasons,
                      "referenced_by": sorted(set(references[ref]))})
    return {"schema": "llm-agent-report-retention-plan/v1", "status": "planned",
            "mode": "dry-run", "owner_review_required": True, "apply_supported": False,
            "files_moved": 0, "scanned_files": scanned, "scan_incomplete": incomplete,
            "candidates": items,
            "limitations": ["text dependency discovery is conservative and does not authorize archive",
                            "review must bind supersession, owner decision and rollback before moving evidence"]}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Plan report retention without deleting or moving evidence")
    parser.add_argument("root", nargs="?", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(argv)
    if args.apply:
        print(json.dumps({"status": "blocked", "reason": "reviewed-supersession-and-owner-decision-required",
                          "files_moved": 0}))
        return 2
    try:
        value = plan(Path(args.root), args.days)
    except (ValueError, OSError) as exc:
        print(json.dumps({"status": "fail", "error": str(exc), "files_moved": 0}))
        return 2
    print(json.dumps(value, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
