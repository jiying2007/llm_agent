from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from .effect_readiness import project as project_effect_readiness
from .native_target_readiness import project as project_native_readiness

SCHEMA = "llm-agent-terminal-closure/v1"
BACKLOG_PATH = Path("manifests/comprehensive_optimization_backlog.json")
G9_EVIDENCE_PATH = Path(
    "reports/runtime-evidence/knowledge-retention/g9-hub-handoff-2026-09-26.json"
)
_EXTERNAL_IDS = ("G9", "G21", "G22")


def _load_object(path: Path, label: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"{label} is missing or unsafe: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
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
        by_id[item_id] = item

    open_items = [
        {
            "id": item_id,
            "priority": item.get("priority"),
            "optimization_area": item.get("optimization_area"),
            "implementation_status": item["implementation_status"],
            "blocking_condition": item.get("blocking_condition"),
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

    evidence = _load_object(root / G9_EVIDENCE_PATH, "G9 Hub handoff evidence")
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
        and authority.get("root_may_apply_or_promote") is False
        and authority.get("automation_may_fill_reviewed_by") is False
    )
    if not captured_reviewing:
        raise ValueError("G9 governed reviewing capture evidence is inconsistent")

    owner_reviewed = authority.get("owner_review_recorded") is True
    lifecycle_decided = authority.get("lifecycle_decision_recorded") is True
    ready = owner_reviewed and lifecycle_decided
    if item["implementation_status"] == "done" and not ready:
        raise ValueError("G9 backlog claims done without durable owner lifecycle evidence")
    if item["implementation_status"] == "blocked" and ready:
        raise ValueError("G9 durable owner lifecycle evidence exists but backlog remains blocked")

    return {
        "status": "ready" if ready else "blocked-external-evidence",
        "captured_reviewing": True,
        "hub_master_revision": governed.get("merge_revision"),
        "hub_post_merge_quality_run": governed.get("post_merge_quality_run"),
        "owner_review_recorded": owner_reviewed,
        "owner_lifecycle_decision_recorded": lifecycle_decided,
        "blockers": [] if ready else ["real-human-knowledge-hub-owner-lifecycle-decision"],
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
