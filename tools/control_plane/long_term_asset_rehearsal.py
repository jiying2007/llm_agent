from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

POLICY_PATH = Path("manifests/long_term_asset_rehearsal.json")
LTA_PATH = Path("manifests/long_term_asset_qualification.json")
SCHEMA = "llm-agent-long-term-asset-rehearsal/v1"
POLICY_SCHEMA = "llm-agent-long-term-asset-rehearsal-policy/v1"


class RehearsalError(RuntimeError):
    pass


def _load(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RehearsalError(f"invalid {label}: {path}") from exc
    if not isinstance(value, dict):
        raise RehearsalError(f"{label} must be a JSON object")
    return value


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _git(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise RehearsalError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout.strip()


def _policy(root: Path) -> dict[str, Any]:
    policy = _load(root / POLICY_PATH, "rehearsal policy")
    if policy.get("schema") != POLICY_SCHEMA or policy.get("enabled") is not True:
        raise RehearsalError("long-term rehearsal policy is disabled or unsupported")
    if policy.get("terminal_effect") != "none":
        raise RehearsalError("rehearsal terminal_effect must remain none")
    markers = policy.get("required_markers")
    if markers != {"simulated": True, "terminal_qualified": False}:
        raise RehearsalError("rehearsal markers must remain simulated=true/terminal_qualified=false")
    hard_rules = policy.get("hard_rules")
    if not isinstance(hard_rules, dict) or any(value is not True for value in hard_rules.values()):
        raise RehearsalError("rehearsal hard rules are incomplete or weakened")
    forbidden = policy.get("forbidden_canonical_outputs")
    if not isinstance(forbidden, list) or not forbidden:
        raise RehearsalError("rehearsal forbidden canonical outputs are missing")
    scopes = policy.get("scopes")
    if not isinstance(scopes, dict) or set(scopes) != {"r2", "longitudinal"}:
        raise RehearsalError("rehearsal scopes must remain exactly r2 + longitudinal")
    return policy


def _real_state(root: Path) -> dict[str, Any]:
    data = _load(root / LTA_PATH, "long-term asset qualification")
    requirements = {
        item.get("id"): item
        for item in data.get("blocking_requirements", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    for key in ("LTA-02", "LTA-04"):
        if key not in requirements:
            raise RehearsalError(f"real long-term asset state is missing {key}")
    terminal = data.get("terminal")
    if not isinstance(terminal, dict):
        raise RehearsalError("real terminal state is missing")
    return {
        "LTA-02": requirements["LTA-02"].get("status"),
        "LTA-04": requirements["LTA-04"].get("status"),
        "terminal_status": terminal.get("status"),
        "terminal_qualified": terminal.get("qualified"),
        "terminal_blockers": terminal.get("blockers"),
    }


def _run_scope(root: Path, name: str, spec: dict[str, Any]) -> dict[str, Any]:
    script_value = spec.get("test")
    if not isinstance(script_value, str) or not script_value:
        raise RehearsalError(f"rehearsal scope {name} has no test")
    script = (root / script_value).resolve()
    try:
        script.relative_to(root)
    except ValueError as exc:
        raise RehearsalError(f"rehearsal scope {name} test escapes repository") from exc
    if not script.is_file() or script.is_symlink():
        raise RehearsalError(f"rehearsal scope {name} test is not a regular file")
    completed = subprocess.run(
        ["bash", str(script)],
        cwd=str(root),
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    tail = completed.stdout.splitlines()[-12:]
    return {
        "status": "pass" if completed.returncode == 0 else "fail",
        "simulated": True,
        "terminal_qualified": False,
        "mode": spec.get("mode"),
        "claim": spec.get("claim"),
        "test": script_value,
        "test_sha256": _sha256(script),
        "exit_code": completed.returncode,
        "output_tail": tail,
    }


def rehearse(root: Path, scope: str) -> dict[str, Any]:
    root = root.resolve()
    policy = _policy(root)
    before = _git(root, "status", "--porcelain=v1", "--untracked-files=all")
    source_head = _git(root, "rev-parse", "HEAD")
    source_tree = _git(root, "rev-parse", "HEAD^{tree}")
    real_before = _real_state(root)

    selected = [scope] if scope != "all" else ["r2", "longitudinal"]
    results: dict[str, Any] = {}
    for name in selected:
        spec = policy["scopes"].get(name)
        if not isinstance(spec, dict):
            raise RehearsalError(f"unknown rehearsal scope: {name}")
        results[name] = _run_scope(root, name, spec)

    real_after = _real_state(root)
    after = _git(root, "status", "--porcelain=v1", "--untracked-files=all")
    if before != after:
        raise RehearsalError("rehearsal changed the repository worktree")
    if real_before != real_after:
        raise RehearsalError("rehearsal changed the real long-term asset state")

    failed = sorted(name for name, result in results.items() if result["status"] != "pass")
    receipt = {
        "schema": SCHEMA,
        "status": "pass" if not failed else "fail",
        "simulated": True,
        "terminal_qualified": False,
        "terminal_effect": "none",
        "scope": scope,
        "source": {
            "head": source_head,
            "tree": source_tree,
            "policy": POLICY_PATH.as_posix(),
            "policy_sha256": _sha256(root / POLICY_PATH),
        },
        "real_state": real_after,
        "worktree_unchanged": True,
        "canonical_evidence_written": False,
        "forbidden_canonical_outputs": policy["forbidden_canonical_outputs"],
        "rehearsals": results,
        "failed_scopes": failed,
    }
    return receipt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="llm-ctl long-term-rehearsal",
        description="Exercise simulated LTA-02 R2 and LTA-04 >=30-day PASS paths without terminal effect.",
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--scope", choices=("all", "r2", "longitudinal"), default="all")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)
    try:
        receipt = rehearse(Path(args.root), args.scope)
    except RehearsalError as exc:
        failure = {
            "schema": SCHEMA,
            "status": "fail",
            "simulated": True,
            "terminal_qualified": False,
            "terminal_effect": "none",
            "error": str(exc),
        }
        print(json.dumps(failure, ensure_ascii=False, sort_keys=True))
        return 1
    if args.summary_json:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    else:
        print(
            "Long-term rehearsal: {} (scope={}, simulated=true, terminal_qualified=false)".format(
                receipt["status"], receipt["scope"]
            )
        )
        for name, result in receipt["rehearsals"].items():
            print(f"- {name}: {result['status']} [{result['mode']}]")
    return 0 if receipt["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
