"""Reexecute three immutable ADK #201 reviews under their original v8.0.36 validator.

No current-source review, human approval, provider execution or release authority.
Requires the annotated v8.0.36 tag to have been fetched in the pinned ADK repo
by the read-only GitHub Actions checkout job. No network access in this module.
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import re
import sys
import tarfile
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any

from tools.codex_assets.intake_io import _reject_symlink_chain
from tools.control_plane.process_budget import run_bounded

SCHEMA = "llm-agent-original-historical-review/v1"
TAG = "v8.0.36"
TAG_OBJECT = "d4b6d5c6c852b54e1f8153a3c9caa8c55d8b3ab8"
COMMIT = "42ae95d146ceb441ff91ea33dbbed581c33de305"
TREE = "4a034da631afbfb4b6b4d3a48310789ae85dcdbe"
VALIDATORS = {
    "src/agent_dev_kit/review_evidence.py": "73d85e864a3da125bf94808f19616f52150751a94ccc729ac66f66d2576b8808",
    "src/agent_dev_kit/strict_json.py": "e11233b8d02d7fb95a8f2f93bfff065a1db84c4ef0820fef6d817600abe8ec98",
    "src/agent_dev_kit/readiness_evidence.py": "ef980657486084eea8ab8a03ab357a76a3ed43691aca8d6909b06642764c808b",
}
POLICY = ".adk/review-policy.json"
AUTHORIZATION = ".adk/review-authorization.md"
POLICY_SHA = "f6c7571084b3f36e12e1fea1e71a46108a54835ba438b189f727a20ee88e0a24"
AUTHORIZATION_SHA = "1594e628184cb0e4ad6c669bf5ce39dcb1f333d03d0798bebb080856e703cda5"
RECORDS = {
    "20261016-skill-catalog-competition": (
        "a3884e579694cf89c2d2aa8ba0f8daac01e799008bc010645e6d4d72a6167ef2",
        "ce839fd501c606d94c57c685a38d25b907f076416f6f75f0368ea5dec1d8081d",
        "7d9562a45b1475e3a4a53548bb8d212b804c33f6",
    ),
    "20261016-effort-evidence-v1": (
        "2e68154bcb10b2ee6501fc77e5353aa8f97c907d00bcf04711efde655ebaf79b",
        "51c0f3da381bb1559a5039ed8dffa87cac475ab30f9309227aacc76f8591a855",
        "78ff0f10fc81a05ecb3ea1650a8f94f592080ef8",
    ),
    "20261016-skill-description-discovery": (
        "65ce1275b56b976db864be3fc8df01343d9b851b7b935f72117fe85fac8ad409",
        "8f2cf5749b057db7b490403b190d6b20c765d2597b4cc17a717d0e17ce293c69",
        "045c467852b07ec0d1b2c8a9cb691da034baa352",
    ),
}
ARCHIVE_BASE = "docs/changes/archive"
SRC = tuple(VALIDATORS) + ("src/agent_dev_kit/__init__.py", POLICY, AUTHORIZATION)
MAX_ARCHIVE_BYTES = 2 * 1024 * 1024
MAX_FILE_BYTES = 128 * 1024
MAX_ENTRIES = 128

# This worker imports ONLY the byte-pinned original validator from a new
# isolated temporary directory. Importing the installed/current ADK here would
# invalidate the historical claim.
_WORKER = r"""
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "src"))
from agent_dev_kit import review_evidence as legacy

expected = json.loads(sys.argv[2])
if legacy.validator_fingerprints() != expected:
    raise ValueError("original validator source drift")
records = {}
for change, (digest, patch, _tree) in json.loads(sys.argv[3]).items():
    record = root / "docs/changes/archive" / ("20261020-" + change) / "review-evidence.json"
    result = legacy.validate_review(
        root, record, policy_root=root,
        expected_subject=change, expected_scope="source-change",
    )
    if (result.get("status") != "pass" or result.get("record_sha256") != digest
            or result.get("verdicts") != {"spec": "pass", "quality": "pass"}
            or result.get("target", {}).get("original_patch_sha256") != patch):
        raise ValueError("original historical validator did not pass pinned record")
    records[change] = {
        "record_sha256": result["record_sha256"],
        "reviewed_at": result["reviewed_at"],
        "reviewer": result["reviewer"],
        "target": result["target"],
        "spec": "pass", "quality": "pass",
    }
if legacy.validator_fingerprints() != expected:
    raise ValueError("original validator drifted during execution")
print(json.dumps({"records": records}, sort_keys=True, ensure_ascii=False))
"""


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _git(adk: Path, *args: str, max_stdout: int = 4096) -> bytes:
    result = run_bounded(
        ("git", "-C", str(adk), *args),
        timeout=15, max_stdout=max_stdout, max_stderr=2048,
    )
    if result.returncode:
        raise ValueError("original ADK git object is missing or unavailable")
    return result.stdout.strip() if max_stdout == 4096 else result.stdout


def _materialize(raw_tar: bytes, destination: Path) -> None:
    count = total = 0
    names: set[str] = set()
    try:
        with tarfile.open(fileobj=io.BytesIO(raw_tar), mode="r:") as archive:
            for member in archive:
                count += 1
                if count > MAX_ENTRIES:
                    raise ValueError("original archive entry count exceeded")
                name = member.name.removesuffix("/")
                parts = PurePosixPath(name)
                if (not name or len(name) > 512 or parts.is_absolute()
                        or parts.as_posix() != name
                        or any(p in ("", ".", "..") for p in parts.parts)
                        or "\\" in name or name in names):
                    raise ValueError("original archive has an unsafe path")
                names.add(name)
                path = destination.joinpath(*parts.parts)
                if member.isdir():
                    path.mkdir(parents=True, exist_ok=True)
                    continue
                if (not member.isfile() or member.mode & 0o111
                        or member.size > MAX_FILE_BYTES):
                    raise ValueError("original archive contains an unsupported file")
                total += member.size
                if total > MAX_ARCHIVE_BYTES:
                    raise ValueError("original archive exceeds extracted byte budget")
                source = archive.extractfile(member)
                if source is None:
                    raise ValueError("original archive member cannot be read")
                data = source.read(MAX_FILE_BYTES + 1)
                if len(data) != member.size:
                    raise ValueError("original archive member changed during read")
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
    except (tarfile.TarError, OSError, EOFError) as exc:
        raise ValueError("original archive cannot be decoded safely") from exc

    required = set(SRC)
    for change in RECORDS:
        base = f"{ARCHIVE_BASE}/20261020-{change}"
        required.add(base + "/review-evidence.json")
        required.add(base + "/evidence/original.patch")
    if not required.issubset(names):
        raise ValueError("original archive lacks required source or review bytes")
    fingerprints = {
        name: _sha((destination / name).read_bytes()) for name in VALIDATORS
    }
    if fingerprints != VALIDATORS:
        raise ValueError("original validator bytes differ from frozen git identity")
    if (_sha((destination / POLICY).read_bytes()) != POLICY_SHA
            or _sha((destination / AUTHORIZATION).read_bytes()) != AUTHORIZATION_SHA):
        raise ValueError("original policy or authorization bytes differ")
    for change, (expected_record, expected_patch, _) in RECORDS.items():
        base = destination / ARCHIVE_BASE / ("20261020-" + change)
        if (_sha((base / "review-evidence.json").read_bytes()) != expected_record
                or _sha((base / "evidence/original.patch").read_bytes()) != expected_patch):
            raise ValueError("original review or patch bytes differ")


def verify_original_reviews(adk: Path) -> dict[str, Any]:
    """Reexecute original source from local immutable Git objects, fail closed."""
    adk = adk.absolute()
    _reject_symlink_chain(adk)
    ref = "refs/tags/" + TAG
    if (_git(adk, "rev-parse", "--verify", ref).decode() != TAG_OBJECT
            or _git(adk, "rev-parse", "--verify", ref + "^{commit}").decode() != COMMIT
            or _git(adk, "rev-parse", "--verify", ref + "^{tree}").decode() != TREE):
        raise ValueError("original immutable annotated release tag does not match")
    for change, (_, _, expected) in RECORDS.items():
        path = f"{ARCHIVE_BASE}/20261020-{change}"
        if _git(adk, "rev-parse", "--verify", COMMIT + ":" + path).decode() != expected:
            raise ValueError("original archive Git tree differs from pinned identity")
    paths = list(SRC) + [f"{ARCHIVE_BASE}/20261020-{name}" for name in RECORDS]
    payload = _git(adk, "archive", "--format=tar", COMMIT, *paths,
                   max_stdout=MAX_ARCHIVE_BYTES)
    with tempfile.TemporaryDirectory(prefix="adk-original-review-") as tmp:
        workspace = Path(tmp)
        _materialize(payload, workspace)
        completed = run_bounded(
            (sys.executable, "-I", "-B", "-c", _WORKER,
             str(workspace), json.dumps(VALIDATORS), json.dumps(RECORDS)),
            timeout=20, max_stdout=32768, max_stderr=2048,
            env={"PATH": os.environ.get("PATH", ""), "TZ": "UTC",
                 "PYTHONDONTWRITEBYTECODE": "1"},
        )
    if completed.returncode:
        raise ValueError("original pinned historical review execution failed")
    try:
        result = json.loads(completed.stdout.decode("utf-8"))
    except (ValueError, UnicodeError) as exc:
        raise ValueError("original review executor returned invalid JSON") from exc
    records = result.get("records")
    if (not isinstance(records, dict) or set(records) != set(RECORDS)
            or any(not isinstance(row, dict) or row.get("record_sha256") != RECORDS[cid][0]
                   or row.get("spec") != "pass" or row.get("quality") != "pass"
                   for cid, row in records.items())):
        raise ValueError("original review executor did not return all fixed reviews")
    return {
        "schema": SCHEMA,
        "source": {"tag": TAG, "tag_object": TAG_OBJECT, "commit": COMMIT, "tree": TREE,
                   "original_validator_sha256": dict(VALIDATORS)},
        "records": records,
        "historical_review_verified": True,
        "current_source_review_verified": False,
        "release_authorized": False,
        "execution_scope": "isolated-original-validator/no-current-qualification",
    }
