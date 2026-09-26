from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

import yaml

SCHEMA = "llm-agent-knowledge-retention-handoff/v1"
CANDIDATE = "docs/knowledge-candidates/llm-agent-adk-target-architecture.md"
SOURCE_REFS = (
    "reports/architecture/llm-agent-adk-target-architecture-2026-07-30.md",
    "manifests/comprehensive_optimization_backlog.json",
    "reports/current-status.md",
    "docs/runbooks/practice-effect-review.md",
    "docs/runbooks/native-target-conformance-readiness.md",
    "docs/runbooks/effect-readiness.md",
)
_FORBIDDEN = (
    re.compile(r"(?i)\bghp_[A-Za-z0-9]{16,}\b"),
    re.compile(r"(?i)\bgithub_pat_[A-Za-z0-9_]{16,}\b"),
    re.compile(r"(?i)\bsk-[A-Za-z0-9_-]{10,}\b"),
    re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/-]{8,}=*\b"),
    re.compile(r"(?i)(?:password|secret|credential|api[_ -]?key)\s*[:=]\s*\S+"),
    re.compile(r"(?<![A-Za-z0-9_])/(?:home|Users)/[^/\s]+/"),
    re.compile(r"(?i)[A-Z]:\\Users\\[^\\\s]+\\"),
)


def _frontmatter(text: str) -> dict[str, Any]:
    if not text.startswith("---\n"):
        raise ValueError("knowledge candidate requires YAML frontmatter")
    marker = text.find("\n---\n", 4)
    if marker < 0:
        raise ValueError("knowledge candidate frontmatter is not closed")
    block = text[4:marker]
    if len(block.encode("utf-8")) > 64 * 1024:
        raise ValueError("knowledge candidate frontmatter exceeds byte budget")
    value = yaml.safe_load(block)
    if not isinstance(value, dict):
        raise ValueError("knowledge candidate frontmatter must be an object")
    return value


def project(root: Path) -> dict[str, Any]:
    root = root.resolve()
    path = (root / CANDIDATE).resolve()
    if not path.is_relative_to(root) or path.is_symlink() or not path.is_file():
        raise ValueError("knowledge candidate is missing or unsafe")
    raw = path.read_bytes()
    if len(raw) > 512 * 1024:
        raise ValueError("knowledge candidate exceeds byte budget")
    text = raw.decode("utf-8")
    metadata = _frontmatter(text)
    required = {
        "id": "llm-agent-adk-target-architecture",
        "status": "reviewing-candidate",
        "promotion": "none",
        "generated_by_ai": True,
        "source_repo": "jiying2007/llm_agent",
    }
    for key, expected in required.items():
        if metadata.get(key) != expected:
            raise ValueError(f"knowledge candidate {key} differs from reviewed contract")
    forbidden_hits = [pattern.pattern for pattern in _FORBIDDEN if pattern.search(text)]
    if forbidden_hits:
        raise ValueError("knowledge candidate contains secret/private-path-like content")
    missing_refs = [relative for relative in SOURCE_REFS if not (root / relative).is_file()]
    if missing_refs:
        raise ValueError("knowledge candidate source references are missing: " + ", ".join(missing_refs))

    digest = hashlib.sha256(raw).hexdigest()
    source_arg = f"$PWD/{CANDIDATE}"
    capture = (
        "rtk bash ~/knowledge-hub/tools/knowledge-capture.sh "
        f"--source \"{source_arg}\" --kind architecture "
        "--target projects/llm-agent/architecture/llm-agent-adk-target-architecture.md "
        "--id llm-agent-adk-target-architecture "
        "--title \"llm_agent / agent-dev-kit 长期资产架构结论候选\" "
        "--domain projects/llm-agent --owner leiwenjun --status reviewing "
        "--generated-by-ai --ai-role summarized --ai-model-or-tool ChatGPT "
        "--source-type public-repository "
        "--source-from https://github.com/jiying2007/llm_agent "
        "--dry-run --json"
    )
    status = (
        "rtk bash ~/knowledge-hub/tools/knowledge-status.sh "
        "--summary-json --review-queue-limit 5"
    )
    return {
        "schema": SCHEMA,
        "status": "pass",
        "handoff_status": "ready-for-external-hub-dry-run",
        "candidate": CANDIDATE,
        "candidate_sha256": digest,
        "candidate_bytes": len(raw),
        "source_references": list(SOURCE_REFS),
        "knowledge_hub_boundary": {
            "repository": "jiying2007/knowledge-hub",
            "capture_entry": "tools/knowledge-capture.sh",
            "status_entry": "tools/knowledge-status.sh",
            "capture_mode": "dry-run",
            "target_status": "reviewing",
            "promotion": "none",
            "owner_review_required": True,
        },
        "commands": {
            "capture_dry_run": capture,
            "status": status,
        },
        "external_action_required": True,
        "promotion_authorized": False,
        "writes_knowledge_hub": False,
        "writes_source_repository": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate the llm_agent to Knowledge Hub candidate handoff")
    parser.add_argument("--root", default=".")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = project(Path(args.root))
    except (OSError, ValueError, UnicodeError, yaml.YAMLError) as exc:
        result = {"schema": SCHEMA, "status": "fail", "error": str(exc)}
    print(
        json.dumps(result, ensure_ascii=False, sort_keys=True)
        if args.summary_json
        else json.dumps(result, ensure_ascii=False, indent=2)
    )
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
