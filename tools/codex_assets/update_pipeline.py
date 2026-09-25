#!/usr/bin/env python3
"""Read approved reference caches and aggregate evidence; never pull or adopt."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence

from tools.control_plane.process_budget import ProcessBudgetError
from tools.control_plane.reference_pins import (
    check, git_command, paths_overlap, plan, protected_roots, resolve_source,
)

from .intake_pipeline import IntakeError, _atomic_text, _run, analyze


def _aggregate(root: Path, analyzed: Sequence[dict[str, Any]]) -> dict[str, Any]:
    names: Counter[str] = Counter()
    signals: Counter[str] = Counter()
    evidence: list[str] = []
    for result in analyzed:
        path = Path(result["report_dir"]) / "analysis.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        if (data.get("schema") != "llm-agent-intake-analysis/v2"
                or data["source"]["commit"] != result["source_commit"]
                or data["source"]["tree"] != result["source_tree"]):
            raise IntakeError("analysis identity/schema changed before aggregation")
        names.update({item["name"] for item in data["skills"]})
        signals.update(item["signal"] for item in data["pattern_signals"] if item["present"])
        evidence.append(path.relative_to(root).as_posix())
    return {
        "repeated_skill_names": {name: count for name, count in sorted(names.items()) if count >= 2},
        "repeated_pattern_signals": {name: count for name, count in sorted(signals.items()) if count >= 2},
        "evidence_files": evidence,
        "decision_boundary": "frequency is discovery evidence, not an adoption decision",
    }


def run_pipeline(
    root: Path, report_only: bool, recent_days: int,
    repository_ids: Sequence[str] | None = None, cache_root: str | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    if not isinstance(recent_days, int) or isinstance(recent_days, bool) or not 0 <= recent_days <= 3650:
        raise ValueError("recent-days must be between 0 and 3650")
    now = datetime.now(timezone.utc).replace(microsecond=0)
    report_root = (root / "reports").resolve()
    if not report_root.is_relative_to(root) or any(paths_overlap(report_root, p) for p in protected_roots(root)):
        raise IntakeError("pipeline report directory overlaps a protected root")
    stem = "pipeline-report-" + now.date().isoformat()
    result: dict[str, Any] = {
        "schema": "llm-agent-update-pipeline/v2", "generated_at": now.isoformat().replace("+00:00", "Z"),
        "status": "running", "mode": "report-only" if report_only else "analyze-cache",
        "source_observations": [], "eligible_repositories": [], "analyzed": [], "patterns": {},
        "failure": None, "network_writes": False, "auto_apply": False,
        "report_json": "reports/" + stem + ".json", "report_markdown": "reports/" + stem + ".md",
    }
    try:
        approved = check(root)["reference_repos"]
        selected = list(repository_ids) if repository_ids is not None else approved
        if not selected or len(selected) != len(set(selected)) or set(selected) - set(approved):
            raise IntakeError("repository selection must contain unique approved reference IDs")
        blocked = False
        for name in selected:
            planned = plan(root, name, cache_root)
            target = Path(planned["target"])
            if not target.exists():
                result["source_observations"].append({"repository": name, "commit": planned["commit"],
                                                       "status": "not-materialized"})
                blocked = True
                continue
            source = resolve_source(root, name, cache_root)
            timestamp = int(_run(git_command(source.repository, "show", "-s", "--format=%ct", source.commit)))
            if timestamp > int(now.timestamp()):
                raise IntakeError("approved source has a future commit timestamp")
            age = (int(now.timestamp()) - timestamp) // 86400
            result["source_observations"].append({
                "repository": name, "commit": source.commit, "tree": source.tree,
                "status": "ready" if age <= recent_days else "outside-window", "age_days": age,
            })
            if age <= recent_days:
                result["eligible_repositories"].append({"repository": name, "age_days": age})
        # Validate the complete selected population before generating analysis.
        if blocked and not report_only:
            result["status"] = "blocked"
            result["failure"] = "explicit materialization required for all selected reference IDs"
        else:
            if not report_only:
                for selected in result["eligible_repositories"]:
                    result["analyzed"].append(analyze(root, selected["repository"], "HEAD", "all", None,
                                                      cache_root=cache_root))
            result["patterns"] = _aggregate(root, result["analyzed"])
            result["status"] = "pass"
        result["analysis_coverage"] = {
            "selected": len(result["source_observations"]), "analyzed": len(result["analyzed"]),
            "partial": sum(item["analysis_status"] == "static-partial" for item in result["analyzed"]),
            "note": "report-only PASS means observation completed, not source analysis or qualification",
        }
    except (RuntimeError, OSError, ValueError) as exc:
        result["status"] = "fail"
        result["failure"] = str(exc)
        result["reason"] = "budget-exceeded" if isinstance(exc, ProcessBudgetError) else "invalid-source"
    payload = json.dumps(result, ensure_ascii=False, indent=2)
    _atomic_text(root / result["report_json"], payload + "\n")
    _atomic_text(root / result["report_markdown"],
                 "# Reference cache observation\n\nNo sync, hook execution, grading or automatic adoption.\n\n"
                 "```json\n" + payload.replace("```", "\\u0060\\u0060\\u0060") + "\n```\n")
    return result


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Observe or analyze approved, already-materialized reference caches")
    parser.add_argument("--root", default=".")
    parser.add_argument("--repository", action="append", dest="repository_ids")
    parser.add_argument("--cache-root")
    parser.add_argument("--report-only", action="store_true")
    parser.add_argument("--recent-days", type=int, default=30)
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = run_pipeline(Path(args.root), args.report_only, args.recent_days, args.repository_ids, args.cache_root)
    except (RuntimeError, OSError, ValueError) as exc:
        result = {"schema": "llm-agent-update-pipeline/v2", "status": "fail", "failure": str(exc)}
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    else:
        print("[{}] {}".format(result["status"].upper(), result.get("failure") or result["report_markdown"]))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
