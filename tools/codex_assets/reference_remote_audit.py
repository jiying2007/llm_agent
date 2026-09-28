"""Read-only live HEAD audit for governed reference-repository pins."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

from tools.control_plane.process_budget import ProcessBudgetError, run_bounded
from tools.control_plane import reference_pins

_COMMIT = re.compile(r"[0-9a-f]{40}\Z")
_BRANCH = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/-]*\Z")
_ALLOWED_HOSTS = frozenset({"github.com", "gitlab.com", "gitee.com"})
_REGISTRY = "subrepos/registry.csv"
_PINS = "manifests/reference_pins.json"


class RemoteAuditError(ValueError):
    """A source identity or audit input is not safe to inspect."""


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _active_branches(root: Path) -> tuple[dict[str, str], str]:
    path = root / _REGISTRY
    if (
        (root / "subrepos").is_symlink() or path.is_symlink()
        or not path.is_file() or path.stat().st_size > 1024 * 1024
    ):
        raise RemoteAuditError("reference registry is missing, linked, or oversized")
    raw = path.read_bytes()
    if len(raw) > 1024 * 1024:
        raise RemoteAuditError("reference registry exceeded byte budget while reading")
    with io.StringIO(raw.decode("utf-8"), newline="") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames or not {"repo", "branch", "enabled", "status"}.issubset(reader.fieldnames):
            raise RemoteAuditError("reference registry columns are incomplete")
        branches: dict[str, str] = {}
        for row in reader:
            name = row.get("repo")
            if not name or row.get("enabled") != "yes" or row.get("status") != "active":
                continue
            branch = row.get("branch")
            if not isinstance(branch, str) or not _BRANCH.fullmatch(branch):
                raise RemoteAuditError(f"active reference {name} has an invalid branch")
            if ".." in branch or "//" in branch or branch.endswith(("/", ".lock")):
                raise RemoteAuditError(f"active reference {name} has an unsafe branch")
            if name in branches:
                raise RemoteAuditError(f"duplicate active reference: {name}")
            branches[name] = branch
    return branches, hashlib.sha256(raw).hexdigest()


def _approved_url(url: str) -> None:
    parsed = urlsplit(url)
    if (
        parsed.scheme != "https"
        or parsed.hostname not in _ALLOWED_HOSTS
        or parsed.port is not None
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
    ):
        raise RemoteAuditError("reference remote host or URL is not approved for live audit")


def _remote_head(url: str, branch: str, timeout: float) -> str | None:
    ref = f"refs/heads/{branch}"
    # Run outside the workspace so repository-local Git configuration cannot
    # rewrite the approved URL or start a credential helper.
    command = [
        "git", "-c", "credential.helper=", "-c", "protocol.ext.allow=never",
        "-c", "protocol.file.allow=never", "-c", "http.followRedirects=false",
        "ls-remote", "--heads", url, ref,
    ]
    result = run_bounded(
        command, cwd=Path("/"), timeout=timeout, max_stdout=4096, max_stderr=4096,
        env=reference_pins.git_environment(),
    )
    if result.returncode != 0:
        return None
    try:
        output = result.stdout.decode("ascii").strip()
    except UnicodeError:
        return None
    parts = output.split("\t")
    if len(parts) != 2 or parts[1] != ref or not _COMMIT.fullmatch(parts[0]):
        return None
    return parts[0]


def audit(
    root: Path,
    *,
    allow_network: bool = False,
    repo_ids: list[str] | None = None,
    timeout: float = 15.0,
) -> dict[str, Any]:
    root = root.resolve()
    if isinstance(timeout, bool) or not 0 < timeout <= 60:
        raise RemoteAuditError("timeout must be within 0-60 seconds")
    pin_path = root / _PINS
    if (
        (root / "manifests").is_symlink() or pin_path.is_symlink()
        or not pin_path.is_file() or pin_path.stat().st_size > 1024 * 1024
    ):
        raise RemoteAuditError("reference pin manifest is missing, linked, or oversized")
    pin_raw = pin_path.read_bytes()
    if len(pin_raw) > 1024 * 1024:
        raise RemoteAuditError("reference pin manifest exceeded byte budget while reading")
    pin_sha256 = hashlib.sha256(pin_raw).hexdigest()
    pin_check = reference_pins.check(root)
    if _sha256(pin_path) != pin_sha256:
        raise RemoteAuditError("reference pins changed during preflight")
    pin_data = json.loads(pin_raw)
    indexed = {item["id"]: item for item in pin_data["pins"]}
    branches, registry_sha256 = _active_branches(root)
    available = set(pin_check["reference_repos"])
    selected = sorted(set(repo_ids)) if repo_ids else sorted(available)
    if not selected or set(selected) - available:
        raise RemoteAuditError("selection contains no approved reference repository")

    rows: list[dict[str, Any]] = []
    for pin_id in selected:
        if pin_id not in branches:
            raise RemoteAuditError(f"approved pin {pin_id} lacks an active registry branch")
        pin_record = indexed[pin_id]
        url = str(pin_record["url"])
        _approved_url(url)
        pin = str(pin_record["commit"])
        branch = branches[pin_id]
        row: dict[str, Any] = {
            "id": pin_id,
            "url": url,
            "branch": branch,
            "pin": pin,
            "remote_head": None,
            "relation": "not-run-network-disabled",
            "ancestry_checked": False,
        }
        if allow_network:
            try:
                remote_head = _remote_head(url, branch, timeout)
            except (OSError, ProcessBudgetError, RuntimeError):
                remote_head = None
            row["remote_head"] = remote_head
            row["relation"] = (
                "unavailable" if remote_head is None else "same" if remote_head == pin else "different"
            )
        rows.append(row)

    changed = sum(row["relation"] == "different" for row in rows)
    unavailable = sum(row["relation"] == "unavailable" for row in rows)
    if _sha256(pin_path) != pin_sha256 or _sha256(root / _REGISTRY) != registry_sha256:
        raise RemoteAuditError("reference source declarations changed during audit")
    status = (
        "not-run-network-disabled" if not allow_network else
        "degraded" if unavailable else
        "review-required" if changed else "current"
    )
    return {
        "schema": "llm-agent-reference-remote-audit/v1",
        "status": status,
        "observed_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "pin_manifest_sha256": pin_sha256,
        "registry_sha256": registry_sha256,
        "network_requested": allow_network,
        "mutation_performed": False,
        "pin_is_evidence_not_source": True,
        "runtime_enablement": False,
        "ancestry_checked": False,
        "counts": {"selected": len(rows), "different": changed, "unavailable": unavailable},
        "repositories": rows,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Observe approved reference remote HEADs without checkout writes")
    parser.add_argument("--root", default=".")
    parser.add_argument("--repo", action="append", dest="repo_ids")
    parser.add_argument("--allow-network", action="store_true")
    parser.add_argument("--timeout", type=float, default=15.0)
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = audit(
            Path(args.root), allow_network=args.allow_network,
            repo_ids=args.repo_ids, timeout=args.timeout,
        )
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        result = {
            "schema": "llm-agent-reference-remote-audit/v1",
            "status": "blocked",
            "mutation_performed": False,
            "error": str(exc),
        }
    print(json.dumps(result, ensure_ascii=False, sort_keys=args.summary_json, indent=None if args.summary_json else 2))
    return 2 if result["status"] in ("blocked", "degraded") else 0


if __name__ == "__main__":
    raise SystemExit(main())
