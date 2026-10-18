#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHONPATH="$ROOT" python3 - <<'PY'
import hashlib
import json
import tempfile
from pathlib import Path
from unittest.mock import patch

from tools.control_plane import terminal_closure as terminal


def blob_sha(raw):
    return hashlib.sha1(
        b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw,
        usedforsecurity=False,
    ).hexdigest()


with tempfile.TemporaryDirectory(prefix="terminal-evidence-bound-") as tmp:
    root = Path(tmp).resolve()
    directory = root / "reports/runtime-evidence/knowledge-retention"
    directory.mkdir(parents=True)
    path = directory / "evidence.json"
    relative = path.relative_to(root).as_posix()

    def entry():
        return {"path": relative, "git_blob_sha1": blob_sha(path.read_bytes())}

    path.write_text('{"schema":"sample","good":true}\n', encoding="utf-8")
    with patch.object(terminal, "read_bytes", wraps=terminal.read_bytes) as read:
        value, selected = terminal._indexed_object(root, directory, entry(), "G9 fixture")
        assert value["good"] is True and selected == relative
        assert read.call_count == 1, "Git blob verification and JSON parsing must share one read"

    def reject(source_entry, expected):
        try:
            terminal._indexed_object(root, directory, source_entry, "G9 fixture")
        except ValueError as exc:
            assert expected in str(exc), (expected, str(exc))
        else:
            raise AssertionError(f"unsafe G9 evidence accepted: {expected}")

    # A malicious second JSON key must not choose one value for the hash and
    # a different value for the terminal authority.
    path.write_text('{"schema":"sample","good":true,"good":false}\n', encoding="utf-8")
    reject(entry(), "invalid or unsafe")
    try:
        terminal._load_object(path, "G9 index")
    except ValueError as exc:
        assert "invalid or unsafe" in str(exc), str(exc)
    else:
        raise AssertionError("ambiguous G9 index accepted")

    path.write_text('{"good":NaN}\n', encoding="utf-8")
    reject(entry(), "invalid or unsafe")
    path.write_text('[]\n', encoding="utf-8")
    reject(entry(), "JSON object")
    path.write_text('{"good":true}\n', encoding="utf-8")
    reject({"path": "./" + relative, "git_blob_sha1": entry()["git_blob_sha1"]}, "canonical")

    path.write_text('{"good":true}\n', encoding="utf-8")
    original = path.read_bytes()
    target = directory / "original.json"
    target.write_bytes(original)
    path.unlink()
    path.symlink_to(target.name)
    reject({"path":relative,"git_blob_sha1":blob_sha(original)}, "symlink")
    path.unlink()
    target.unlink()

    with path.open("wb") as stream:
        stream.truncate(terminal.MAX_TERMINAL_JSON_BYTES + 1)
    reject(entry(), "invalid or unsafe")

    path.write_bytes(original)
    reject({"path":relative,"git_blob_sha1":"0"*40}, "git blob identity mismatch")
PY

echo '[PASS] terminal evidence uses one bounded, strict, content-addressed snapshot'
