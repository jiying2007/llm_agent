"""Synthetic delegated review fixtures; never runtime or field qualification evidence."""
from __future__ import annotations

import hashlib
import importlib
import json
import subprocess
from collections.abc import Sequence
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def timestamp(value: datetime) -> str:
    return value.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def policy_fixture(root: Path, now: datetime) -> dict[str, Any]:
    """Copy the actual loaded validator bytes into an isolated synthetic pin."""
    for name in ("review_evidence", "strict_json", "readiness_evidence"):
        module = importlib.import_module("agent_dev_kit." + name)
        path = root / "src/agent_dev_kit" / (name + ".py")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(Path(module.__file__).read_bytes())
    authorization = root / "authorization.txt"
    authorization.parent.mkdir(parents=True, exist_ok=True)
    authorization.write_text("Synthetic test-only owner delegation; no real qualification authority.\n", encoding="utf-8")
    policy = {
        "schema": "adk-review-policy/v1",
        "mode": "owner-delegated-ai",
        "owner": "fixture-owner",
        "allowed_scopes": ["source-change", "harness-source", "effect-value-review", "longitudinal-review"],
        "authorization": {"path": authorization.relative_to(root).as_posix(), "sha256": sha(authorization),
                          "granted_at": timestamp(now - timedelta(days=1))},
    }
    write_json(root / ".adk/review-policy.json", policy)
    # Pin real Git blobs in an isolated fixture. A directory of lookalike files
    # must not substitute for the ADK commit selected by the Root gitlink.
    subprocess.run(["git", "-C", str(root), "init", "-q"], check=True, capture_output=True)
    subprocess.run(["git", "-C", str(root), "add", "--", "src/agent_dev_kit", ".adk/review-policy.json", "authorization.txt"],
                   check=True, capture_output=True)
    subprocess.run(["git", "-C", str(root), "-c", "user.name=Synthetic Fixture", "-c", "user.email=fixture@example.invalid",
                    "commit", "-qm", "Synthetic delegated review policy fixture"], check=True, capture_output=True)
    head = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], check=True,
                          capture_output=True, text=True).stdout.strip()
    subprocess.run(["git", "-C", str(root.parent), "init", "-q"], check=True, capture_output=True)
    subprocess.run(["git", "-C", str(root.parent), "update-index", "--add", "--cacheinfo",
                    "160000," + head + ",agent-dev-kit"], check=True, capture_output=True)
    return policy


def review_fixture(
    root: Path, path: Path, *, subject: str, scope: str, sources: Sequence[Path],
    reviewed_at: datetime, completed_at: datetime | None = None, policy_root: Path | None = None,
    target: dict[str, str] | None = None,
) -> dict[str, Any]:
    """Write a clearly labelled test record using the production validator API."""
    review_evidence = importlib.import_module("agent_dev_kit.review_evidence")
    path.parent.mkdir(parents=True, exist_ok=True)
    observations = path.with_name(path.stem + "-observations.txt")
    observations.write_text("Synthetic fixture observations only; no model, runtime or field execution.\n", encoding="utf-8")
    source_paths = list(sources)
    if target is not None:
        original_patch = path.parent / "evidence/original.patch"
        original_patch.parent.mkdir(parents=True, exist_ok=True)
        original_patch.write_text("diff --git a/fixture.txt b/fixture.txt\n--- a/fixture.txt\n+++ b/fixture.txt\n@@ -1 +1 @@\n-before\n+after\n", encoding="utf-8")
        source_paths.append(original_patch)
        target = {"original_patch_sha256": sha(original_patch), **target}

    def reference(source: Path) -> dict[str, str]:
        if source.is_relative_to(path.parent):
            return {"base": "record", "path": source.relative_to(path.parent).as_posix(), "sha256": sha(source)}
        return {"base": "repository", "path": source.relative_to(root).as_posix(), "sha256": sha(source)}

    record = {
        "schema": "adk-review-evidence/v1", "subject_id": subject, "scope": scope,
        "author_id": "fixture-author",
        "reviewer": {"id": "fixture-ai-reviewer", "kind": "ai", "independence": "independent"},
        "reviewed_at": timestamp(reviewed_at), "evidence_completed_at": timestamp(completed_at or reviewed_at),
        "verdicts": {"spec": "pass", "quality": "pass"}, "findings": [],
        "limitations": ["Synthetic deterministic fixture, never real qualification evidence."],
        "policy_sha256": sha((policy_root or root) / ".adk/review-policy.json"),
        "validator_sha256": review_evidence.validator_fingerprints(),
        "sources": [reference(source) for source in source_paths], "evidence": [reference(observations)],
    }
    if target is not None:
        record["target"] = target
    write_json(path, record)
    return record
