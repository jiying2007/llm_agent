"""Bounded, non-executing identity for observed reference working trees."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import selectors
import signal
import stat
import subprocess
import time
from datetime import date
from pathlib import Path
from typing import Any, Sequence

SCHEMA = "llm-agent-reference-worktree-identity/v1"
MAX_PATHS = 8192
MAX_FILE_BYTES = 32 * 1024 * 1024
MAX_TOTAL_BYTES = 512 * 1024 * 1024
MAX_GIT_BYTES = 8 * 1024 * 1024


class IdentityError(ValueError):
    pass


def _git(repo: Path, *args: str) -> bytes:
    command = ["git", "--no-optional-locks", "-c", "core.fsmonitor=false", "-c", "core.untrackedCache=false", "-C", str(repo), *args]
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True) as process:
        assert process.stdout is not None and process.stderr is not None
        output = {"stdout": bytearray(), "stderr": bytearray()}
        deadline = time.monotonic() + 30
        try:
            with selectors.DefaultSelector() as selector:
                for name, pipe in (("stdout", process.stdout), ("stderr", process.stderr)):
                    os.set_blocking(pipe.fileno(), False)
                    selector.register(pipe, selectors.EVENT_READ, name)
                while selector.get_map():
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise IdentityError("git-timeout")
                    for key, _ in selector.select(min(remaining, 0.5)):
                        chunk = os.read(key.fd, 65536)
                        if not chunk:
                            selector.unregister(key.fileobj)
                            continue
                        buffer = output[key.data]
                        limit = MAX_GIT_BYTES if key.data == "stdout" else 65536
                        if len(buffer) + len(chunk) > limit:
                            raise IdentityError("git-output-budget")
                        buffer.extend(chunk)
            if process.wait(timeout=max(0.01, deadline - time.monotonic())):
                raise IdentityError("git-read-failed")
            return bytes(output["stdout"])
        except (IdentityError, subprocess.TimeoutExpired):
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
            raise


def _paths(index: bytes, others: bytes) -> list[bytes]:
    paths = set()
    for record in index.split(b"\0"):
        if not record:
            continue
        header, path = record.split(b"\t", 1)
        if header.split(b" ")[-1] != b"0":
            raise IdentityError("unmerged-index")
        paths.add(path)
    paths.update(path for path in others.split(b"\0") if path)
    if len(paths) > MAX_PATHS:
        raise IdentityError("path-budget")
    for path in paths:
        if path.startswith(b"/") or any(part in (b"", b".", b"..") for part in path.split(b"/")):
            raise IdentityError("unsafe-path")
    return sorted(paths)


def _stamp(info: os.stat_result) -> tuple[int, ...]:
    return (info.st_dev, info.st_ino, info.st_mode, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def _entry(root_fd: int, path: bytes) -> tuple[str, int, str, int]:
    parent = os.dup(root_fd)
    try:
        parts = path.split(b"/")
        try:
            for part in parts[:-1]:
                child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
                os.close(parent)
                parent = child
            info = os.stat(parts[-1], dir_fd=parent, follow_symlinks=False)
        except FileNotFoundError:
            return "missing", 0, "", 0
        mode = stat.S_IMODE(info.st_mode)
        if stat.S_ISLNK(info.st_mode):
            target = os.readlink(parts[-1], dir_fd=parent)
            if _stamp(info) != _stamp(os.stat(parts[-1], dir_fd=parent, follow_symlinks=False)):
                raise IdentityError("worktree-changed")
            return "symlink", mode, hashlib.sha256(target).hexdigest(), len(target)
        if not stat.S_ISREG(info.st_mode):
            raise IdentityError("unsupported-file-type")
        fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
        try:
            opened = os.fstat(fd)
            if not stat.S_ISREG(opened.st_mode) or _stamp(opened) != _stamp(info):
                raise IdentityError("worktree-changed")
            if opened.st_size > MAX_FILE_BYTES:
                raise IdentityError("file-budget")
            digest = hashlib.sha256()
            count = 0
            while True:
                chunk = os.read(fd, 65536)
                if not chunk:
                    break
                count += len(chunk)
                if count > MAX_FILE_BYTES:
                    raise IdentityError("file-budget")
                digest.update(chunk)
            if _stamp(opened) != _stamp(os.fstat(fd)):
                raise IdentityError("worktree-changed")
            return "regular", mode, digest.hexdigest(), count
        finally:
            os.close(fd)
    finally:
        os.close(parent)


def _scan(repo: Path, paths: list[bytes]) -> tuple[str, int]:
    fd = os.open(repo, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    digest = hashlib.sha256()
    count = 0
    try:
        for path in paths:
            kind, mode, content, size = _entry(fd, path)
            count += size
            if count > MAX_TOTAL_BYTES:
                raise IdentityError("total-byte-budget")
            # Length-prefix the raw path so unusual filename bytes stay exact.
            digest.update(len(path).to_bytes(8, "big"))
            digest.update(path)
            digest.update(f"\0{kind}\0{mode:o}\0{content}\0".encode("ascii"))
    finally:
        os.close(fd)
    return digest.hexdigest(), count


def snapshot(root: Path, name: str) -> dict[str, Any]:
    if os.name != "posix":
        raise IdentityError("unsupported-platform")
    root = root.resolve()
    if not re.fullmatch(r"[A-Za-z0-9._-]+", name) or name in (".", ".."):
        raise IdentityError("invalid-repository-name")
    repo = root / name
    if repo.is_symlink() or not repo.is_dir():
        raise IdentityError("repository-unavailable")
    if Path(os.fsdecode(_git(repo, "rev-parse", "--show-toplevel")).strip()).resolve() != repo.resolve():
        raise IdentityError("repository-boundary-mismatch")
    head = _git(repo, "rev-parse", "HEAD").strip()
    index = _git(repo, "ls-files", "--stage", "-z")
    others = _git(repo, "ls-files", "--others", "--exclude-standard", "-z")
    paths = _paths(index, others)
    first, size = _scan(repo, paths)
    second, _ = _scan(repo, paths)
    if first != second or head != _git(repo, "rev-parse", "HEAD").strip() or index != _git(repo, "ls-files", "--stage", "-z") or others != _git(repo, "ls-files", "--others", "--exclude-standard", "-z"):
        raise IdentityError("worktree-changed")
    index_hash = hashlib.sha256(index).hexdigest()
    identity = hashlib.sha256(b"\0".join((SCHEMA.encode(), head, index_hash.encode(), second.encode()))).hexdigest()
    return {"schema": SCHEMA, "status": "pass", "repository": name,
            "head": head.decode("ascii"), "index_sha256": index_hash,
            "worktree_sha256": second, "snapshot_sha256": identity,
            "paths": len(paths), "bytes": size,
            "scope": "index-and-nonignored-worktree", "snapshot_atomic": False,
            "stable_two_scans": True, "source_approved": False,
            "runtime_enablement": False, "read_only": True}


def verify_review(root: Path, name: str, expected: str, relative: str) -> None:
    from tools.codex_assets.intake_io import IntakeError, read_json

    root = root.resolve()
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise IdentityError("invalid-review-record")
    target = root / path
    try:
        target.parent.resolve().relative_to(root)
    except ValueError as exc:
        raise IdentityError("review-record-escape") from exc
    try:
        record = read_json(target, label="review record", max_bytes=512 * 1024)
    except IntakeError as exc:
        raise IdentityError("review-record-unavailable-or-unsafe") from exc
    if not isinstance(record, dict) or record.get("schema") != "llm-agent-reference-worktree-review/v1":
        raise IdentityError("review-record-schema")
    try:
        reviewed = date.fromisoformat(record["reviewed_on"])
        expires = date.fromisoformat(record["expires_on"])
    except (KeyError, TypeError, ValueError) as exc:
        raise IdentityError("review-record-dates") from exc
    if reviewed > date.today() or expires < date.today() or expires < reviewed:
        raise IdentityError("review-record-expired-or-future")
    unsigned = dict(record)
    stored = unsigned.pop("record_sha256", None)
    actual = hashlib.sha256(json.dumps(unsigned, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
    observations = record.get("observations")
    observation = observations.get(name) if isinstance(observations, dict) else None
    if (stored != actual or not isinstance(observation, dict)
            or observation.get("snapshot_sha256") != expected
            or observation.get("source_approved") is not False
            or record.get("mode") != "report-only"
            or record.get("owner_approval") is not False
            or record.get("runtime_enablement") is not False):
        raise IdentityError("review-record-identity")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--repository", required=True)
    parser.add_argument("--field", choices=("snapshot_sha256",))
    parser.add_argument("--summary-json", action="store_true")
    parser.add_argument("--expected-snapshot")
    parser.add_argument("--review-record")
    args = parser.parse_args(argv)
    try:
        result = snapshot(Path(args.root), args.repository)
        if args.expected_snapshot or args.review_record:
            if not args.expected_snapshot or not args.review_record:
                raise IdentityError("review-binding-incomplete")
            verify_review(Path(args.root), args.repository, args.expected_snapshot, args.review_record)
            if result["snapshot_sha256"] != args.expected_snapshot:
                raise IdentityError("current-content-drift")
    except (IdentityError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
        result = {"schema": SCHEMA, "status": "blocked", "reason": str(exc) if isinstance(exc, IdentityError) else "observation-failed", "read_only": True, "source_approved": False}
        print(json.dumps(result, separators=(",", ":")))
        return 1
    print(result[args.field] if args.field else json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
