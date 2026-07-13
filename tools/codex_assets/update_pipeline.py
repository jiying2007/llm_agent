#!/usr/bin/env python3
"""Fail-fast subrepository update and evidence aggregation pipeline."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple

from .intake_pipeline import IntakeError, analyze


class PipelineError(RuntimeError):
    """Fail-fast pipeline stage error."""


def _atomic_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, str(path))
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def _atomic_json(path: Path, value: Mapping[str, Any]) -> None:
    _atomic_text(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def _command(root: Path, name: str, command: Sequence[str]) -> Dict[str, Any]:
    started = datetime.now(timezone.utc)
    completed = subprocess.run(
        list(command),
        cwd=str(root),
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    elapsed = (datetime.now(timezone.utc) - started).total_seconds()
    result = {
        "name": name,
        "status": "pass" if completed.returncode == 0 else "fail",
        "exit_code": completed.returncode,
        "elapsed_seconds": round(elapsed, 3),
        "stdout": completed.stdout.replace(str(root), "."),
        "stderr": completed.stderr.replace(str(root), "."),
    }
    return result


def _append_stage(result: Dict[str, Any], root: Path, name: str, command: Sequence[str]) -> Dict[str, Any]:
    stage = _command(root, name, command)
    result["stages"].append(stage)
    if stage["status"] != "pass":
        detail = stage["stderr"].strip() or stage["stdout"].strip()
        raise PipelineError("{} failed with exit {}: {}".format(name, stage["exit_code"], detail[-500:]))
    return stage


def _registry_rows(root: Path) -> List[Dict[str, str]]:
    path = root / "subrepos" / "registry.csv"
    with path.open(newline="", encoding="utf-8") as source:
        rows = list(csv.DictReader(source))
    required = {"repo", "enabled", "status", "grade"}
    if not rows or not required.issubset(rows[0]):
        raise PipelineError("registry.csv is empty or missing required columns: {}".format(sorted(required)))
    return rows


def _dynamic_grades(output: str) -> Dict[str, str]:
    ansi = re.compile(r"\x1b\[[0-9;]*m")
    grades: Dict[str, str] = {}
    for raw in output.splitlines():
        line = ansi.sub("", raw)
        match = re.match(r"^\[([SABCD])\]\s+(\S+)", line)
        if match:
            grades[match.group(2)] = match.group(1)
    if not grades:
        raise PipelineError("quality-grade output did not contain parseable repository grades")
    return grades


def _recent_reference_rows(
    root: Path, days: int, dynamic_grades: Mapping[str, str]
) -> Tuple[List[Dict[str, str]], List[Dict[str, str]]]:
    now_epoch = int(datetime.now(timezone.utc).timestamp())
    selected: List[Dict[str, str]] = []
    drifts: List[Dict[str, str]] = []
    for row in _registry_rows(root):
        if row["repo"] == "agent-dev-kit":
            continue
        if row["enabled"].strip().lower() not in ("yes", "true", "1"):
            continue
        if row["status"].strip().lower() != "active":
            continue
        registry_grade = row["grade"].strip().upper()
        dynamic_grade = dynamic_grades.get(row["repo"])
        if dynamic_grade is None:
            raise PipelineError("dynamic grade missing for enabled active repository: {}".format(row["repo"]))
        if registry_grade != dynamic_grade:
            drifts.append(
                {"repository": row["repo"], "registry_grade": registry_grade, "dynamic_grade": dynamic_grade}
            )
        if registry_grade not in ("S", "A") or dynamic_grade not in ("S", "A"):
            continue
        repository = root / row["repo"]
        if not repository.is_dir():
            raise PipelineError("registered active repository missing: {}".format(row["repo"]))
        completed = subprocess.run(
            ["git", "-C", str(repository), "show", "-s", "--format=%ct", "HEAD"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if completed.returncode != 0:
            raise PipelineError("cannot read latest commit for {}".format(row["repo"]))
        age_days = max(0, (now_epoch - int(completed.stdout.strip())) // 86400)
        if age_days <= days:
            selected.append(dict(row, age_days=str(age_days)))
    return selected, drifts


def _aggregate_patterns(root: Path, analyzed: Sequence[Mapping[str, Any]]) -> Dict[str, Any]:
    names: Counter[str] = Counter()
    signals: Counter[str] = Counter()
    evidence_files: List[str] = []
    for result in analyzed:
        report_dir = Path(str(result["report_dir"]))
        analysis_path = (report_dir if report_dir.is_absolute() else root / report_dir) / "analysis.json"
        data = json.loads(analysis_path.read_text(encoding="utf-8"))
        evidence_files.append(analysis_path.relative_to(root).as_posix())
        names.update({str(item["name"]) for item in data.get("skills", [])})
        signals.update(str(item["signal"]) for item in data.get("pattern_signals", []) if item.get("present"))
    return {
        "repeated_skill_names": {name: count for name, count in sorted(names.items()) if count >= 2},
        "repeated_pattern_signals": {name: count for name, count in sorted(signals.items()) if count >= 2},
        "evidence_files": evidence_files,
        "decision_boundary": "pattern frequency is discovery evidence, not an adoption decision",
    }


def _stage_excerpt(stage: Mapping[str, Any], limit: int = 30) -> List[str]:
    output = str(stage.get("stdout", "")).strip().splitlines()
    return output[-limit:]


def _render_report(result: Mapping[str, Any]) -> str:
    lines = [
        "# 子仓更新流水线报告",
        "",
        "- generated_at: {}".format(result["generated_at"]),
        "- status: {}".format(result["status"]),
        "- mode: {}".format(result["mode"]),
        "- failure: {}".format(result.get("failure") or "-"),
        "",
        "## 阶段结果",
        "",
        "| Stage | Status | Exit | Seconds |",
        "|---|---|---:|---:|",
    ]
    for stage in result["stages"]:
        lines.append(
            "| {} | {} | {} | {} |".format(
                stage["name"], stage["status"], stage["exit_code"], stage["elapsed_seconds"]
            )
        )
    lines.extend(["", "## 分析结果", ""])
    eligible = result.get("eligible_repositories", [])
    lines.append("- eligible_repositories: {}".format(json.dumps(eligible, ensure_ascii=False)))
    if result["analyzed"]:
        for item in result["analyzed"]:
            lines.append(
                "- `{}` @ `{}`: static evidence complete, decision review required".format(
                    item["repository"], item["source_commit"][:12]
                )
            )
    else:
        lines.append("- 本轮未生成新分析；可能为 report-only、显式跳过或无近期 S/A 级参考源。")
    patterns = result.get("patterns", {})
    lines.extend(
        [
            "",
            "## 跨仓模式",
            "",
            "- repeated_skill_names: {}".format(json.dumps(patterns.get("repeated_skill_names", {}), ensure_ascii=False)),
            "- repeated_pattern_signals: {}".format(
                json.dumps(patterns.get("repeated_pattern_signals", {}), ensure_ascii=False)
            ),
            "- boundary: {}".format(patterns.get("decision_boundary", "not evaluated")),
            "- grade_drift: {}".format(json.dumps(result.get("grade_drift", []), ensure_ascii=False)),
            "",
            "## 关键输出摘要",
            "",
        ]
    )
    for stage in result["stages"]:
        excerpt = _stage_excerpt(stage)
        if not excerpt:
            continue
        lines.extend(["### {}".format(stage["name"]), "", "```text"])
        lines.extend(excerpt)
        lines.extend(["```", ""])
    lines.extend(
        [
            "## 下一门禁",
            "",
            "任何 `decision-candidate.json` 都必须经过语义、重复、架构、许可证、安全和运行效果复核，才能更新 adoption matrix 或修改 agent-dev-kit。",
            "",
        ]
    )
    return "\n".join(lines)


def run_pipeline(root: Path, skip_sync: bool, skip_analyze: bool, report_only: bool, recent_days: int) -> Dict[str, Any]:
    root = root.resolve()
    if report_only:
        skip_sync = True
        skip_analyze = True
    now = datetime.now(timezone.utc).replace(microsecond=0)
    result: Dict[str, Any] = {
        "schema": "llm-agent-update-pipeline/v1",
        "generated_at": now.isoformat().replace("+00:00", "Z"),
        "status": "running",
        "mode": "report-only" if report_only else "active",
        "stages": [],
        "analyzed": [],
        "eligible_repositories": [],
        "patterns": {},
        "grade_drift": [],
        "failure": None,
    }
    report_stem = "pipeline-report-{}".format(now.date().isoformat())
    json_path = root / "reports" / (report_stem + ".json")
    markdown_path = root / "reports" / (report_stem + ".md")
    result["report_json"] = json_path.relative_to(root).as_posix()
    result["report_markdown"] = markdown_path.relative_to(root).as_posix()
    try:
        if not skip_sync:
            _append_stage(result, root, "sync", ["bash", "scripts/sync-subrepos.sh"])
        _append_stage(result, root, "diff-scan", ["bash", "scripts/diff-scan.sh"])
        quality_stage = _append_stage(result, root, "quality-grade", ["bash", "scripts/check-repo-quality.sh"])
        grades = _dynamic_grades(quality_stage["stdout"])
        selected, grade_drift = _recent_reference_rows(root, recent_days, grades)
        result["eligible_repositories"] = [
            {"repository": row["repo"], "age_days": int(row["age_days"])} for row in selected
        ]
        result["grade_drift"] = grade_drift
        if not skip_analyze:
            for row in selected:
                item = analyze(root, row["repo"], "HEAD", "all", None)
                item["age_days"] = int(row["age_days"])
                result["analyzed"].append(item)
        result["patterns"] = _aggregate_patterns(root, result["analyzed"])
        result["status"] = "pass"
    except (PipelineError, IntakeError, OSError, ValueError, json.JSONDecodeError) as exc:
        result["status"] = "fail"
        result["failure"] = str(exc)
    _atomic_json(json_path, result)
    _atomic_text(markdown_path, _render_report(result))
    return result


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Run the llm_agent reference update pipeline")
    parser.add_argument("--root", default=os.environ.get("LLM_AGENT_ROOT", "."))
    parser.add_argument("--skip-sync", action="store_true")
    parser.add_argument("--skip-analyze", action="store_true")
    parser.add_argument("--report-only", action="store_true")
    parser.add_argument("--recent-days", type=int, default=30)
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    if args.recent_days < 0 or args.recent_days > 3650:
        parser.error("--recent-days must be between 0 and 3650")
    result = run_pipeline(Path(args.root), args.skip_sync, args.skip_analyze, args.report_only, args.recent_days)
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    else:
        print("[{}] report: {}".format(result["status"].upper(), result["report_markdown"]))
        if result.get("failure"):
            print("[FAIL] {}".format(result["failure"]), file=sys.stderr)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
