#!/usr/bin/env python3
"""Evidence-first, bounded analysis of explicitly governed source snapshots."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import tarfile
import tempfile
import time
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence

import yaml

from tools.control_plane.process_budget import ProcessBudgetError, run_bounded
from tools.control_plane.reference_pins import (
    git_command, git_environment, paths_overlap, protected_roots, resolve_source,
)

REPO_NAME = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]*$")
TEXT_SUFFIXES = {".c", ".cc", ".cpp", ".h", ".hpp", ".go", ".rs", ".js", ".jsx", ".json",
                 ".md", ".py", ".sh", ".toml", ".ts", ".tsx", ".txt", ".yaml", ".yml", ".proto"}
SCRIPT_SUFFIXES = {".py", ".sh", ".js", ".jsx", ".ts", ".tsx", ".rs", ".go", ".c", ".cc", ".cpp", ".h", ".hpp"}
TEXT_NAMES = {"license", "copying", "makefile", "cmakelists.txt"}
PROMPT_NAME_MARKERS = ("prompt", "system", "instruction", "skill.md", "agents.md")
GUARDRAIL_MARKERS = ("must not", "forbidden", "deny", "approval", "禁止", "不得", "审批")
EVAL_PARTS = {"test", "tests", "eval", "evals", "fixtures"}


class IntakeError(RuntimeError):
    """Expected user-facing intake failure."""


@dataclass(frozen=True)
class IntakeBudget:
    archive_bytes: int = 512 * 1024 * 1024
    archive_members: int = 50000
    text_bytes: int = 1024 * 1024
    analysis_seconds: float = 120
    command_seconds: float = 120

    def __post_init__(self) -> None:
        for value in (self.archive_bytes, self.archive_members, self.text_bytes):
            if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
                raise ValueError("byte/member budgets must be positive integers")
        for value in (self.analysis_seconds, self.command_seconds):
            if isinstance(value, bool) or not 0 < value < float("inf"):
                raise ValueError("time budgets must be positive and finite")


def _run(command: Sequence[str], cwd: Path | None = None) -> str:
    result = run_bounded(command, cwd, env=git_environment())
    if result.returncode:
        raise IntakeError("command failed: " + result.stderr.decode(errors="replace")[-500:])
    return result.stdout.decode("utf-8").strip()


def _ensure_within(path: Path, root: Path, label: str) -> Path:
    resolved = path.resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise IntakeError(f"{label} escapes workspace")
    return resolved


def _atomic_text(path: Path, content: str) -> None:
    if len(content.encode("utf-8")) > 16 * 1024 * 1024:
        raise ProcessBudgetError("report byte budget exceeded")
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def _safe_extract_archive(repository: Path, commit: str, destination: Path, budget: IntakeBudget) -> int:
    skipped_links, expanded = 0, 0
    deadline = time.monotonic() + budget.command_seconds
    with tempfile.TemporaryFile() as stream:
        result = run_bounded(
            git_command(repository, "archive", "--format=tar", commit),
            timeout=budget.command_seconds, max_stdout=budget.archive_bytes,
            stdout_sink=stream, env=git_environment(),
        )
        if result.returncode:
            raise IntakeError("git archive failed: " + result.stderr.decode(errors="replace")[-500:])
        stream.seek(0)
        with tarfile.open(fileobj=stream, mode="r:") as archive:
            for count, member in enumerate(archive, 1):
                if count > budget.archive_members or time.monotonic() > deadline:
                    raise ProcessBudgetError("archive member/time budget exceeded")
                pure = PurePosixPath(member.name)
                if pure.is_absolute() or ".." in pure.parts or "\\" in member.name:
                    raise IntakeError("unsafe archive member")
                target = _ensure_within(destination / member.name, destination, "archive member")
                if member.issym() or member.islnk():
                    skipped_links += 1
                    continue
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                if not member.isfile() or member.size < 0:
                    raise IntakeError("unsupported special archive member")
                expanded += member.size
                if expanded > budget.archive_bytes:
                    raise ProcessBudgetError("expanded archive byte budget exceeded")
                target.parent.mkdir(parents=True, exist_ok=True)
                source = archive.extractfile(member)
                if source is None:
                    raise IntakeError("archive member data is unavailable")
                with source, target.open("xb") as output:
                    shutil.copyfileobj(source, output, length=64 * 1024)
    return skipped_links


def _read_text(path: Path, limit: int) -> tuple[str, str]:
    if path.suffix.lower() not in TEXT_SUFFIXES and path.name.lower() not in TEXT_NAMES:
        return "unsupported", ""
    if path.stat().st_size > limit:
        return "oversized", ""
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        return "oversized", ""
    try:
        return "analyzed", raw.decode("utf-8")
    except UnicodeDecodeError:
        return "decode-error", ""


class _MetadataLoader(yaml.SafeLoader):
    def construct_mapping(self, node: Any, deep: bool = False) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if not isinstance(key, str) or key in result:
                raise ValueError("frontmatter keys must be unique strings")
            result[key] = self.construct_object(value_node, deep=deep)
        return result


def _frontmatter(content: str) -> tuple[str, dict[str, Any]]:
    # Normalize parser input only; preserve original bytes for the evidence hash.
    content = content.replace("\r\n", "\n")
    if not content.startswith("---\n"):
        return "missing", {}
    match = re.search(r"^---\s*$", content[4:], re.MULTILINE)
    if match is None:
        return "invalid", {}
    block = content[4:4 + match.start()]
    if len(block.encode("utf-8")) > 64 * 1024:
        return "invalid", {}
    try:
        depth = 0
        for count, event in enumerate(yaml.parse(block), 1):
            if count > 2000 or isinstance(event, yaml.AliasEvent):
                raise ValueError("frontmatter exceeds event budget or contains aliases")
            if isinstance(event, (yaml.MappingStartEvent, yaml.SequenceStartEvent)):
                depth += 1
                if depth > 16:
                    raise ValueError("frontmatter nesting exceeds budget")
            elif isinstance(event, (yaml.MappingEndEvent, yaml.SequenceEndEvent)):
                depth -= 1
        metadata = yaml.load(block, Loader=_MetadataLoader)
        if not isinstance(metadata, dict):
            raise ValueError("frontmatter must be a mapping")
        for key in ("name", "description"):
            if key in metadata and (not isinstance(metadata[key], str) or len(metadata[key]) > 8192):
                raise ValueError("name/description must be bounded strings")
        return "valid", metadata
    except (ValueError, yaml.YAMLError):
        return "invalid", {}


def _scan_snapshot(snapshot: Path, budget: IntakeBudget) -> dict[str, Any]:
    deadline = time.monotonic() + budget.analysis_seconds
    files = sorted(path for path in snapshot.rglob("*") if path.is_file() and not path.is_symlink())
    coverage: Counter[str] = Counter()
    by_suffix: dict[str, Counter[str]] = {}
    skipped: dict[str, list[str]] = {}
    skills, named, code_hits, guardrails, eval_paths, licenses = [], [], [], [], [], []
    named_count = code_count = guardrail_count = eval_count = invalid_metadata = 0
    prompt_expression = re.compile(r"system[_ -]?prompt|user[_ -]?prompt|\bmessages\s*[:=]|\bcontent\s*[:=]", re.I)
    for path in files:
        if time.monotonic() > deadline:
            raise ProcessBudgetError("analysis time budget exceeded")
        relative = path.relative_to(snapshot)
        name = relative.as_posix()
        status, content = _read_text(path, budget.text_bytes)
        coverage[status] += 1
        suffix = path.suffix.lower() or "<none>"
        by_suffix.setdefault(suffix, Counter())[status] += 1
        if status != "analyzed":
            if len(skipped.setdefault(status, [])) < 20:
                skipped[status].append(name)
        if path.name.lower() in ("license", "license.md", "license.txt", "copying"):
            licenses.append(name)
        if path.name == "SKILL.md":
            fm_status, metadata = _frontmatter(content)
            invalid_metadata += int(fm_status == "invalid")
            # Files larger than the text budget are not silently hashed/read again.
            skills.append({
                "name": metadata.get("name", "").strip() or path.parent.name,
                "path": name, "lines": len(content.splitlines()) if status == "analyzed" else None,
                "read_status": status, "frontmatter_status": fm_status,
                "has_frontmatter": fm_status == "valid",
                "has_description": bool(metadata.get("description", "").strip()),
                "description": metadata.get("description", "").strip(),
                "has_scripts": (path.parent / "scripts").is_dir(),
                "has_references": (path.parent / "references").is_dir(),
                "has_assets": (path.parent / "assets").is_dir(),
                "sha256": hashlib.sha256(content.encode("utf-8")).hexdigest() if status == "analyzed" else None,
            })
        if any(marker in path.name.lower() for marker in PROMPT_NAME_MARKERS):
            named_count += 1
            if len(named) < 100:
                named.append(name)
        if path.suffix.lower() in SCRIPT_SUFFIXES and status == "analyzed":
            for number, line in enumerate(content.splitlines(), 1):
                if prompt_expression.search(line):
                    code_count += 1
                    if len(code_hits) < 50:
                        code_hits.append({"path": name, "line": number})
        if content and any(marker in content.lower() for marker in GUARDRAIL_MARKERS):
            guardrail_count += 1
            if len(guardrails) < 20:
                guardrails.append(name)
        if any(part.lower() in EVAL_PARTS for part in relative.parts):
            eval_count += 1
            if len(eval_paths) < 20:
                eval_paths.append(name)
    if time.monotonic() > deadline:
        raise ProcessBudgetError("analysis time budget exceeded")
    references = [item["path"] for item in skills if item["has_references"]]
    scripts = [item["path"] for item in skills if item["has_scripts"]]
    signals = []
    for signal, evidence, count in (
        ("progressive-disclosure-assets", references[:20], len(references)),
        ("tool-backed-skills", scripts[:20], len(scripts)),
        ("explicit-guardrails", guardrails, guardrail_count),
        ("tests-or-evals", eval_paths, eval_count),
    ):
        signals.append({"signal": signal, "present": count > 0, "count": count,
                        "evidence": evidence, "evidence_truncated": count > len(evidence)})
    return {
        "inventory": {
            "total_files": len(files), "markdown_files": sum(p.suffix.lower() == ".md" for p in files),
            "skill_files": len(skills), "agent_files": sum(p.name == "AGENTS.md" for p in files),
            "script_files": sum(p.suffix.lower() in SCRIPT_SUFFIXES for p in files), "test_or_eval_files": eval_count,
        },
        "coverage": {"total_files": len(files), "by_status": dict(coverage),
                     "by_suffix": {key: dict(value) for key, value in sorted(by_suffix.items())},
                     "skipped_path_examples": skipped, "invalid_skill_frontmatter": invalid_metadata},
        "skills": skills, "license_evidence": licenses,
        "prompt_evidence": {"named_files": named, "named_file_count": named_count,
                            "code_signal_locations": code_hits, "code_signal_count": code_count,
                            "evidence_truncated": named_count > len(named) or code_count > len(code_hits)},
        "pattern_signals": signals,
        "structural_metrics": {
            "scope": "structure-only", "not_an_adoption_score": True,
            "skills_with_description": sum(s["has_description"] for s in skills),
            "skills_with_scripts": len(scripts), "skills_with_references": len(references),
            "signals_present": sum(s["present"] for s in signals),
        },
    }


def _resolve_input(root: Path, name: str, ref: str, kind: str, cache_root: str | None) -> tuple[Path, dict[str, Any]]:
    if kind == "reference-repo":
        source = resolve_source(root, name, cache_root)
        if ref not in ("HEAD", source.commit):
            raise IntakeError("reference analysis must use its approved exact pin")
        repository, commit, tree, url = source.repository, source.commit, source.tree, source.url
    elif kind == "managed-dependency":
        if cache_root is not None:
            raise IntakeError("cache-root is only valid for a reference repository")
        registry = json.loads((root / "manifests" / "gitlinks.json").read_text(encoding="utf-8"))
        if not isinstance(registry, dict) or not isinstance(registry.get("gitlinks"), list):
            raise IntakeError("managed dependency registry is invalid")
        entries = [e for e in registry["gitlinks"] if isinstance(e, dict) and e.get("path") == name and e.get("kind") == kind]
        if registry.get("schema") != "llm-agent-gitlinks/v2" or len(entries) != 1:
            raise IntakeError("source is not a declared managed dependency")
        repository = _ensure_within(root / name, root, "managed repository")
        commit = _run(git_command(repository, "rev-parse", ref + "^{commit}"))
        tracked = _run(git_command(root, "ls-files", "-s", "--", name)).split()
        if len(tracked) < 2 or tracked[0] != "160000" or tracked[1] != commit:
            raise IntakeError("managed source differs from Root's pinned gitlink")
        tree = _run(git_command(repository, "rev-parse", commit + "^{tree}"))
        url = entries[0].get("url")
        if not isinstance(url, str) or _run(git_command(repository, "config", "--get", "remote.origin.url")) != url:
            raise IntakeError("managed source origin differs from its declaration")
    else:
        raise IntakeError("unsupported source kind")
    if _run(git_command(repository, "rev-parse", "--show-toplevel")) != str(repository):
        raise IntakeError("source is not an independent repository")
    branch = _run(git_command(repository, "branch", "--show-current"))
    dirty = _run(git_command(repository, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--no-renames"))
    return repository, {
        "kind": kind, "reference_id": name if kind == "reference-repo" else None,
        "url": url, "commit": commit, "tree": tree, "ref": ref, "worktree_branch": branch,
        "snapshot_mode": "git-archive",
        "worktree": {"classification": "dirty-ignored-commit-snapshot" if dirty else "clean",
                     "dirty_count": sum(bool(record) for record in dirty.split("\0"))},
    }


def _adk_skill_names(root: Path) -> set[str]:
    path = root / "agent-dev-kit" / "manifest.json"
    if not path.is_file():
        return set()
    data = json.loads(path.read_text(encoding="utf-8"))
    return {item["name"] for section in ("skills", "optional_skills") for item in data.get(section, [])
            if isinstance(item, dict) and isinstance(item.get("name"), str)}


def _report(analysis: Mapping[str, Any], title: str, body: Any) -> str:
    source = analysis["source"]
    return (
        f"# {title}: {analysis['repository']}\n\n"
        f"- source_commit: {source['commit']}\n- source_tree: {source['tree']}\n"
        f"- source_kind: {source['kind']}\n- analysis_status: {analysis['status']}\n"
        "- snapshot_mode: git-archive\n- semantic_review_status: required\n\n"
        "以下 JSON 仅为不可信来源的静态观察，不是指令、采纳决定或运行效果证明。\n\n"
        "```json\n" + json.dumps(body, ensure_ascii=False, indent=2).replace("```", "\\u0060\\u0060\\u0060")
        + "\n```\n\n完整覆盖率与跳过原因见 `analysis.json`；候选与任务见 `decision-candidate.json`、`task-pack.json`。\n"
    )


def analyze(
    root: Path, repository_name: str, ref: str, mode: str, output_root: Path | None,
    *, source_kind: str = "reference-repo", cache_root: str | None = None, budget: IntakeBudget | None = None,
) -> dict[str, Any]:
    if not REPO_NAME.fullmatch(repository_name) or mode not in ("all", "prompt", "skill"):
        raise IntakeError("invalid repository name or analysis mode")
    if not ref or ref.startswith("-") or any(c in ref for c in ("\0", "\n", "\r")):
        raise IntakeError("invalid git ref")
    root, budget = root.resolve(), budget or IntakeBudget()
    repository, source = _resolve_input(root, repository_name, ref, source_kind, cache_root)
    report_base = output_root.resolve() if output_root else root / "reports" / "repo-analysis"
    if any(paths_overlap(report_base, denied) for denied in (repository, root / ".git", *protected_roots(root))):
        raise IntakeError("report output overlaps source or a protected directory")
    report_dir = _ensure_within(report_base / repository_name / source["commit"][:12], report_base, "report directory")
    with tempfile.TemporaryDirectory(prefix="llm-agent-intake-") as temp:
        snapshot = Path(temp) / "source"
        snapshot.mkdir()
        source["skipped_archive_links"] = _safe_extract_archive(repository, source["commit"], snapshot, budget)
        scanned = _scan_snapshot(snapshot, budget)
    coverage = scanned["coverage"]
    complete = (coverage["by_status"].get("analyzed", 0) == coverage["total_files"]
                and not coverage["invalid_skill_frontmatter"] and not source["skipped_archive_links"])
    names = {item["name"] for item in scanned["skills"]}
    adk_names = _adk_skill_names(root)
    analysis = {
        "schema": "llm-agent-intake-analysis/v2", "status": "static-complete" if complete else "static-partial",
        "repository": repository_name, "mode": mode,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "source": source, **scanned,
        "comparison": {"adk_catalog_status": "available" if (root / "agent-dev-kit" / "manifest.json").is_file() else "unavailable",
                       "adk_catalog_size": len(adk_names), "exact_name_overlap": sorted(names & adk_names),
                       "novel_name_candidates": sorted(names - adk_names)},
        "limitations": ["static evidence is not semantic or runtime proof", "structure counts are not effectiveness scores",
                        "unsupported/oversized/invalid files and truncated evidence are explicitly reported"],
    }
    decision = {
        "schema": "llm-agent-adoption-decision/v1", "status": "review-required", "repository": repository_name,
        "source_commit": source["commit"], "source_tree": source["tree"], "recommendation": "semantic-review",
        "auto_apply": False, "candidate_assets": sorted(names - adk_names),
        "required_reviews": ["semantic-value", "existing-asset-duplication", "architecture-fit",
                             "license-and-provenance", "security-and-supply-chain", "runtime-effectiveness"],
        "prohibited_actions": ["direct-copy", "automatic-adoption-matrix-update", "automatic-adk-write"],
        "evidence": ["analysis.json"],
    }
    task_pack = {
        "schema": "llm-agent-intake-task-pack/v1", "status": "ready-for-review", "repository": repository_name,
        "source_commit": source["commit"], "source_tree": source["tree"],
        "tasks": [
            {"id": "semantic-review", "action": "Bind each mechanism to exact source locations and an existing local problem",
             "acceptance": "Record adopt/observe/reject rationale; names or counts alone cannot prove novelty or value"},
            {"id": "risk-review", "action": "Review file-level license, provenance, scripts, hooks and network behavior",
             "acceptance": "Resolve all blockers before implementation; never execute reference hooks during intake"},
            {"id": "implementation-change", "action": "Create an ADK change for approved candidates only",
             "acceptance": "Requirements, design, negative test, implementation test, rollback and evidence exist"},
            {"id": "effectiveness-eval", "action": "Freeze tasks, repeated trials, controls, budgets and a single intervention",
             "acceptance": "Report complete paired results including failures; no lifecycle authority is inherited"},
        ],
    }
    # Prepare every report before publishing any file, including byte-budget checks.
    outputs = {
        "analysis.json": json.dumps(analysis, ensure_ascii=False, indent=2) + "\n",
        "decision-candidate.json": json.dumps(decision, ensure_ascii=False, indent=2) + "\n",
        "task-pack.json": json.dumps(task_pack, ensure_ascii=False, indent=2) + "\n",
        "README.md": _report(analysis, "分析索引", {"coverage": coverage, "auto_apply": False}),
    }
    if mode in ("all", "prompt"):
        outputs["prompt-analysis.md"] = _report(analysis, "Prompt 静态证据分析", scanned["prompt_evidence"])
    if mode in ("all", "skill"):
        outputs["skill-deep-analysis.md"] = _report(analysis, "Skill 结构化分析", {"skills": scanned["skills"], "metrics": scanned["structural_metrics"]})
    if sum(len(value.encode("utf-8")) for value in outputs.values()) > 16 * 1024 * 1024:
        raise ProcessBudgetError("combined report byte budget exceeded")
    for name, content in outputs.items():
        _atomic_text(report_dir / name, content)
    return {
        "schema": "llm-agent-intake-result/v2", "status": "pass", "repository": repository_name,
        "source_commit": source["commit"], "source_tree": source["tree"], "report_dir": str(report_dir),
        "analysis_status": analysis["status"], "decision_status": decision["status"], "skill_count": len(scanned["skills"]),
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Analyze an approved exact-pin reference cache or declared managed dependency")
    parser.add_argument("repository")
    parser.add_argument("--root", default=os.environ.get("LLM_AGENT_ROOT", "."))
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--source-kind", choices=("reference-repo", "managed-dependency"), default="reference-repo")
    parser.add_argument("--cache-root")
    parser.add_argument("--output-root")
    parser.add_argument("--summary-json", action="store_true")
    parser.add_argument("--max-archive-bytes", type=int, default=512 * 1024 * 1024)
    parser.add_argument("--max-archive-members", type=int, default=50000)
    parser.add_argument("--max-text-bytes", type=int, default=1024 * 1024)
    parser.add_argument("--timeout-seconds", type=float, default=120)
    modes = parser.add_mutually_exclusive_group()
    for flag in ("prompt", "skill", "all"):
        modes.add_argument("--" + flag, action="store_true")
    args = parser.parse_args(argv)
    try:
        budget = IntakeBudget(args.max_archive_bytes, args.max_archive_members, args.max_text_bytes,
                              args.timeout_seconds, args.timeout_seconds)
        result = analyze(Path(args.root), args.repository, args.ref,
                         "prompt" if args.prompt else "skill" if args.skill else "all",
                         Path(args.output_root) if args.output_root else None,
                         source_kind=args.source_kind, cache_root=args.cache_root, budget=budget)
    except (RuntimeError, OSError, ValueError, tarfile.TarError) as exc:
        result = {"schema": "llm-agent-intake-result/v2", "status": "fail", "error": str(exc),
                  "reason": "budget-exceeded" if isinstance(exc, ProcessBudgetError) else "invalid-input"}
        if args.summary_json:
            print(json.dumps(result, ensure_ascii=False))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    else:
        print(f"[PASS] {result['repository']} {result['source_commit'][:12]} -> {result['report_dir']}")
        print(f"[INFO] {result['analysis_status']}; semantic adoption review remains required")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
