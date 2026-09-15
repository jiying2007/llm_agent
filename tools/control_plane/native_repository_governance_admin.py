from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

from tools.control_plane.native_repository_governance import (
    DEFAULT_REPOSITORY,
    DEFAULT_REQUIRED_CHECKS,
    DEFAULT_RULESET_NAME,
    desired_ruleset_payload,
    evaluate_state,
)

API_VERSION = "2022-11-28"
RECEIPT_SCHEMA = "llm-agent-native-repository-governance-admin/v1"
TOKEN_ENV = "ADK_GITHUB_ADMIN_TOKEN"


class AdminError(RuntimeError):
    """Raised when an administration plan or apply cannot be trusted."""


class AdminClient:
    def __init__(self, repo: str, token: str) -> None:
        self.repo = repo
        self.token = token

    def request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> Any:
        headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "User-Agent": "llm-agent-native-governance-admin",
            "X-GitHub-Api-Version": API_VERSION,
        }
        data = None if payload is None else json.dumps(payload, separators=(",", ":")).encode("utf-8")
        request = urllib.request.Request(
            f"https://api.github.com{path}",
            headers=headers,
            data=data,
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise AdminError(
                f"GitHub API {method} {path} failed with HTTP {exc.code}: {body}"
            ) from exc
        except urllib.error.URLError as exc:
            raise AdminError(f"GitHub API {method} {path} failed: {exc}") from exc


def _pull_request_state(rule: dict[str, Any]) -> dict[str, Any]:
    parameters = rule.get("parameters")
    if not isinstance(parameters, dict):
        parameters = {}
    return {
        "allowed_merge_methods": sorted(
            item for item in parameters.get("allowed_merge_methods", []) if isinstance(item, str)
        ),
        "dismiss_stale_reviews_on_push": parameters.get("dismiss_stale_reviews_on_push"),
        "require_code_owner_review": parameters.get("require_code_owner_review"),
        "require_last_push_approval": parameters.get("require_last_push_approval"),
        "required_approving_review_count": parameters.get("required_approving_review_count"),
        "required_review_thread_resolution": parameters.get("required_review_thread_resolution"),
    }


def _status_check_state(rule: dict[str, Any]) -> dict[str, Any]:
    parameters = rule.get("parameters")
    if not isinstance(parameters, dict):
        parameters = {}
    checks = sorted(
        item.get("context")
        for item in parameters.get("required_status_checks", [])
        if isinstance(item, dict) and isinstance(item.get("context"), str)
    )
    return {
        "do_not_enforce_on_create": parameters.get("do_not_enforce_on_create", False),
        "required_status_checks": checks,
        "strict_required_status_checks_policy": parameters.get(
            "strict_required_status_checks_policy"
        ),
    }


def normalized_ruleset(ruleset: dict[str, Any]) -> dict[str, Any]:
    rules = ruleset.get("rules", [])
    rule_map = {
        rule.get("type"): rule
        for rule in rules
        if isinstance(rule, dict) and isinstance(rule.get("type"), str)
    }
    return {
        "name": ruleset.get("name"),
        "target": ruleset.get("target"),
        "enforcement": ruleset.get("enforcement"),
        "bypass_actors": ruleset.get("bypass_actors", []),
        "conditions": ruleset.get("conditions", {}),
        "rule_types": sorted(rule_map),
        "pull_request": _pull_request_state(rule_map.get("pull_request", {})),
        "required_status_checks": _status_check_state(
            rule_map.get("required_status_checks", {})
        ),
    }


def _find_managed_ruleset(
    rulesets: list[dict[str, Any]], ruleset_name: str
) -> dict[str, Any] | None:
    matches = [item for item in rulesets if item.get("name") == ruleset_name]
    if len(matches) > 1:
        ids = [item.get("id") for item in matches]
        raise AdminError(f"multiple managed rulesets named {ruleset_name!r}: {ids}")
    return matches[0] if matches else None


def fetch_state(
    client: AdminClient, repo: str, branch: str
) -> tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]]]:
    repository = client.request("GET", f"/repos/{repo}")
    branch_state = client.request("GET", f"/repos/{repo}/branches/{branch}")
    summaries = client.request("GET", f"/repos/{repo}/rulesets")
    if not isinstance(repository, dict) or not isinstance(branch_state, dict):
        raise AdminError("repository or branch administration response is invalid")
    if not isinstance(summaries, list):
        raise AdminError("repository rulesets response is not a list")
    details: list[dict[str, Any]] = []
    for summary in summaries:
        if not isinstance(summary, dict) or summary.get("id") is None:
            continue
        detail = client.request("GET", f"/repos/{repo}/rulesets/{summary['id']}")
        if not isinstance(detail, dict):
            raise AdminError("repository ruleset detail is not an object")
        details.append(detail)
    return repository, branch_state, details


def build_plan(
    repository: dict[str, Any],
    branch_state: dict[str, Any],
    rulesets: list[dict[str, Any]],
    *,
    branch: str,
    ruleset_name: str,
    required_checks: tuple[str, ...] = DEFAULT_REQUIRED_CHECKS,
) -> dict[str, Any]:
    if repository.get("delete_branch_on_merge") is not True:
        raise AdminError(
            "full-scope prerequisite delete_branch_on_merge=true is not satisfied; "
            "repair the repository setting before applying the LTA-01 ruleset"
        )
    desired = desired_ruleset_payload(branch, ruleset_name, required_checks)
    managed = _find_managed_ruleset(rulesets, ruleset_name)
    if managed is None:
        action = "create"
        managed_id = None
    elif normalized_ruleset(managed) == normalized_ruleset(desired):
        action = "none"
        managed_id = managed.get("id")
    else:
        action = "update"
        managed_id = managed.get("id")
    return {
        "schema": RECEIPT_SCHEMA,
        "mode": "plan",
        "repository": repository.get("full_name"),
        "branch": branch,
        "repository_prerequisites": {"delete_branch_on_merge": True},
        "current_governance": evaluate_state(
            repository,
            branch_state,
            rulesets,
            branch_name=branch,
            required_checks=required_checks,
            scope="full",
        ),
        "ruleset": {
            "name": ruleset_name,
            "action": action,
            "id": managed_id,
            "desired": desired,
        },
    }


def _git(*args: str) -> str:
    try:
        completed = subprocess.run(
            ["git", *args],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise AdminError("git is required for --apply checkout verification") from exc
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip() or str(completed.returncode)
        raise AdminError(f"git {' '.join(args)} failed: {detail}")
    return completed.stdout.strip()


def _repo_from_remote(remote: str) -> str | None:
    value = remote.strip()
    if value.startswith("git@github.com:"):
        path = value[len("git@github.com:") :]
    else:
        parsed = urllib.parse.urlparse(value)
        if parsed.hostname != "github.com":
            return None
        path = parsed.path.lstrip("/")
    if path.endswith(".git"):
        path = path[:-4]
    return path or None


def validate_local_checkout(
    repo: str,
    branch: str,
    branch_state: dict[str, Any],
    observed: dict[str, str] | None = None,
) -> dict[str, Any]:
    local = dict(
        observed
        or {
            "branch": _git("branch", "--show-current"),
            "head_sha": _git("rev-parse", "HEAD"),
            "status": _git("status", "--porcelain"),
            "origin": _git("remote", "get-url", "origin"),
        }
    )
    remote_sha = branch_state.get("commit", {}).get("sha")
    if not isinstance(remote_sha, str) or not remote_sha:
        raise AdminError("live GitHub branch state has no commit SHA")
    problems: list[str] = []
    if local.get("branch") != branch:
        problems.append(f"local branch is {local.get('branch')!r}, expected {branch!r}")
    if local.get("head_sha") != remote_sha:
        problems.append(
            f"local HEAD {local.get('head_sha')!r} does not match live {branch} {remote_sha!r}"
        )
    if local.get("status"):
        problems.append("local working tree is not clean")
    origin_repo = _repo_from_remote(str(local.get("origin") or ""))
    if origin_repo is None or origin_repo.lower() != repo.lower():
        problems.append(f"origin {local.get('origin')!r} does not identify {repo!r}")
    if problems:
        raise AdminError("unsafe local checkout for --apply: " + "; ".join(problems))
    return {
        "branch": branch,
        "head_sha": local.get("head_sha"),
        "remote_branch_sha": remote_sha,
        "origin": local.get("origin"),
        "repository": origin_repo,
        "worktree_clean": True,
    }


def apply_plan(
    client: AdminClient, repo: str, plan: dict[str, Any]
) -> list[dict[str, Any]]:
    ruleset = plan["ruleset"]
    action = ruleset["action"]
    if action == "create":
        created = client.request("POST", f"/repos/{repo}/rulesets", ruleset["desired"])
        return [{"operation": "create_ruleset", "id": created.get("id")}]
    if action == "update":
        ruleset_id = ruleset.get("id")
        if ruleset_id is None:
            raise AdminError("managed ruleset update has no ruleset id")
        client.request("PUT", f"/repos/{repo}/rulesets/{ruleset_id}", ruleset["desired"])
        return [{"operation": "update_ruleset", "id": ruleset_id}]
    if action == "none":
        return []
    raise AdminError(f"unsupported ruleset action: {action!r}")


def _render(payload: dict[str, Any], out: Path | None) -> None:
    text = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if out:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text, encoding="utf-8")
    sys.stdout.write(text)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Plan/apply the canonical solo-maintainer LTA-01 ruleset from a trusted local checkout."
    )
    parser.add_argument("--repo", default=DEFAULT_REPOSITORY)
    parser.add_argument("--branch", default="main")
    parser.add_argument("--ruleset-name", default=DEFAULT_RULESET_NAME)
    parser.add_argument("--required-check", action="append", dest="required_checks")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)

    token = os.environ.get(TOKEN_ENV)
    if not token:
        parser.error(
            f"{TOKEN_ENV} with repository Administration read/write is required for authoritative plan/apply"
        )
    if args.apply and os.environ.get("GITHUB_ACTIONS", "").lower() == "true":
        parser.error("--apply refuses to run inside GitHub Actions")

    required_checks = tuple(args.required_checks or DEFAULT_REQUIRED_CHECKS)
    try:
        client = AdminClient(args.repo, token)
        repository, branch_state, rulesets = fetch_state(client, args.repo, args.branch)
        plan = build_plan(
            repository,
            branch_state,
            rulesets,
            branch=args.branch,
            ruleset_name=args.ruleset_name,
            required_checks=required_checks,
        )
        if not args.apply:
            _render(plan, args.out)
            return 0 if plan["ruleset"]["action"] == "none" else 2

        checkout = validate_local_checkout(args.repo, args.branch, branch_state)
        operations = apply_plan(client, args.repo, plan)
        after_repository, after_branch, after_rulesets = fetch_state(
            client, args.repo, args.branch
        )
        verification = evaluate_state(
            after_repository,
            after_branch,
            after_rulesets,
            branch_name=args.branch,
            required_checks=required_checks,
            scope="full",
        )
        receipt = {
            "schema": RECEIPT_SCHEMA,
            "mode": "apply",
            "repository": args.repo,
            "branch": args.branch,
            "checkout": checkout,
            "plan": plan,
            "operations": operations,
            "verification": verification,
        }
        _render(receipt, args.out)
        return 0 if verification.get("status") == "pass" else 1
    except (AdminError, OSError, ValueError, json.JSONDecodeError) as exc:
        payload = {
            "schema": RECEIPT_SCHEMA,
            "mode": "apply" if args.apply else "plan",
            "status": "fail",
            "error": str(exc),
        }
        _render(payload, args.out)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
