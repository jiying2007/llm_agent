#!/usr/bin/env python3
"""Evidence-first reference repository analysis and decision packaging."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


REPO_NAME = re.compile(r"^[A-Za-z0-9._-]+$")
TEXT_SUFFIXES = {
    ".c",
    ".cc",
    ".cpp",
    ".h",
    ".hpp",
    ".js",
    ".json",
    ".md",
    ".py",
    ".sh",
    ".toml",
    ".ts",
    ".tsx",
    ".yaml",
    ".yml",
}
SCRIPT_SUFFIXES = {".py", ".sh", ".js", ".ts"}
PROMPT_NAME_MARKERS = ("prompt", "system", "instruction", "skill.md", "agents.md")
GUARDRAIL_MARKERS = ("must not", "forbidden", "deny", "approval", "禁止", "不得", "审批")
MAX_ARCHIVE_BYTES = 512 * 1024 * 1024
MAX_ARCHIVE_MEMBERS = 50000


class IntakeError(RuntimeError):
    """Expected user-facing intake failure."""


def _run(command: Sequence[str], cwd: Optional[Path] = None) -> str:
    completed = subprocess.run(
        list(command),
        cwd=str(cwd) if cwd else None,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise IntakeError(
            "command failed ({}): {}".format(" ".join(command), completed.stderr.strip()[-500:])
        )
    return completed.stdout.strip()


def _ensure_within(path: Path, root: Path, label: str) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise IntakeError("{} escapes workspace: {}".format(label, path)) from exc
    return resolved


def _atomic_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, str(path))
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def _atomic_json(path: Path, value: Mapping[str, Any]) -> None:
    _atomic_text(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def _portable_path(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def _safe_extract_archive(repository: Path, commit: str, destination: Path) -> int:
    skipped_links = 0
    with tempfile.TemporaryFile() as archive_stream:
        completed = subprocess.run(
            ["git", "-C", str(repository), "archive", "--format=tar", commit],
            check=False,
            stdout=archive_stream,
            stderr=subprocess.PIPE,
        )
        if completed.returncode != 0:
            raise IntakeError("git archive failed: {}".format(completed.stderr.decode(errors="replace")[-500:]))
        archive_size = archive_stream.tell()
        if archive_size > MAX_ARCHIVE_BYTES:
            raise IntakeError("repository archive exceeds {} bytes".format(MAX_ARCHIVE_BYTES))
        archive_stream.seek(0)
        with tarfile.open(fileobj=archive_stream, mode="r:") as archive:
            for member_count, member in enumerate(archive, start=1):
                if member_count > MAX_ARCHIVE_MEMBERS:
                    raise IntakeError("repository archive exceeds {} members".format(MAX_ARCHIVE_MEMBERS))
                pure = PurePosixPath(member.name)
                if pure.is_absolute() or ".." in pure.parts:
                    raise IntakeError("unsafe archive member: {}".format(member.name))
                _ensure_within(destination / member.name, destination, "archive member")
                if member.issym() or member.islnk():
                    skipped_links += 1
                    continue
                if member.ischr() or member.isblk() or member.isfifo():
                    raise IntakeError("unsupported special archive member: {}".format(member.name))
                archive.extract(member, path=str(destination))
    return skipped_links


def _read_text(path: Path) -> str:
    if path.stat().st_size > 1024 * 1024 or path.suffix.lower() not in TEXT_SUFFIXES:
        return ""
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return ""


def _frontmatter_value(content: str, key: str) -> Optional[str]:
    if not content.startswith("---\n"):
        return None
    end = content.find("\n---", 4)
    if end < 0:
        return None
    pattern = re.compile(r"^{}:\s*(.+?)\s*$".format(re.escape(key)), re.MULTILINE)
    match = pattern.search(content[4:end])
    if not match:
        return None
    return match.group(1).strip().strip("'\"")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _inventory(snapshot: Path) -> Tuple[List[Path], Dict[str, Any]]:
    files = sorted(path for path in snapshot.rglob("*") if path.is_file() and not path.is_symlink())
    markdown = [path for path in files if path.suffix.lower() == ".md"]
    skills = [path for path in files if path.name == "SKILL.md"]
    agents = [path for path in files if path.name == "AGENTS.md"]
    scripts = [path for path in files if path.suffix.lower() in SCRIPT_SUFFIXES]
    tests = [
        path
        for path in files
        if any(part.lower() in ("test", "tests", "eval", "evals", "fixtures") for part in path.parts)
    ]
    return files, {
        "total_files": len(files),
        "markdown_files": len(markdown),
        "skill_files": len(skills),
        "agent_files": len(agents),
        "script_files": len(scripts),
        "test_or_eval_files": len(tests),
    }


def _skill_records(snapshot: Path, files: Iterable[Path]) -> List[Dict[str, Any]]:
    records: List[Dict[str, Any]] = []
    for path in files:
        if path.name != "SKILL.md":
            continue
        content = _read_text(path)
        directory = path.parent
        records.append(
            {
                "name": _frontmatter_value(content, "name") or directory.name,
                "path": path.relative_to(snapshot).as_posix(),
                "lines": len(content.splitlines()),
                "has_frontmatter": content.startswith("---\n"),
                "has_description": bool(_frontmatter_value(content, "description")),
                "has_scripts": (directory / "scripts").is_dir(),
                "has_references": (directory / "references").is_dir(),
                "has_assets": (directory / "assets").is_dir(),
                "sha256": _sha256(path),
            }
        )
    return records


def _prompt_evidence(snapshot: Path, files: Iterable[Path]) -> Dict[str, Any]:
    named: List[str] = []
    code_hits: List[Dict[str, Any]] = []
    expression = re.compile(r"system_prompt|user_prompt|messages\s*=|content\s*=", re.IGNORECASE)
    for path in files:
        relative = path.relative_to(snapshot).as_posix()
        lowered = path.name.lower()
        if any(marker in lowered for marker in PROMPT_NAME_MARKERS):
            named.append(relative)
        if path.suffix.lower() not in SCRIPT_SUFFIXES:
            continue
        for line_number, line in enumerate(_read_text(path).splitlines(), start=1):
            if expression.search(line):
                code_hits.append({"path": relative, "line": line_number})
                if len(code_hits) >= 50:
                    break
        if len(code_hits) >= 50:
            break
    return {"named_files": named[:100], "code_signal_locations": code_hits}


def _pattern_signals(snapshot: Path, files: Iterable[Path], skills: Sequence[Mapping[str, Any]]) -> List[Dict[str, Any]]:
    text_files = [(path, _read_text(path)) for path in files]
    guardrail_paths = [
        path.relative_to(snapshot).as_posix()
        for path, content in text_files
        if content and any(marker in content.lower() for marker in GUARDRAIL_MARKERS)
    ]
    eval_paths = [
        path.relative_to(snapshot).as_posix()
        for path, _ in text_files
        if any(part.lower() in ("test", "tests", "eval", "evals", "fixtures") for part in path.parts)
    ]
    reference_paths = [str(item["path"]) for item in skills if item["has_references"]]
    script_paths = [str(item["path"]) for item in skills if item["has_scripts"]]
    return [
        {
            "signal": "progressive-disclosure-assets",
            "present": bool(reference_paths),
            "evidence": reference_paths[:20],
        },
        {
            "signal": "tool-backed-skills",
            "present": bool(script_paths),
            "evidence": script_paths[:20],
        },
        {
            "signal": "explicit-guardrails",
            "present": bool(guardrail_paths),
            "evidence": guardrail_paths[:20],
        },
        {
            "signal": "tests-or-evals",
            "present": bool(eval_paths),
            "evidence": eval_paths[:20],
        },
    ]


def _structural_scores(inventory: Mapping[str, int], skills: Sequence[Mapping[str, Any]], signals: Sequence[Mapping[str, Any]]) -> Dict[str, Any]:
    frontmatter = sum(1 for item in skills if item["has_frontmatter"] and item["has_description"])
    script_backed = sum(1 for item in skills if item["has_scripts"])
    reference_backed = sum(1 for item in skills if item["has_references"])
    resource_backed = sum(1 for item in skills if item["has_assets"] or item["has_references"])
    signal_count = sum(1 for item in signals if item["present"])
    scores = {
        "painpoint_precision": min(20, 4 + frontmatter * 2),
        "workflow_clarity": min(20, 4 + script_backed * 3 + signal_count),
        "context_efficiency": min(20, 4 + reference_backed * 3 + frontmatter),
        "resource_design": min(20, 4 + resource_backed * 3 + int(inventory["test_or_eval_files"] > 0) * 3),
        "extensibility": min(20, 4 + len(skills) + signal_count * 2),
    }
    return {
        "scope": "structural-readiness-only",
        "not_an_adoption_score": True,
        "dimensions": scores,
        "total": sum(scores.values()),
        "maximum": 100,
    }


def _adk_skill_names(root: Path) -> List[str]:
    manifest = root / "agent-dev-kit" / "manifest.json"
    if manifest.is_file():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        return sorted(
            str(item["name"])
            for section in ("skills", "optional_skills")
            for item in data.get(section, [])
            if isinstance(item, dict) and item.get("name")
        )
    skills_root = root / "agent-dev-kit" / "skills"
    return sorted(path.name for path in skills_root.iterdir() if path.is_dir()) if skills_root.is_dir() else []


def _dirty_state(root: Path, repository_name: str) -> Mapping[str, Any]:
    script = root / "scripts" / "classify-repo-worktree.sh"
    output = _run([str(script), str(root), repository_name])
    value = json.loads(output)
    if not isinstance(value, dict):
        raise IntakeError("dirty classifier returned a non-object")
    return value


def _markdown_table_rows(skills: Sequence[Mapping[str, Any]]) -> str:
    if not skills:
        return "| (无 SKILL.md) | - | - | - | - |"
    rows = []
    for item in skills:
        rows.append(
            "| {name} | {lines} | {scripts} | {references} | {assets} |".format(
                name=item["name"],
                lines=item["lines"],
                scripts="Y" if item["has_scripts"] else "N",
                references="Y" if item["has_references"] else "N",
                assets="Y" if item["has_assets"] else "N",
            )
        )
    return "\n".join(rows)


def _metadata_lines(analysis: Mapping[str, Any]) -> List[str]:
    source = analysis["source"]
    return [
        "- generated_at: {}".format(analysis["generated_at"]),
        "- source_commit: {}".format(source["commit"]),
        "- source_ref: {}".format(source["ref"]),
        "- worktree_branch: {}".format(source["worktree_branch"] or "-"),
        "- snapshot_mode: git-archive",
        "- analysis_policy: commit-snapshot-only",
        "- analysis_scope: static-evidence",
        "- semantic_review_status: required",
        "- worktree_dirty_classification: {}".format(source["worktree"]["classification"]),
        "- worktree_dirty_count: {}".format(source["worktree"]["dirty_count"]),
    ]


def _render_prompt_report(analysis: Mapping[str, Any]) -> str:
    prompt = analysis["prompt_evidence"]
    inventory = analysis["inventory"]
    lines = ["# Prompt 静态证据分析: {}".format(analysis["repository"]), ""]
    lines.extend(_metadata_lines(analysis))
    lines.extend(
        [
            "",
            "## 项目结构",
            "",
            "| 指标 | 数值 |",
            "|---|---:|",
            "| 总文件数 | {} |".format(inventory["total_files"]),
            "| Markdown | {} |".format(inventory["markdown_files"]),
            "| SKILL.md | {} |".format(inventory["skill_files"]),
            "| AGENTS.md | {} |".format(inventory["agent_files"]),
            "| 脚本文件 | {} |".format(inventory["script_files"]),
            "",
            "## Prompt 证据",
            "",
        ]
    )
    named = prompt["named_files"]
    lines.extend(["- 命名相关文件: {}".format(len(named)), "- 代码信号位置: {}".format(len(prompt["code_signal_locations"])), ""])
    lines.extend("- `{}`".format(item) for item in named[:30])
    if not named:
        lines.append("- 未发现基于命名的 prompt 文件；该结论仅限静态快照。")
    lines.extend(
        [
            "",
            "## 模式证据",
            "",
            "下表只表示可复核的静态信号，不直接构成采纳结论。",
            "",
            "| Signal | Present | Evidence count |",
            "|---|---|---:|",
        ]
    )
    for signal in analysis["pattern_signals"]:
        lines.append("| {} | {} | {} |".format(signal["signal"], signal["present"], len(signal["evidence"])))
    lines.extend(["", "决策候选与后续任务见 `decision-candidate.json`、`task-pack.json`。", ""])
    return "\n".join(lines)


def _render_skill_report(analysis: Mapping[str, Any]) -> str:
    lines = ["# Skill 结构化分析: {}".format(analysis["repository"]), ""]
    lines.extend(_metadata_lines(analysis))
    lines.extend(
        [
            "",
            "## Skill 清单",
            "",
            "| Skill | 行数 | Scripts | References | Assets |",
            "|---|---:|---|---|---|",
            _markdown_table_rows(analysis["skills"]),
            "",
            "## ADK 重复与新颖性",
            "",
            "- exact_name_overlap: {}".format(", ".join(analysis["comparison"]["exact_name_overlap"]) or "无"),
            "- novel_name_candidates: {}".format(", ".join(analysis["comparison"]["novel_name_candidates"]) or "无"),
            "",
            "## 五维结构就绪度",
            "",
            "> 该评分只衡量可见结构，不评价内容正确性、运行效果或是否应采纳。",
            "",
            "| 维度 | 分数 |",
            "|---|---:|",
        ]
    )
    for name, score in analysis["structural_score"]["dimensions"].items():
        lines.append("| {} | {}/20 |".format(name, score))
    lines.extend(
        [
            "| 合计 | {}/100 |".format(analysis["structural_score"]["total"]),
            "",
            "## 结论边界",
            "",
            "静态证据分析已完成；语义质量、许可证兼容、安全风险和 ADK 架构适配仍需独立审查。",
            "",
        ]
    )
    return "\n".join(lines)


def _render_index(analysis: Mapping[str, Any], mode: str) -> str:
    lines = ["# 分析索引: {}".format(analysis["repository"]), ""]
    lines.extend(_metadata_lines(analysis))
    lines.extend(["", "## 产物", "", "- [结构化证据](analysis.json)"])
    if mode in ("all", "prompt"):
        lines.append("- [Prompt 静态证据分析](prompt-analysis.md)")
    if mode in ("all", "skill"):
        lines.append("- [Skill 结构化分析](skill-deep-analysis.md)")
    lines.extend(
        [
            "- [决策候选](decision-candidate.json)",
            "- [执行任务包](task-pack.json)",
            "",
            "## 状态",
            "",
            "- 静态证据: complete",
            "- 语义审查: required",
            "- 自动写入 agent-dev-kit: forbidden",
            "",
        ]
    )
    return "\n".join(lines)


def analyze(root: Path, repository_name: str, ref: str, mode: str, output_root: Optional[Path]) -> Dict[str, Any]:
    if not REPO_NAME.fullmatch(repository_name):
        raise IntakeError("invalid repository name: {}".format(repository_name))
    root = root.resolve()
    repository = _ensure_within(root / repository_name, root, "repository")
    if not repository.is_dir():
        raise IntakeError("repository does not exist: {}".format(repository))
    if not ref or ref.startswith("-") or any(character in ref for character in ("\x00", "\n", "\r")):
        raise IntakeError("invalid git ref")
    if _run(["git", "-C", str(repository), "rev-parse", "--is-inside-work-tree"]) != "true":
        raise IntakeError("not a git repository: {}".format(repository))
    commit = _run(["git", "-C", str(repository), "rev-parse", "{}^{{commit}}".format(ref)])
    branch = _run(["git", "-C", str(repository), "branch", "--show-current"])
    worktree = _dirty_state(root, repository_name)
    short = commit[:12]
    report_base = output_root.resolve() if output_root else root / "reports" / "repo-analysis"
    report_dir = _ensure_within(report_base / repository_name / short, report_base, "report directory")

    with tempfile.TemporaryDirectory(prefix="llm-agent-intake-") as temp:
        snapshot = Path(temp) / "source"
        snapshot.mkdir()
        skipped_links = _safe_extract_archive(repository, commit, snapshot)
        files, inventory = _inventory(snapshot)
        skills = _skill_records(snapshot, files)
        prompt = _prompt_evidence(snapshot, files)
        signals = _pattern_signals(snapshot, files, skills)
        adk_names = set(_adk_skill_names(root))
        source_names = {str(item["name"]) for item in skills}
        license_files = [
            path.relative_to(snapshot).as_posix()
            for path in files
            if path.name.lower() in ("license", "license.md", "license.txt", "copying")
        ]
        analysis: Dict[str, Any] = {
            "schema": "llm-agent-intake-analysis/v1",
            "status": "static-complete",
            "repository": repository_name,
            "mode": mode,
            "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
            "source": {
                "commit": commit,
                "ref": ref,
                "worktree_branch": branch,
                "snapshot_mode": "git-archive",
                "skipped_archive_links": skipped_links,
                "worktree": worktree,
            },
            "inventory": inventory,
            "prompt_evidence": prompt,
            "skills": skills,
            "pattern_signals": signals,
            "structural_score": _structural_scores(inventory, skills, signals),
            "comparison": {
                "adk_catalog_size": len(adk_names),
                "exact_name_overlap": sorted(source_names.intersection(adk_names)),
                "novel_name_candidates": sorted(source_names.difference(adk_names)),
            },
            "license_evidence": license_files,
            "limitations": [
                "static snapshot evidence does not prove semantic quality",
                "structural score is not an adoption score",
                "runtime effectiveness and security require separate verification",
            ],
        }

    decision = {
        "schema": "llm-agent-adoption-decision/v1",
        "status": "review-required",
        "repository": repository_name,
        "source_commit": commit,
        "recommendation": "semantic-review" if skills or prompt["named_files"] else "observe",
        "auto_apply": False,
        "candidate_assets": analysis["comparison"]["novel_name_candidates"],
        "required_reviews": [
            "semantic-value",
            "existing-asset-duplication",
            "architecture-fit",
            "license-and-provenance",
            "security-and-supply-chain",
            "runtime-effectiveness",
        ],
        "prohibited_actions": ["direct-copy", "automatic-adoption-matrix-update", "automatic-adk-write"],
        "evidence": ["analysis.json"]
        + (["prompt-analysis.md"] if mode in ("all", "prompt") else [])
        + (["skill-deep-analysis.md"] if mode in ("all", "skill") else []),
    }
    task_pack = {
        "schema": "llm-agent-intake-task-pack/v1",
        "status": "ready-for-review",
        "repository": repository_name,
        "source_commit": commit,
        "tasks": [
            {
                "id": "semantic-review",
                "action": "Review candidate behavior against source evidence and ADK equivalents",
                "acceptance": "Each candidate has adopt, observe, or reject rationale with evidence paths",
            },
            {
                "id": "risk-review",
                "action": "Review license, provenance, secrets, executable scripts, hooks, and network behavior",
                "acceptance": "No unresolved blocker remains before implementation",
            },
            {
                "id": "implementation-change",
                "action": "Create an ADK change artifact for approved candidates only",
                "acceptance": "Proposal, design, negative test, implementation test, rollback, and evidence index exist",
            },
            {
                "id": "effectiveness-eval",
                "action": "Compare baseline and ADK-assisted behavior on representative tasks",
                "acceptance": "Effectiveness evidence is recorded; static structure alone is not used as proof",
            },
        ],
    }

    _atomic_json(report_dir / "analysis.json", analysis)
    _atomic_json(report_dir / "decision-candidate.json", decision)
    _atomic_json(report_dir / "task-pack.json", task_pack)
    if mode in ("all", "prompt"):
        _atomic_text(report_dir / "prompt-analysis.md", _render_prompt_report(analysis))
    if mode in ("all", "skill"):
        _atomic_text(report_dir / "skill-deep-analysis.md", _render_skill_report(analysis))
    _atomic_text(report_dir / "README.md", _render_index(analysis, mode))
    return {
        "schema": "llm-agent-intake-result/v1",
        "status": "pass",
        "repository": repository_name,
        "source_commit": commit,
        "report_dir": _portable_path(report_dir, root),
        "analysis_status": analysis["status"],
        "decision_status": decision["status"],
        "skill_count": len(skills),
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Analyze a reference repository from an immutable commit snapshot")
    parser.add_argument("repository")
    parser.add_argument("--root", default=os.environ.get("LLM_AGENT_ROOT", "."))
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--output-root")
    parser.add_argument("--summary-json", action="store_true")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--prompt", action="store_true")
    modes.add_argument("--skill", action="store_true")
    modes.add_argument("--all", action="store_true")
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _parser().parse_args(argv)
    mode = "prompt" if args.prompt else "skill" if args.skill else "all"
    try:
        result = analyze(
            Path(args.root),
            args.repository,
            args.ref,
            mode,
            Path(args.output_root) if args.output_root else None,
        )
    except (IntakeError, OSError, json.JSONDecodeError) as exc:
        print("[FAIL] {}".format(exc), file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    else:
        print("[PASS] {} {} -> {}".format(result["repository"], result["source_commit"][:12], result["report_dir"]))
        print("[INFO] static evidence complete; semantic adoption review remains required")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
