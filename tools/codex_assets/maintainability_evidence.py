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

from .maintainability_budget import (
    BudgetError,
    EVIDENCE_SCHEMA,
    _identifier,
    _population_digest,
    _reject_secrets,
)


CANDIDATE_SCHEMA = "llm-agent-maintainability-evidence-candidate/v1"
UTC = timezone.utc
MAX_GIT_OUTPUT_BYTES = 16 * 1024 * 1024


def _git(root: Path, args: Sequence[str], *, text: bool = True) -> Any:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=text,
    )
    if result.returncode != 0:
        raise BudgetError("Git evidence command failed: {}".format(args[0]))
    output = result.stdout
    size = len(output.encode("utf-8")) if isinstance(output, str) else len(output)
    if size > MAX_GIT_OUTPUT_BYTES:
        raise BudgetError("Git evidence output exceeds bounded size")
    return output


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
    records = {path: {"additions": 0, "deletions": 0} for path in population}
    raw = _git(
        root,
        ["diff", "--numstat", "--no-renames", "-z", start, end, "--"],
        text=False,
    )
    for item in raw.split(b"\0"):
        if not item:
            continue
        parts = item.split(b"\t", 2)
        if len(parts) != 3:
            raise BudgetError("Git numstat record is malformed")
        additions_raw, deletions_raw, path_raw = parts
        if additions_raw == b"-" or deletions_raw == b"-":
            raise BudgetError("Binary churn requires a separate reviewed metric")
        try:
            path = Path(path_raw.decode("utf-8")).as_posix()
            additions = int(additions_raw)
            deletions = int(deletions_raw)
        except (UnicodeDecodeError, ValueError) as exc:
            raise BudgetError("Git numstat record is invalid") from exc
        if path not in records or additions < 0 or deletions < 0:
            raise BudgetError("Git numstat path is outside the reviewed population")
        records[path] = {"additions": additions, "deletions": deletions}
    return records


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
    if not population:
        raise BudgetError("candidate Git population must not be empty")
    measured = _numstat(root, start, end, population)
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
        "candidate_id": "churn-{}-{}".format(end[:12], evidence_content_sha256[:12]),
        "evidence_content_sha256": evidence_content_sha256,
        "evidence": evidence,
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
