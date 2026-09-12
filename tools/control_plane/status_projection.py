from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any

PROJECTION_SCHEMA = "llm-agent-status-projection/v3"
CURRENT_STATUS_SCHEMA = "llm-agent-current-status/v1"
BEGIN_MARKER = "<!-- BEGIN GENERATED CURRENT SOURCE PROJECTION -->"
END_MARKER = "<!-- END GENERATED CURRENT SOURCE PROJECTION -->"
PROJECTION_INPUT_PATHS = (
    "adk.lock",
    "manifests/gates.json",
    "manifests/product_maturity_scorecard.json",
    "manifests/software_m5_policy.json",
    "tools/control_plane/status_projection.py",
)


def _git(root: Path, *args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout.strip()


def _kv(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def _json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"{path.name} must contain a JSON object")
    return value


def _parse_md_fields(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    pattern = re.compile(r"^- ([A-Za-z0-9_]+):\s*(.+)$")
    for line in text.splitlines():
        match = pattern.match(line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return fields


def _md_fields(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    return _parse_md_fields(path.read_text(encoding="utf-8"))


def _generated_md_fields(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    if text.count(BEGIN_MARKER) != 1 or text.count(END_MARKER) != 1:
        raise RuntimeError("current-status generated projection markers are malformed")
    _, remainder = text.split(BEGIN_MARKER, 1)
    generated, _ = remainder.split(END_MARKER, 1)
    return _parse_md_fields(generated)


def _commit_known(root: Path, commit: str) -> bool:
    if not commit:
        return False
    return subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", f"{commit}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def _ancestry(root: Path, ancestor: str, descendant: str) -> bool | None:
    if not _commit_known(root, ancestor):
        return None
    return subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def _projection_inputs(root: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for relative in PROJECTION_INPUT_PATHS:
        path = root / relative
        if not path.is_file():
            raise RuntimeError(f"projection input missing: {relative}")
        values[relative] = _git(root, "hash-object", relative)
    return values


def _projection_digest(inputs: dict[str, str]) -> str:
    payload = json.dumps(inputs, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _bool_text(value: Any) -> str:
    return "true" if value is True else "false" if value is False else ""


def _expected_current_fields(root: Path, lock: dict[str, str], digest: str) -> dict[str, str]:
    scorecard = _json_object(root / "manifests/product_maturity_scorecard.json")
    policy = _json_object(root / "manifests/software_m5_policy.json")
    overall = scorecard.get("overall")
    software_m5 = scorecard.get("software_m5")
    release = policy.get("release")
    if not all(isinstance(value, dict) for value in (overall, software_m5, release)):
        raise RuntimeError("maturity scorecard/policy is missing required objects")
    current_commit = lock.get("agent-dev-kit.commit", "")
    candidate_commit = str(release.get("candidate_commit") or "")
    relation = "current" if candidate_commit == current_commit else "historical"
    authorized = (
        software_m5.get("certified") is True
        and overall.get("terminal_mature") is True
        and release.get("candidate_release_eligible") is True
        and relation == "current"
    )
    fields = {
        "projection_schema": CURRENT_STATUS_SCHEMA,
        "projection_semantics": "generated-current-source-projection",
        "projection_inputs_sha256": digest,
        "current_adk_version": lock.get("agent-dev-kit.version", ""),
        "current_adk_commit": current_commit,
        "current_adk_tree": lock.get("agent-dev-kit.tree", ""),
        "current_adk_manifest_blob": lock.get("agent-dev-kit.manifest_blob", ""),
        "current_product_maturity": str(overall.get("level", "")),
        "current_software_m5_readiness": str(software_m5.get("readiness_status", "")),
        "current_software_m5_certified": _bool_text(software_m5.get("certified")),
        "current_terminal_mature": _bool_text(overall.get("terminal_mature")),
        "current_field_status": str(overall.get("field_status", "")),
        "release_candidate_version": str(release.get("candidate_version", "")),
        "release_candidate_commit": candidate_commit,
        "release_evidence_relation": relation,
        "release_authorized": _bool_text(authorized),
    }
    missing = sorted(key for key, value in fields.items() if not value)
    if missing:
        raise RuntimeError("current status projection source fields are missing: " + ", ".join(missing))
    return fields


def _render_generated_block(fields: dict[str, str]) -> str:
    order = (
        "projection_schema", "projection_semantics", "projection_inputs_sha256",
        "current_adk_version", "current_adk_commit", "current_adk_tree",
        "current_adk_manifest_blob", "current_product_maturity",
        "current_software_m5_readiness", "current_software_m5_certified",
        "current_terminal_mature", "current_field_status", "release_candidate_version",
        "release_candidate_commit", "release_evidence_relation", "release_authorized",
    )
    return "\n".join([
        BEGIN_MARKER,
        "<!-- Generated by tools/control_plane/status_projection.py; do not edit this block by hand. -->",
        *(f"- {key}: {fields[key]}" for key in order),
        END_MARKER,
    ])


def _atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def refresh_current_status(root: Path) -> dict[str, str]:
    root = root.resolve()
    status_path = root / "reports/current-status.md"
    existing = status_path.read_text(encoding="utf-8")
    lock = _kv(root / "adk.lock")
    digest = _projection_digest(_projection_inputs(root))
    fields = _expected_current_fields(root, lock, digest)
    block = _render_generated_block(fields)
    if existing.count(BEGIN_MARKER) == 1 and existing.count(END_MARKER) == 1:
        before, remainder = existing.split(BEGIN_MARKER, 1)
        _, after = remainder.split(END_MARKER, 1)
        updated = before.rstrip() + "\n\n" + block + after
    elif BEGIN_MARKER in existing or END_MARKER in existing:
        raise RuntimeError("current-status generated projection markers are malformed")
    else:
        lines = existing.splitlines()
        if not lines or not lines[0].startswith("#"):
            raise RuntimeError("current-status.md must start with a Markdown heading")
        updated = lines[0] + "\n\n" + block + "\n\n" + "\n".join(lines[1:]).lstrip()
    if not updated.endswith("\n"):
        updated += "\n"
    _atomic_write(status_path, updated)
    return fields


def project(root: Path, today: dt.date) -> dict[str, Any]:
    root = root.resolve()
    head = _git(root, "rev-parse", "HEAD")
    index = _git(root, "ls-files", "-s", "agent-dev-kit").split()
    if len(index) < 2 or index[0] != "160000":
        raise RuntimeError("agent-dev-kit is not tracked as a gitlink")
    gitlink = index[1]
    lock = _kv(root / "adk.lock")
    lock_commit = lock.get("agent-dev-kit.commit", "")
    pin_consistent = lock.get("schema") == "llm-agent-adk-lock/v2" and bool(lock_commit) and gitlink == lock_commit
    status_path = root / "reports/current-status.md"
    status_fields = _md_fields(status_path)
    current_fields = _generated_md_fields(status_path)
    inputs = _projection_inputs(root)
    digest = _projection_digest(inputs)
    expected = _expected_current_fields(root, lock, digest)
    mismatches = {
        key: {"expected": value, "actual": current_fields.get(key)}
        for key, value in expected.items() if current_fields.get(key) != value
    }
    projection_consistent = not mismatches

    baseline_commit = status_fields.get("root_product_commit", "")
    baseline_date_text = status_fields.get("last_verified_at", "")
    verified_digest = status_fields.get("verified_projection_inputs_sha256", "")
    baseline_age_days: int | None = None
    baseline_date_valid = False
    if baseline_date_text:
        try:
            baseline_date = dt.date.fromisoformat(baseline_date_text)
            baseline_age_days = (today - baseline_date).days
            baseline_date_valid = baseline_age_days >= 0
        except ValueError:
            pass
    baseline_ancestor = _ancestry(root, baseline_commit, head) if baseline_commit else None
    relationship = "ancestor" if baseline_ancestor is True else "not-ancestor" if baseline_ancestor is False else "history-unavailable"
    source_match = bool(verified_digest) and verified_digest == digest
    # Shallow GitHub Actions checkouts can omit the historical baseline object.
    # Exact source-input identity is sufficient unless available history proves non-ancestry.
    baseline_fresh = (
        projection_consistent
        and baseline_ancestor is not False
        and baseline_date_valid
        and baseline_age_days is not None
        and baseline_age_days <= 7
        and source_match
    )
    baseline_integrity = bool(baseline_commit) and baseline_date_valid and baseline_ancestor is not False
    state = "verified-for-current-source" if baseline_fresh else "source-current-evidence-historical"
    result = {
        "schema": PROJECTION_SCHEMA,
        "status": "pass" if pin_consistent and projection_consistent and baseline_integrity else "fail",
        "source": {
            "head": head, "adk_gitlink": gitlink, "adk_lock_commit": lock_commit,
            "adk_lock_schema": lock.get("schema", ""), "pin_consistent": pin_consistent,
        },
        "current_projection": {
            "path": "reports/current-status.md", "schema": CURRENT_STATUS_SCHEMA,
            "inputs_sha256": digest, "inputs": inputs, "consistent": projection_consistent,
            "mismatches": mismatches,
        },
        "last_verified_baseline": {
            "path": "reports/current-status.md", "root_product_commit": baseline_commit or None,
            "last_verified_at": baseline_date_text or None,
            "verified_projection_inputs_sha256": verified_digest or None,
            "age_days": baseline_age_days, "history_available": baseline_ancestor is not None,
            "relationship_to_head": relationship, "is_ancestor": baseline_ancestor,
            "source_inputs_match": source_match, "fresh_for_current_source": baseline_fresh,
            "fresh_for_current_head": baseline_fresh,
        },
        "current_evidence_state": state,
        "release_authorized": expected["release_authorized"] == "true",
    }
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Project current source identity and generated product status")
    parser.add_argument("--root", default=".")
    parser.add_argument("--today")
    parser.add_argument("--require-fresh", action="store_true")
    parser.add_argument("--write-current-status", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        root = Path(args.root).resolve()
        if args.write_current_status:
            refresh_current_status(root)
        today = dt.date.fromisoformat(args.today) if args.today else dt.date.today()
        result = project(root, today)
        if args.require_fresh and not result["last_verified_baseline"]["fresh_for_current_source"]:
            result["status"] = "fail"
            result["error"] = (
                "current source lacks a fresh verified evidence baseline "
                f"(relationship={result['last_verified_baseline']['relationship_to_head']}, "
                f"source_inputs_match={result['last_verified_baseline']['source_inputs_match']})"
            )
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        result = {"schema": PROJECTION_SCHEMA, "status": "fail", "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False, sort_keys=args.summary_json, indent=None if args.summary_json else 2))
    return 0 if result.get("status") == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
