"""Bounded intake file decoding and rollback-preserving output transactions."""
from __future__ import annotations

import hashlib
from contextlib import contextmanager
import json
import math
import os
import stat
import tempfile
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


class IntakeError(RuntimeError):
    """A sanitized, fail-closed intake contract error."""


def _canonical_json(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_value(value: Any) -> str:
    return _sha256_bytes(_canonical_json(value))


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with _regular_input(path, "input digest") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


@contextmanager
def _regular_input(path: Path, label: str):
    """Bind leaf type/identity checks to the descriptor actually read.

    Parent chain validation is a preflight; callers must control parent
    directories. This does not lock out concurrent parent renames or writers.
    """
    descriptor = None
    try:
        _reject_symlink_chain(path)
        before = path.lstat()
        if not stat.S_ISREG(before.st_mode):
            raise IntakeError("{} is missing or not a regular file".format(label))
        if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_NONBLOCK"):
            raise IntakeError("safe regular-file reading is unavailable")
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        opened = os.fstat(descriptor)
        if (not stat.S_ISREG(opened.st_mode)
                or (opened.st_dev, opened.st_ino) != (before.st_dev, before.st_ino)):
            raise IntakeError("{} changed during open".format(label))
        with os.fdopen(descriptor, "rb", closefd=False) as stream:
            yield stream
    except OSError as exc:
        raise IntakeError("cannot read {}".format(label)) from exc
    finally:
        if descriptor is not None:
            os.close(descriptor)


def _load_bytes(path: Path, limit: int, label: str) -> bytes:
    with _regular_input(path, label) as stream:
        if os.fstat(stream.fileno()).st_size > limit:
            raise IntakeError("{} exceeds the {} byte budget".format(label, limit))
        payload = stream.read(limit + 1)
        if len(payload) > limit:
            raise IntakeError("{} exceeds the {} byte budget".format(label, limit))
        return payload


def read_bytes(path: Path, *, label: str, max_bytes: int = 4 * 1024 * 1024) -> bytes:
    """Public bounded regular-file input for non-JSON consumer contracts."""
    if isinstance(max_bytes, bool) or not isinstance(max_bytes, int) or max_bytes < 1:
        raise IntakeError("byte budget must be a positive integer")
    return _load_bytes(path, max_bytes, label)


def _load_json(path: Path, limit: int, label: str) -> Any:
    raw = _load_bytes(path, limit, label)
    try:
        return decode_json(raw, label)
    except IntakeError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise IntakeError("{} must contain valid UTF-8 JSON".format(label)) from exc


def read_json(path: Path, *, label: str, max_bytes: int = 4 * 1024 * 1024) -> Any:
    """Public, bounded strict decoder for portable consumer contracts."""
    if isinstance(max_bytes, bool) or not isinstance(max_bytes, int) or max_bytes < 1:
        raise IntakeError("JSON byte budget must be a positive integer")
    return _load_json(path, max_bytes, label)


def _load_jsonl(path: Path, limit: int, label: str) -> List[Dict[str, Any]]:
    raw = _load_bytes(path, limit, label)
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise IntakeError("{} must contain UTF-8 JSONL".format(label)) from exc
    rows: List[Dict[str, Any]] = []
    for line_number, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = decode_json(line, "{} line {}".format(label, line_number))
        except json.JSONDecodeError as exc:
            raise IntakeError("{} line {} is invalid JSON".format(label, line_number)) from exc
        if not isinstance(row, dict):
            raise IntakeError("{} line {} must be an object".format(label, line_number))
        rows.append(row)
    return rows


def _resolve_path(root: Path, value: str, label: str) -> Path:
    if not isinstance(value, str) or not value:
        raise IntakeError("{} must be a non-empty path".format(label))
    raw = Path(value)
    path = raw if raw.is_absolute() else root / raw
    return Path(os.path.abspath(os.fspath(path)))


def _relative_ref(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def _input_reference(root: Path, path: Path, digest: str) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return "external-input-sha256:{}".format(digest[:20])


def _reject_symlink_chain(path: Path) -> None:
    current = path
    while True:
        if current.is_symlink():
            raise IntakeError("path must not traverse symlinks")
        if current.parent == current:
            return
        current = current.parent


def _same_file(left: Path, right: Path) -> bool:
    if left == right:
        return True
    try:
        return left.exists() and right.exists() and os.path.samefile(str(left), str(right))
    except OSError:
        return False


def _atomic_write_many(outputs: Sequence[Tuple[Path, bytes]], inputs: Iterable[Path] = (),
                       *, mode: int = 0o644) -> None:
    if isinstance(mode, bool) or not isinstance(mode, int) or not 0 <= mode <= 0o777:
        raise IntakeError("invalid output permission mode")
    if not outputs:
        return
    normalized_inputs = [Path(os.path.abspath(os.fspath(item))) for item in inputs]
    normalized_outputs: List[Tuple[Path, bytes]] = []
    for raw_path, payload in outputs:
        path = Path(os.path.abspath(os.fspath(raw_path)))
        _reject_symlink_chain(path)
        if not path.parent.is_dir():
            raise IntakeError("output parent directory does not exist")
        if any(_same_file(path, item) for item in normalized_inputs):
            raise IntakeError("output must not overwrite an input")
        if any(_same_file(path, prior) for prior, _ in normalized_outputs):
            raise IntakeError("output paths must be unique")
        normalized_outputs.append((path, payload))

    staged: Dict[Path, Path] = {}
    backups: Dict[Path, Optional[Path]] = {}
    committed: List[Path] = []
    preserve_backups = False
    try:
        for path, payload in normalized_outputs:
            descriptor, temporary = tempfile.mkstemp(prefix=".practice-intake-stage-", dir=str(path.parent))
            temp_path = Path(temporary)
            staged[path] = temp_path
            with os.fdopen(descriptor, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(str(temp_path), mode)

        for path, _ in normalized_outputs:
            backup: Optional[Path] = None
            if path.exists():
                descriptor, temporary = tempfile.mkstemp(prefix=".practice-intake-backup-", dir=str(path.parent))
                os.close(descriptor)
                backup = Path(temporary)
                backup.unlink()
                os.replace(str(path), str(backup))
            backups[path] = backup
            try:
                os.replace(str(staged[path]), str(path))
            except Exception:
                if backup is not None and backup.exists():
                    os.replace(str(backup), str(path))
                raise
            committed.append(path)

        for backup in backups.values():
            if backup is not None and backup.exists():
                try:
                    backup.unlink()
                except OSError:
                    pass
    except Exception as exc:
        rollback_errors: List[OSError] = []
        for path in reversed(committed):
            try:
                if path.exists():
                    path.unlink()
                backup = backups.get(path)
                if backup is not None and backup.exists():
                    os.replace(str(backup), str(path))
            except OSError as rollback_error:
                rollback_errors.append(rollback_error)
        for path, backup in backups.items():
            if path not in committed and backup is not None and backup.exists():
                try:
                    os.replace(str(backup), str(path))
                except OSError as rollback_error:
                    rollback_errors.append(rollback_error)
        if rollback_errors:
            preserve_backups = True
            raise IntakeError("atomic output rollback failed; backup files were preserved") from exc
        raise
    finally:
        for temp_path in staged.values():
            if temp_path.exists():
                try:
                    temp_path.unlink()
                except OSError:
                    pass
        if not preserve_backups:
            for backup in backups.values():
                if backup is not None and backup.exists():
                    try:
                        backup.unlink()
                    except OSError:
                        pass


def _atomic_write(path: Path, payload: bytes, inputs: Iterable[Path] = (), *, mode: int = 0o644) -> None:
    try:
        _atomic_write_many([(path, payload)], inputs, mode=mode)
    except IntakeError:
        raise
    except Exception as exc:
        raise IntakeError("atomic output transaction failed") from exc


def _transactional_write(outputs: Sequence[Tuple[Path, bytes]], inputs: Iterable[Path] = ()) -> None:
    try:
        _atomic_write_many(outputs, inputs)
    except IntakeError:
        raise
    except Exception as exc:
        raise IntakeError("atomic output transaction failed") from exc


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _jsonl_bytes(rows: Sequence[Mapping[str, Any]]) -> bytes:
    return b"".join(_canonical_json(row) + b"\n" for row in rows)


def decode_json(raw: bytes | str, label: str) -> Any:
    """Reject ambiguous keys and non-finite numbers without echoing content."""
    def unique(pairs: Sequence[Tuple[str, Any]]) -> Dict[str, Any]:
        value: Dict[str, Any] = {}
        for key, item in pairs:
            if key in value:
                raise IntakeError("{} contains duplicate JSON keys".format(label))
            value[key] = item
        return value

    def constant(_text: str) -> Any:
        raise IntakeError("{} contains non-finite JSON numbers".format(label))

    try:
        value = json.loads(raw, object_pairs_hook=unique, parse_constant=constant)
    except IntakeError:
        raise
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise IntakeError("{} must contain valid UTF-8 JSON".format(label)) from exc
    pending = [(value, 0)]
    while pending:
        item, depth = pending.pop()
        if depth > 64:
            raise IntakeError("{} exceeds JSON nesting budget".format(label))
        if isinstance(item, float) and not math.isfinite(item):
            raise IntakeError("{} contains non-finite JSON numbers".format(label))
        if isinstance(item, dict):
            pending.extend((child, depth + 1) for child in item.values())
        elif isinstance(item, list):
            pending.extend((child, depth + 1) for child in item)
    return value
