from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from .effect_readiness import project as project_effect_readiness
from .native_target_readiness import project as project_native_readiness

SCHEMA = "llm-agent-terminal-closure/v1"
BACKLOG_PATH = Path("manifests/comprehensive_optimization_backlog.json")
G9_EVIDENCE_INDEX = Path(
    "reports/runtime-evidence/knowledge-retention/evidence-index.json"
)
_EXTERNAL_IDS = ("G9", "G21", "G22")


def _external_tracking(item_id: str, item: dict[str, Any]) -> dict[str, Any] | None:
    tracking = item.get("external_tracking")
    if item_id not in _EXTERNAL_IDS:
        if tracking is not None:
            raise ValueError(f"non-external item {item_id} must not declare external_tracking")
        return None
    if not isinstance(tracking, dict) or set(tracking) != {"repository", "issue_number"}:
        raise ValueError(f"external item {item_id} has invalid external_tracking")
    repository = tracking.get("repository")
    issue_number = tracking.get("issue_number")
    if (
        not isinstance(repository, str)
        or repository.count("/") != 1
        or any(not part for part in repository.split("/"))
        or not isinstance(issue_number, int)
        or isinstance(issue_number, bool)
        or issue_number <= 0
    ):
        raise ValueError(f"external item {item_id} tracking issue is invalid")
    return {
        "repository": repository,
        "issue_number": issue_number,
        "url": f"https://github.com/{repository}/issues/{issue_number}",
    }


def _load_object(path: Path, label: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"{label} is missing or unsafe: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def _git_blob_sha1(path: Path) -> str:
    raw = path.read_bytes()
    digest = hashlib.sha1(usedforsecurity=False)
    digest.update(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw)
    return digest.hexdigest()


def _indexed_object(
    root: Path,
    evidence_root: Path,
    entry: Any,
    label: str,
) -> tuple[dict[str, Any], str]:
    if not isinstance(entry, dict) or set(entry) != {"path", "git_blob_sha1"}:
        raise ValueError(f"{label} index entry is invalid")
    path_value = entry.get("path")
    expected = entry.get("git_blob_sha1")
    if (
        not isinstance(path_value, str)
        or not path_value
        or Path(path_value).is_absolute()
        or ".." in Path(path_value).parts
        or "\\" in path_value
        or "\x00" in path_value
        or "\n" in path_value
        or "\r" in path_value
    ):
        raise ValueError(f"{label} path is invalid")
    if (
        not isinstance(expected, str)
        or len(expected) != 40
        or any(ch not in "0123456789abcdef" for ch in expected)
    ):
        raise ValueError(f"{label} git blob id is invalid")
    path = (root / path_value).resolve()
    if (
        not path.is_relative_to(root)
        or not path.is_relative_to(evidence_root)
        or path.is_symlink()
        or not path.is_file()
    ):
        raise ValueError(f"{label} path is missing or unsafe")
    actual = _git_blob_sha1(path)
    if actual != expected:
        raise ValueError(f"{label} git blob identity mismatch")
    return _load_object(path, label), path.relative_to(root).as_posix()


def _owner_decision(value: dict[str, Any]) -> dict[str, Any]:
    required = {
        "schema",
        "status",
        "candidate_id",
        "hub_item",
        "hub_revision",
        "reviewed_by",
        "reviewed_at",
        "lifecycle_decision",
        "automation_generated",
        "raw_content_stored",
        "release_authorized",
    }
    if set(value) != required:
        raise ValueError("G9 owner decision fields are invalid")
    if (
        value.get("schema") != "llm-agent-g9-hub-owner-decision/v1"
        or value.get("status") != "recorded"
        or value.get("candidate_id") != "llm-agent-adk-target-architecture"
        or value.get("hub_item")
        != "projects/llm-agent/architecture/llm-agent-adk-target-architecture.md"
    ):
        raise ValueError("G9 owner decision identity is invalid")
    revision = value.get("hub_revision")
    if (
        not isinstance(revision, str)
        or len(revision) != 40
        or any(ch not in "0123456789abcdef" for ch in revision)
    ):
        raise ValueError("G9 owner decision Hub revision is invalid")
    reviewer = value.get("reviewed_by")
    if not isinstance(reviewer, str) or not reviewer.strip() or len(reviewer) > 128:
        raise ValueError("G9 owner decision reviewer is invalid")
    reviewed_at = value.get("reviewed_at")
    if (
        not isinstance(reviewed_at, str)
        or "T" not in reviewed_at
        or not reviewed_at.endswith("Z")
    ):
        raise ValueError("G9 owner decision timestamp is invalid")
    if value.get("lifecycle_decision") not in {
        "activate",
        "continue-reviewing",
        "archive",
        "reject",
    }:
        raise ValueError("G9 owner lifecycle decision is invalid")
    if (
        value.get("automation_generated") is not False
        or value.get("raw_content_stored") is not False
        or value.get("release_authorized") is not False
    ):
        raise ValueError("G9 owner decision authority/privacy boundary is invalid")
    return value


def _backlog_projection(root: Path) -> dict[str, Any]:
    backlog = _load_object(root / BACKLOG_PATH, "optimization backlog")
    if backlog.get("schema_version") != 2 or backlog.get("status") != "active":
        raise ValueError("optimization backlog schema/status is invalid")
    items = backlog.get("items")
    if not isinstance(items, list) or not items:
        raise ValueError("optimization backlog items are missing")

    by_id: dict[str, dict[str, Any]] = {}
    for item in items:
        if not isinstance(item, dict):
            raise ValueError("optimization backlog contains a non-object item")
        item_id = item.get("id")
        if not isinstance(item_id, str) or not item_id or item_id in by_id:
            raise ValueError("optimization backlog item ids are invalid or duplicated")
        implementation_status = item.get("implementation_status")
        if implementation_status not in {"done", "blocked", "in_progress"}:
            raise ValueError(f"unsupported implementation status for {item_id}")
        if implementation_status == "blocked":
            blocker = item.get("blocking_condition")
            if not isinstance(blocker, str) or not blocker.strip():
                raise ValueError(f"blocked item {item_id} has no blocking condition")
        _external_tracking(item_id, item)
        by_id[item_id] = item

    open_items = [
        {
            "id": item_id,
            "priority": item.get("priority"),
            "optimization_area": item.get("optimization_area"),
            "implementation_status": item["implementation_status"],
            "blocking_condition": item.get("blocking_condition"),
            "tracking_issue": _external_tracking(item_id, item),
        }
        for item_id, item in sorted(by_id.items())
        if item["implementation_status"] != "done"
    ]
    unexpected = [
        item["id"]
        for item in open_items
        if item["id"] not in _EXTERNAL_IDS
        or item["implementation_status"] != "blocked"
    ]
    return {
        "total_items": len(by_id),
        "done_items": sum(
            item["implementation_status"] == "done" for item in by_id.values()
        ),
        "open_items": open_items,
        "open_item_ids": [item["id"] for item in open_items],
        "unexpected_nonterminal_items": unexpected,
        "items": by_id,
    }


def _g9_projection(root: Path, backlog: dict[str, Any]) -> dict[str, Any]:
    item = backlog["items"].get("G9")
    if not isinstance(item, dict):
        raise ValueError("G9 is missing from optimization backlog")

    index_path = (root / G9_EVIDENCE_INDEX).resolve()
    evidence_root = index_path.parent.resolve()
    index = _load_object(index_path, "G9 knowledge-retention evidence index")
    if (
        set(index) != {"schema", "status", "handoff", "owner_decision"}
        or index.get("schema")
        != "llm-agent-knowledge-retention-evidence-index/v1"
        or index.get("status") != "active"
    ):
        raise ValueError("G9 knowledge-retention evidence index is invalid")

    evidence, handoff_path = _indexed_object(
        root, evidence_root, index["handoff"], "G9 Hub handoff evidence"
    )
    if (
        evidence.get("schema") != "llm-agent-g9-hub-handoff-evidence/v2"
        or evidence.get("status") != "pass"
    ):
        raise ValueError("G9 Hub handoff evidence schema/status is invalid")
    hub = evidence.get("knowledge_hub")
    capture = evidence.get("capture")
    authority = evidence.get("authority_boundary")
    if not all(isinstance(value, dict) for value in (hub, capture, authority)):
        raise ValueError("G9 Hub handoff evidence is incomplete")
    governed = hub.get("governed_capture")
    if not isinstance(governed, dict):
        raise ValueError("G9 governed capture evidence is missing")

    captured_reviewing = (
        governed.get("merged") is True
        and governed.get("final_pr_quality_conclusion") == "success"
        and governed.get("security_review_conclusion") == "success"
        and governed.get("post_merge_quality_conclusion") == "success"
        and capture.get("status") == "applied"
        and capture.get("created_status") == "reviewing"
        and capture.get("promotion") == "none"
        and capture.get("active_promotion") is False
        and capture.get("promotion_authorized") is False
        and authority.get("hub_item_captured") is True
        and authority.get("owner_review_recorded") is False
        and authority.get("lifecycle_decision_recorded") is False
        and authority.get("root_may_apply_or_promote") is False
        and authority.get("automation_may_fill_reviewed_by") is False
    )
    if not captured_reviewing:
        raise ValueError("G9 governed reviewing capture evidence is inconsistent")

    decision_entry = index.get("owner_decision")
    decision_path = None
    decision = None
    if decision_entry is not None:
        decision, decision_path = _indexed_object(
            root, evidence_root, decision_entry, "G9 Hub owner decision"
        )
        decision = _owner_decision(decision)

    owner_reviewed = decision is not None
    lifecycle_decision = decision.get("lifecycle_decision") if decision else None
    terminal_decision = lifecycle_decision in {"activate", "archive", "reject"}
    if item["implementation_status"] == "done" and not terminal_decision:
        raise ValueError("G9 backlog claims done without terminal owner lifecycle evidence")
    if item["implementation_status"] == "blocked" and terminal_decision:
        raise ValueError("G9 terminal owner lifecycle evidence exists but backlog remains blocked")

    return {
        "status": "ready" if terminal_decision else "blocked-external-evidence",
        "captured_reviewing": True,
        "evidence_index": G9_EVIDENCE_INDEX.as_posix(),
        "handoff_evidence": handoff_path,
        "owner_decision_evidence": decision_path,
        "hub_master_revision": governed.get("merge_revision"),
        "hub_post_merge_quality_run": governed.get("post_merge_quality_run"),
        "owner_review_recorded": owner_reviewed,
        "owner_lifecycle_decision_recorded": owner_reviewed,
        "terminal_lifecycle_decision": terminal_decision,
        "lifecycle_decision": lifecycle_decision,
        "blockers": (
            []
            if terminal_decision
            else ["real-human-knowledge-hub-owner-terminal-lifecycle-decision"]
        ),
    }


def project(root: Path) -> dict[str, Any]:
    root = root.resolve()
    backlog = _backlog_projection(root)
    native = project_native_readiness(root)
    effect = project_effect_readiness(root)
    g9 = _g9_projection(root, backlog)

    if native.get("status") != "pass":
        raise ValueError("native readiness projection is invalid")
    if effect.get("status") != "pass":
        raise ValueError("effect readiness projection is invalid")

    software_ready = (
        not backlog["unexpected_nonterminal_items"]
        and native.get("software_ready") is True
        and effect.get("software_ready") is True
        and g9.get("captured_reviewing") is True
    )

    domain_ready = {
        "G9": g9["status"] == "ready",
        "G21": native.get("terminal_status") == "ready",
        "G22": effect.get("terminal_status") == "ready",
    }
    blockers: list[dict[str, Any]] = []
    if not domain_ready["G9"]:
        blockers.append(
            {
                "id": "G9",
                "kind": "human-owner-decision",
                "tracking_issue": _external_tracking("G9", backlog["items"]["G9"]),
                "action": (
                    "Knowledge Hub owner reviews llm-agent-adk-target-architecture "
                    "and records the lifecycle decision; automation must not fill reviewed_by."
                ),
            }
        )
    if not domain_ready["G21"]:
        blockers.append(
            {
                "id": "G21",
                "kind": "real-native-runtime-evidence",
                "tracking_issue": _external_tracking("G21", backlog["items"]["G21"]),
                "action": (
                    "Run one authenticated version-pinned direct-target discovery/load/trigger "
                    "campaign, sign the typed receipt, bind it in managed trust, and pass the "
                    "pinned ADK production loader."
                ),
            }
        )
    if not domain_ready["G22"]:
        blockers.append(
            {
                "id": "G22",
                "kind": "real-effect-value-evidence",
                "tracking_issue": _external_tracking("G22", backlog["items"]["G22"]),
                "action": (
                    "Collect decisive repeated-task comparison plus managed runtime/field "
                    "Agent Value measurements covering every current Agent/Skill/Profile, "
                    "then record digest-bound per-asset owner review."
                ),
            }
        )

    backlog_open = set(backlog["open_item_ids"])
    readiness_open = {item_id for item_id, ready in domain_ready.items() if not ready}
    if backlog_open != readiness_open:
        raise ValueError(
            "optimization backlog/readiness mismatch: "
            f"backlog={sorted(backlog_open)} readiness={sorted(readiness_open)}"
        )

    terminal_ready = software_ready and not blockers and not backlog_open
    terminal_status = (
        "ready"
        if terminal_ready
        else "blocked-external-evidence"
        if software_ready
        else "blocked-software"
    )
    return {
        "schema": SCHEMA,
        "status": "pass",
        "terminal_status": terminal_status,
        "terminal_ready": terminal_ready,
        "software_ready": software_ready,
        "backlog": {
            "total_items": backlog["total_items"],
            "done_items": backlog["done_items"],
            "open_items": backlog["open_items"],
            "unexpected_nonterminal_items": backlog[
                "unexpected_nonterminal_items"
            ],
        },
        "domains": {
            "G9": g9,
            "G21": {
                "status": native["terminal_status"],
                "software_ready": native["software_ready"],
                "native_verified": native["native_verified"],
                "native_verified_targets": native["native_verified_targets"],
                "blockers": native["blockers"],
            },
            "G22": {
                "status": effect["terminal_status"],
                "software_ready": effect["software_ready"],
                "effect_evidence_ready": effect["effect_evidence_ready"],
                "evidence_index": effect["evidence_index"],
                "blockers": effect["blockers"],
            },
        },
        "external_blockers": blockers,
        "authority_boundary": {
            "projection_has_execution_authority": False,
            "projection_may_fill_owner_review": False,
            "projection_may_create_runtime_or_effect_evidence": False,
            "projection_authorizes_release": False,
        },
        "release_authorized": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Project terminal llm_agent/ADK closure and remaining external facts"
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--require-terminal", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = project(Path(args.root))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        result = {
            "schema": SCHEMA,
            "status": "fail",
            "terminal_status": "invalid-source",
            "terminal_ready": False,
            "software_ready": False,
            "failures": [str(exc)],
            "external_blockers": [],
            "release_authorized": False,
        }

    print(
        json.dumps(result, ensure_ascii=False, sort_keys=True)
        if args.summary_json
        else json.dumps(result, ensure_ascii=False, indent=2)
    )
    if result["status"] != "pass":
        return 1
    if args.require_terminal and not result["terminal_ready"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
