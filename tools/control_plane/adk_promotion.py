from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
from dataclasses import asdict, dataclass
from pathlib import Path

from tools.control_plane.receipts import bind_receipt, write_receipt
from tools.control_plane.status_projection import project, refresh_current_status

LOCK_SCHEMA = "llm-agent-adk-lock/v2"
PROMOTION_SCHEMA = "llm-agent-adk-promotion/v2"
PROMOTION_PATHS = (
    "agent-dev-kit",
    "adk.lock",
    "reports/current-status.md",
)


@dataclass(frozen=True)
class CandidateIdentity:
    version: str
    commit: str
    tree: str
    manifest_blob: str


def _git(cwd: Path, *args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout.strip()


def _root_identity(root: Path) -> dict[str, str]:
    values = _git(root, "rev-parse", "HEAD", "HEAD^{tree}").splitlines()
    if len(values) != 2:
        raise RuntimeError("unable to resolve root source identity")
    return {"head": values[0], "tree": values[1]}


def candidate_identity(candidate_dir: Path, ref: str) -> CandidateIdentity:
    commit = _git(candidate_dir, "rev-parse", f"{ref}^{{commit}}")
    tree = _git(candidate_dir, "rev-parse", f"{commit}^{{tree}}")
    manifest_text = _git(candidate_dir, "show", f"{commit}:manifest.json")
    manifest = json.loads(manifest_text)
    version = manifest.get("version")
    if not isinstance(version, str) or not version:
        raise RuntimeError("candidate manifest.json is missing version")
    manifest_blob = _git(candidate_dir, "rev-parse", f"{commit}:manifest.json")
    return CandidateIdentity(version=version, commit=commit, tree=tree, manifest_blob=manifest_blob)


def render_lock(identity: CandidateIdentity, updated_at: str) -> str:
    return (
        f"schema={LOCK_SCHEMA}\n"
        f"agent-dev-kit.version={identity.version}\n"
        f"agent-dev-kit.commit={identity.commit}\n"
        f"agent-dev-kit.tree={identity.tree}\n"
        f"agent-dev-kit.manifest_blob={identity.manifest_blob}\n"
        f"updated_at={updated_at}\n"
    )


def _staged_paths(root: Path) -> list[str]:
    output = _git(root, "diff", "--cached", "--name-only", "--diff-filter=ACDMRTUXB")
    return sorted(line for line in output.splitlines() if line)


def _root_clean_for_promotion(root: Path) -> bool:
    if _staged_paths(root):
        return False
    status = _git(root, "status", "--porcelain=v1", "--untracked-files=all")
    allowed = {"agent-dev-kit"}
    for line in status.splitlines():
        if not line:
            continue
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if path not in allowed:
            return False
    return True


def _current_gitlink(root: Path) -> str:
    value = _git(root, "ls-files", "-s", "agent-dev-kit")
    fields = value.split()
    if len(fields) < 2 or fields[0] != "160000":
        raise RuntimeError("agent-dev-kit is not a tracked gitlink")
    return fields[1]


def _atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def _rollback_transaction(
    root: Path,
    lock_path: Path,
    status_path: Path,
    previous_lock: str | None,
    previous_status: str | None,
) -> None:
    if previous_lock is None:
        lock_path.unlink(missing_ok=True)
    else:
        _atomic_write(lock_path, previous_lock)
    if previous_status is None:
        status_path.unlink(missing_ok=True)
    else:
        _atomic_write(status_path, previous_status)
    _git(root, "reset", "-q", "HEAD", "--", *PROMOTION_PATHS, check=False)


def apply_promotion(root: Path, identity: CandidateIdentity, lock_text: str) -> list[str]:
    if not _root_clean_for_promotion(root):
        raise RuntimeError(
            "promotion requires a clean index and an isolated worktree; only the agent-dev-kit worktree may differ"
        )

    lock_path = root / "adk.lock"
    status_path = root / "reports" / "current-status.md"
    previous_lock = lock_path.read_text(encoding="utf-8") if lock_path.exists() else None
    previous_status = status_path.read_text(encoding="utf-8") if status_path.exists() else None
    previous_gitlink = _current_gitlink(root)
    if identity.commit == previous_gitlink:
        raise RuntimeError("candidate ADK commit is already pinned; promotion requires a new commit")

    try:
        _atomic_write(lock_path, lock_text)
        _git(root, "update-index", "--add", "--cacheinfo", f"160000,{identity.commit},agent-dev-kit")
        refresh_current_status(root)
        _git(root, "add", "--", "adk.lock", "reports/current-status.md")

        staged_paths = _staged_paths(root)
        expected_paths = sorted(PROMOTION_PATHS)
        if staged_paths != expected_paths:
            raise RuntimeError(
                "promotion staged transaction is incomplete: "
                f"expected={expected_paths}, actual={staged_paths}"
            )

        completed = subprocess.run(
            ["bash", "scripts/check-adk-lock.sh", ".", "--pin-only"],
            cwd=root,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        if completed.returncode != 0:
            raise RuntimeError("post-apply pin validation failed: " + completed.stdout.strip())
        projection = project(root, dt.date.today())
        if projection.get("status") != "pass":
            raise RuntimeError("post-apply status projection validation failed")
        return staged_paths
    except Exception:
        _rollback_transaction(root, lock_path, status_path, previous_lock, previous_status)
        raise


def promotion_receipt(
    *,
    root: Path,
    before_gitlink: str,
    identity: CandidateIdentity,
    updated_at: str,
    mode: str,
    status: str,
    lock_lines: list[str],
    staged_paths: list[str],
) -> dict[str, object]:
    payload: dict[str, object] = {
        "schema": PROMOTION_SCHEMA,
        "mode": mode,
        "status": status,
        "source": _root_identity(root),
        "before_gitlink": before_gitlink,
        "candidate": asdict(identity),
        "lock_schema": LOCK_SCHEMA,
        "lock": lock_lines,
        "staged_paths": staged_paths,
        "staged_transaction_complete": staged_paths == sorted(PROMOTION_PATHS),
        "updated_at": updated_at,
        "requires_fresh_cross_repo_verification": True,
        "release_authorized": False,
    }
    return bind_receipt(payload)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Plan or apply an atomic ADK gitlink+lock+status promotion")
    parser.add_argument("--root", default=".")
    parser.add_argument("--candidate-dir", default="agent-dev-kit")
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--updated-at", required=True, help="Explicit YYYY-MM-DD provenance date")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Stage agent-dev-kit gitlink, adk.lock and generated current-status as one transaction; default is dry-run",
    )
    parser.add_argument("--receipt-out", help="Atomically write the content-addressed promotion receipt")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    candidate_dir = Path(args.candidate_dir)
    if not candidate_dir.is_absolute():
        candidate_dir = (root / candidate_dir).resolve()

    try:
        identity = candidate_identity(candidate_dir, args.ref)
        lock_text = render_lock(identity, args.updated_at)
        lock_lines = lock_text.splitlines()
        before = _current_gitlink(root)
        mode = "apply" if args.apply else "dry-run"
        status = "planned"
        staged_paths: list[str] = []
        if args.apply:
            staged_paths = apply_promotion(root, identity, lock_text)
            status = "applied-not-verified"
        result = promotion_receipt(
            root=root,
            before_gitlink=before,
            identity=identity,
            updated_at=args.updated_at,
            mode=mode,
            status=status,
            lock_lines=lock_lines,
            staged_paths=staged_paths,
        )
        if args.receipt_out:
            write_receipt(Path(args.receipt_out), result)
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        failure = bind_receipt({"schema": PROMOTION_SCHEMA, "status": "fail", "error": str(exc)})
        print(f"[FAIL] {exc}", file=sys.stderr)
        if args.summary_json:
            print(json.dumps(failure, ensure_ascii=False, sort_keys=True))
        return 1

    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
