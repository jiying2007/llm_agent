from __future__ import annotations

import hashlib
import json
import os
import tempfile
from pathlib import Path
from typing import Any


def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode(
        "utf-8"
    )


def content_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def bind_receipt(payload: dict[str, Any]) -> dict[str, Any]:
    """Return a copy carrying a digest over all receipt fields except its digest."""
    result = dict(payload)
    result.pop("receipt_sha256", None)
    result["receipt_sha256"] = content_sha256(result)
    return result


def write_receipt(path: Path, receipt: dict[str, Any]) -> None:
    """Atomically write a receipt without changing its canonical identity."""
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(canonical_json_bytes(receipt))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
