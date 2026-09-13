#!/usr/bin/env python3
"""Software M5 facade with repository-governance abstraction.

The v3 certification core remains stable. This facade upgrades only the field
repository identity boundary so an independent pilot repository can be governed
by either a real managed gitlink or an immutable reference pin. Reference-pinned
pilots must also prove the exact pinned repository/path/commit in the existing
hash-bound pilot-start evidence.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Mapping, Sequence
from urllib.parse import urlparse

from tools.codex_assets import software_m5_v3_core as _core

POLICY_SCHEMA = _core.POLICY_SCHEMA
STATUS_SCHEMA = _core.STATUS_SCHEMA
LEDGER_SCHEMA = _core.LEDGER_SCHEMA
EVENT_SCHEMA = _core.EVENT_SCHEMA
ZERO_HASH = _core.ZERO_HASH
REQUIRED_RULES = _core.REQUIRED_RULES
M5Error = _core.M5Error

_COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")


def _repository_slug(url: str) -> str:
    if url.startswith("git@") and ":" in url:
        path = url.split(":", 1)[1]
    else:
        parsed = urlparse(url)
        if parsed.scheme not in {"http", "https", "ssh", "git"} or not parsed.path:
            raise M5Error("reference pin URL is not a supported repository URL")
        path = parsed.path
    slug = path.strip("/")
    if slug.endswith(".git"):
        slug = slug[:-4]
    if "/" not in slug:
        raise M5Error("reference pin URL must identify owner/repository")
    return slug


def _reference_repo_pins(root: Path) -> dict[str, dict[str, Any]]:
    manifest = _core._load_object(
        _core._repo_path(root, "manifests/reference_pins.json", "reference pin registry"),
        "reference pin registry",
    )
    if manifest.get("schema") != "llm-agent-reference-pins/v2":
        raise M5Error("independent reference governance requires reference-pins/v2")
    policy = manifest.get("policy")
    if not isinstance(policy, dict) or policy.get("runtime_enablement") is not False:
        raise M5Error("reference pin registry must keep runtime enablement disabled")
    pins: dict[str, dict[str, Any]] = {}
    for item in manifest.get("pins", []):
        if not isinstance(item, dict) or item.get("kind") != "reference-repo":
            continue
        pin_id = item.get("id")
        path = item.get("path")
        commit = item.get("commit")
        url = item.get("url")
        if not all(isinstance(value, str) and value for value in (pin_id, path, commit, url)):
            raise M5Error("reference repository pin is incomplete")
        if not _COMMIT_RE.fullmatch(commit):
            raise M5Error(f"reference repository pin {pin_id} has invalid commit")
        if pin_id in pins:
            raise M5Error(f"duplicate reference repository pin: {pin_id}")
        _repository_slug(url)
        pins[pin_id] = item
    return pins


def _pilot_start_matches_pin(
    root: Path,
    event: Mapping[str, Any],
    repo_id: str,
    repo_path: str,
    pin: Mapping[str, Any],
) -> bool:
    expected_repository = _repository_slug(str(pin["url"]))
    for relative in event.get("evidence", []):
        if not isinstance(relative, str) or not relative.endswith(".json"):
            continue
        evidence = _core._load_object(_core._repo_path(root, relative, "field evidence"), "field evidence")
        if evidence.get("schema") != "llm-agent-m5-independent-pilot-start/v1":
            continue
        pilot_repo = evidence.get("pilot_repository")
        if not isinstance(pilot_repo, dict):
            continue
        if (
            pilot_repo.get("id") == repo_id
            and pilot_repo.get("path") == repo_path
            and pilot_repo.get("repository") == expected_repository
            and pilot_repo.get("commit") == pin.get("commit")
            and pilot_repo.get("classification") == "independent"
            and pilot_repo.get("real_software") is True
        ):
            return True
    return False


def _validate_field(root: Path, policy: Mapping[str, Any]) -> dict[str, Any]:
    field = policy["field_qualification"]
    ledger = _core._load_object(
        _core._repo_path(root, field["ledger"], "M5 pilot ledger"), "M5 pilot ledger"
    )
    if ledger.get("schema") != LEDGER_SCHEMA:
        raise M5Error("pilot ledger schema is invalid")

    repositories = {
        item.get("id"): item
        for item in ledger.get("repositories", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    operators = {
        item.get("id"): item
        for item in ledger.get("operators", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    pilots = {
        item.get("id"): item
        for item in ledger.get("pilots", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    if len(repositories) < int(field["minimum_real_repositories"]):
        raise M5Error("real repository coverage is below policy")

    independent = {
        repo_id
        for repo_id, item in repositories.items()
        if item.get("classification") == "independent" and item.get("real_software") is True
    }
    if len(independent) < int(field["minimum_independent_repositories"]):
        raise M5Error("independent repository coverage is below policy")

    human_operators = {
        operator_id
        for operator_id, item in operators.items()
        if item.get("operator_type") == "human"
    }
    if len(human_operators) < int(field["minimum_human_operators"]):
        raise M5Error("human operator coverage is below policy")

    gitlinks = _core._load_object(
        _core._repo_path(root, "manifests/gitlinks.json", "gitlink registry"), "gitlink registry"
    )
    managed_paths = {
        item.get("path")
        for item in gitlinks.get("gitlinks", [])
        if isinstance(item, dict)
        and item.get("kind") == "managed-dependency"
        and isinstance(item.get("path"), str)
    }
    reference_pins = _reference_repo_pins(root)
    governance: dict[str, tuple[str, Mapping[str, Any] | None]] = {}
    for repo_id in independent:
        repository = repositories[repo_id]
        repo_path = repository.get("path")
        if not isinstance(repo_path, str) or not repo_path:
            raise M5Error("independent M5 repository requires a repository path")
        if repo_path in managed_paths:
            governance[repo_id] = ("managed-gitlink", None)
            continue
        pin_id = repository.get("reference_pin")
        if not isinstance(pin_id, str) or not pin_id:
            raise M5Error("independent non-gitlink repository requires reference_pin")
        pin = reference_pins.get(pin_id)
        if pin is None or pin.get("path") != repo_path:
            raise M5Error("independent M5 repository reference pin is missing or path-mismatched")
        governance[repo_id] = ("reference-pin", pin)

    events = _core._read_events(
        root, _core._repo_path(root, field["event_log"], "M5 event log")
    )
    qualifying: list[dict[str, Any]] = []
    for event in events:
        if event.get("event_type") not in field["required_event_types"]:
            continue
        if event.get("evidence_layer") != "field":
            continue
        repo_id = event.get("repository_id")
        operator_id = event.get("operator_id")
        pilot = pilots.get(event.get("pilot_id"))
        if repo_id not in independent or operator_id not in human_operators or not isinstance(pilot, dict):
            continue
        if pilot.get("environment_class") != "independent":
            continue
        if pilot.get("status") not in {"active", "completed"}:
            continue
        if repo_id not in pilot.get("repositories", []) or operator_id not in pilot.get("operators", []):
            continue
        governance_kind, pin = governance[repo_id]
        repo_path = str(repositories[repo_id]["path"])
        if governance_kind == "reference-pin" and (
            pin is None or not _pilot_start_matches_pin(root, event, repo_id, repo_path, pin)
        ):
            continue
        item = {
            "pilot_id": event.get("pilot_id"),
            "repository_id": repo_id,
            "operator_id": operator_id,
            "event_id": event.get("event_id"),
            "event_hash": event.get("event_hash"),
            "repository_governance": governance_kind,
        }
        if pin is not None:
            item["reference_commit"] = pin["commit"]
        qualifying.append(item)
    if not qualifying:
        raise M5Error("no real independent pilot_started field event satisfies M5 policy and repository identity")

    return {
        "status": "pass",
        "qualifying_events": qualifying,
        "event_chain_head": events[-1]["event_hash"] if events else ZERO_HASH,
    }


# Patch only the repository-governance boundary. All other v3 certification,
# declaration, append-only event and CLI semantics remain the stable core.
_core._validate_field = _validate_field

assess = _core.assess
check = _core.check
append_event = _core.append_event
main = _core.main

__all__ = [
    "POLICY_SCHEMA",
    "STATUS_SCHEMA",
    "LEDGER_SCHEMA",
    "EVENT_SCHEMA",
    "ZERO_HASH",
    "REQUIRED_RULES",
    "M5Error",
    "assess",
    "check",
    "append_event",
    "main",
]

if __name__ == "__main__":
    raise SystemExit(main())
