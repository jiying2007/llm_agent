"""Generate review-required maintainability evidence candidates from native Git history."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Mapping, Optional, Sequence

from tools.control_plane.process_budget import ProcessBudgetError, run_bounded

from .maintainability_budget import (
    BudgetError,
    EVIDENCE_SCHEMA,
    _identifier,
    _population_digest,
    _reject_secrets,
)


CANDIDATE_SCHEMA = "llm-agent-maintainability-evidence-candidate/v2"
UTC = timezone.utc
MAX_GIT_OUTPUT_BYTES = 16 * 1024 * 1024
MAX_GIT_STDERR_BYTES = 64 * 1024
MAX_GIT_SECONDS = 60


def _git(root: Path, args: Sequence[str], *, text: bool = True) -> Any:
    # Do not capture an unbounded Git response and only check its size after
    # subprocess.run has already allocated it. Enforce the byte and wall-clock
    # budgets during concurrent pipe reads, including inherited descriptors.
    try:
        result = run_bounded(
            ["git", "-C", str(root), *args],
            timeout=MAX_GIT_SECONDS,
            max_stdout=MAX_GIT_OUTPUT_BYTES,
            max_stderr=MAX_GIT_STDERR_BYTES,
        )
    except ProcessBudgetError as exc:
        raise BudgetError("Git evidence command exceeded runtime or output budget: {}".format(args[0])) from exc
    if result.returncode != 0:
        raise BudgetError("Git evidence command failed: {}".format(args[0]))
    if not text:
        return result.stdout
    try:
        return result.stdout.decode("utf-8", errors="strict")
    except UnicodeDecodeError as exc:
        raise BudgetError("Git evidence output is not valid UTF-8") from exc


def _commit(root: Path, revision: str) -> str:
    value = _git(root, ["rev-parse", "--verify", revision + "^{commit}"]).strip()
    if len(value) != 40 or any(character not in "0123456789abcdef" for character in value):
        raise BudgetError("Git revision did not resolve to a full commit")
    return value


def _timestamp(value: Any, label: str) -> datetime:
    if isinstance(value, datetime):
        parsed = value
    elif isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError as exc:
            raise BudgetError("{} must be an RFC3339 timestamp".format(label)) from exc
    else:
        raise BudgetError("{} must be an RFC3339 timestamp".format(label))
    if parsed.tzinfo is None:
        raise BudgetError("{} must include a timezone".format(label))
    return parsed.astimezone(UTC)


def _iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _commit_time(root: Path, revision: str) -> datetime:
    return _timestamp(_git(root, ["show", "-s", "--format=%cI", revision]).strip(), "commit time")


def _tracked_paths(root: Path, revision: str) -> set[str]:
    raw = _git(root, ["ls-tree", "-r", "-z", "--name-only", revision], text=False)
    paths = set()
    for item in raw.split(b"\0"):
        if not item:
            continue
        try:
            path = item.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise BudgetError("Git evidence path is not UTF-8") from exc
        candidate = Path(path)
        if candidate.is_absolute() or ".." in candidate.parts:
            raise BudgetError("Git evidence contains an unsafe path")
        paths.add(candidate.as_posix())
    return paths


def _numstat(root: Path, start: str, end: str, population: set[str]) -> Dict[str, Dict[str, int]]:
    """Sum actual first-parent changes instead of the net endpoint diff.

    A reverted change is still churn; a file added and deleted inside the
    window must stay visible. Merge commits are compared to first parent once.
    The existing bounded Git process protects the complete output.
    """
    records = {path: {"additions": 0, "deletions": 0} for path in population}
    raw = _git(
        root,
        [
            "log", "--first-parent", "--diff-merges=first-parent",
            "--format=", "--numstat", "--no-renames", "-z",
            start + ".." + end, "--",
        ],
        text=False,
    )
    for item in raw.split(b"\0"):
        if not item:
            continue
        parts = item.split(b"\t", 2)
        if len(parts) != 3:
            raise BudgetError("Git first-parent numstat record is malformed")
        additions_raw, deletions_raw, path_raw = parts
        if additions_raw == b"-" or deletions_raw == b"-":
            raise BudgetError("Binary churn requires a separate reviewed metric")
        try:
            candidate = Path(path_raw.decode("utf-8"))
            path = candidate.as_posix()
            additions = int(additions_raw)
            deletions = int(deletions_raw)
        except (UnicodeDecodeError, ValueError) as exc:
            raise BudgetError("Git first-parent numstat record is invalid") from exc
        if (
            not path_raw or path == "." or candidate.is_absolute()
            or ".." in candidate.parts or additions < 0 or deletions < 0
        ):
            raise BudgetError("Git first-parent numstat path or counts are invalid")
        counts = records.setdefault(path, {"additions": 0, "deletions": 0})
        counts["additions"] += additions
        counts["deletions"] += deletions
    return records


_SCOPE_CLASSES = (
    "audit-evidence", "change-docs", "documentation", "reports",
    "tests", "implementation", "manifests", "other",
)


def _churn_scope(path: str) -> str:
    """Classify complete-population churn for diagnosis, never for gate exclusions."""
    if path.startswith("docs/changes/"):
        return "audit-evidence" if "/evidence/" in path else "change-docs"
    if path.startswith("docs/"):
        return "documentation"
    if path.startswith("reports/"):
        return "reports"
    if path.startswith("tests/"):
        return "tests"
    if path.startswith(("tools/", "scripts/", "src/", ".github/workflows/")):
        return "implementation"
    if path.startswith("manifests/"):
        return "manifests"
    return "other"


def _churn_scope_diagnostics(records: Sequence[Mapping[str, Any]]) -> Mapping[str, Any]:
    """Additive visibility only; leave authoritative source records and digests intact."""
    changed_lines = {scope: 0 for scope in _SCOPE_CLASSES}
    changed_files = {scope: 0 for scope in _SCOPE_CLASSES}
    for record in records:
        path = record["path"]
        churn = record["additions"] + record["deletions"]
        scope = _churn_scope(path)
        changed_lines[scope] += churn
        if churn:
            changed_files[scope] += 1
    return {
        "schema": "llm-agent-maintainability-scope-diagnostics/v1",
        "status": "report-only",
        "authority": "none-candidate-only",
        "coverage": "same-complete-evidence-population",
        "changed_lines_total": sum(changed_lines.values()),
        "changed_files_total": sum(changed_files.values()),
        "changed_lines_by_scope": changed_lines,
        "changed_files_by_scope": changed_files,
    }


def generate_churn_candidate(
    root: Path,
    repository_id: str,
    revision_start: str,
    revision_end: str,
    window_started_at: datetime,
    window_ended_at: datetime,
    *,
    generated_at: Optional[datetime] = None,
) -> Mapping[str, Any]:
    root = root.resolve()
    if not (root / ".git").exists():
        raise BudgetError("maintainability candidate requires a native Git repository")
    _reject_secrets(repository_id, "maintainability candidate repository_id")
    _identifier(repository_id, "maintainability candidate repository_id")
    start = _commit(root, revision_start)
    end = _commit(root, revision_end)
    ancestry = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", start, end],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if ancestry.returncode != 0:
        raise BudgetError("candidate revisions do not form an ancestor window")
    if start == end:
        raise BudgetError("churn candidate requires distinct start and end commits")
    # A second-parent ancestor would include changes outside the declared
    # first-parent observation window, so reject it rather than under/overcount.
    first_parent_history = _git(root, ["rev-list", "--first-parent", end]).splitlines()
    if start not in first_parent_history:
        raise BudgetError("candidate revisions do not form a first-parent window")
    window_start = _timestamp(window_started_at, "window_started_at")
    window_end = _timestamp(window_ended_at, "window_ended_at")
    now = _timestamp(generated_at or datetime.now(UTC), "generated_at")
    if not window_start < window_end <= now:
        raise BudgetError("candidate window must satisfy started_at < ended_at <= generated_at")
    start_time = _commit_time(root, start)
    end_time = _commit_time(root, end)
    if not window_start <= start_time <= end_time <= window_end:
        raise BudgetError("candidate window does not contain the revision commit times")
    population = _tracked_paths(root, start) | _tracked_paths(root, end)
    measured = _numstat(root, start, end, population)
    # Include intermediate-only paths created and deleted within the window.
    population.update(measured)
    if not population:
        raise BudgetError("candidate Git population must not be empty")
    records = [
        {"path": path, "additions": measured[path]["additions"], "deletions": measured[path]["deletions"]}
        for path in sorted(population)
    ]
    evidence = {
        "schema": EVIDENCE_SCHEMA,
        "metric": "churn",
        "repository_id": repository_id,
        "source_kind": "git-history-numstat",
        "window": {
            "started_at": _iso(window_start),
            "ended_at": _iso(window_end),
            "revision_start": start,
            "revision_end": end,
        },
        "population": {
            "count": len(population),
            "digest": _population_digest(sorted(population)),
            "coverage": "complete",
        },
        "generated_at": _iso(now),
        "records": records,
    }
    evidence_content_sha256 = hashlib.sha256(
        json.dumps(evidence, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    candidate = {
        "schema": CANDIDATE_SCHEMA,
        "status": "review-required",
        "computation": {
            "history": "first-parent",
            "merge_diff": "first-parent",
            "churn_semantics": "sum-per-commit-numstat",
            "population": "endpoints-plus-intermediate-touched",
        },
        "candidate_id": "churn-{}-{}".format(end[:12], evidence_content_sha256[:12]),
        "evidence_content_sha256": evidence_content_sha256,
        "evidence": evidence,
        "scope_diagnostics": _churn_scope_diagnostics(records),
        "review": {
            "owner_decision_required": True,
            "backlog_mutation_performed": False,
            "promotion_authority": "none-candidate-only",
            "required_checks": [
                "repository identity and revision window",
                "population completeness and privacy",
                "source path and SHA-256 insertion by owner",
            ],
        },
        "raw_content_stored": False,
    }
    _reject_secrets(candidate, "maintainability evidence candidate")
    return candidate


def _safe_output(path: Path, root: Path) -> Path:
    unresolved = path if path.is_absolute() else Path.cwd() / path
    current = Path(unresolved.anchor)
    for part in unresolved.parts[1:]:
        current = current / part
        if current.exists() and current.is_symlink():
            raise BudgetError("candidate output path must not traverse a symlink")
    output = path.resolve(strict=False)
    allowed_roots = [(root / "reports").resolve(strict=False), Path(tempfile.gettempdir()).resolve()]
    if not any(output == parent or parent in output.parents for parent in allowed_roots):
        raise BudgetError("candidate output must be under workspace reports or system tmp")
    current = output.parent
    while current != current.parent:
        if current.exists() and current.is_symlink():
            raise BudgetError("candidate output path must not traverse a symlink")
        if current in allowed_roots:
            break
        current = current.parent
    if output.exists() or output.is_symlink():
        raise BudgetError("candidate output already exists")
    return output


def write_candidate(candidate: Mapping[str, Any], output: Path, root: Path) -> Path:
    target = _safe_output(output, root)
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", prefix="." + target.name + ".", suffix=".tmp",
        dir=str(target.parent), delete=False,
    ) as stream:
        temporary = Path(stream.name)
        json.dump(candidate, stream, ensure_ascii=False, indent=2, sort_keys=True)
        stream.write("\n")
    try:
        temporary.chmod(0o644)
        try:
            os.link(str(temporary), str(target))
        except FileExistsError as exc:
            raise BudgetError("candidate output already exists") from exc
    finally:
        temporary.unlink(missing_ok=True)
    return target


def main(argv: Sequence[str] = ()) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--repository-id", required=True)
    parser.add_argument("--revision-start", required=True)
    parser.add_argument("--revision-end", required=True)
    parser.add_argument("--window-started-at", required=True)
    parser.add_argument("--window-ended-at", required=True)
    parser.add_argument("--generated-at")
    parser.add_argument("--output", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(list(argv) if argv else None)
    root = Path(args.root).resolve()
    try:
        candidate = generate_churn_candidate(
            root,
            args.repository_id,
            args.revision_start,
            args.revision_end,
            _timestamp(args.window_started_at, "window_started_at"),
            _timestamp(args.window_ended_at, "window_ended_at"),
            generated_at=_timestamp(args.generated_at, "generated_at") if args.generated_at else None,
        )
        output = Path(args.output).expanduser()
        written = str(write_candidate(candidate, output, root)) if args.apply else None
        result = {
            "schema": "llm-agent-maintainability-evidence-candidate-result/v1",
            "status": "review-required",
            "candidate_id": candidate["candidate_id"],
            "evidence_content_sha256": candidate["evidence_content_sha256"],
            "record_count": len(candidate["evidence"]["records"]),
            "scope_diagnostics": candidate["scope_diagnostics"],
            "applied": args.apply,
            "output": written,
            "backlog_mutation_performed": False,
        }
        print(json.dumps(result, ensure_ascii=False, separators=(",", ":") if args.summary_json else None))
        return 0
    except (BudgetError, OSError) as exc:
        print("[FAIL] {}".format(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
