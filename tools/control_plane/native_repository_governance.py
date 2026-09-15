from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

API_VERSION = "2022-11-28"
CHECK_SCHEMA = "llm-agent-native-repository-governance-check/v2"
DEFAULT_REPOSITORY = "jiying2007/llm_agent"
DEFAULT_RULESET_NAME = "llm_agent main governance"
DEFAULT_REQUIRED_CHECKS = (
    "contract",
    "doc-sync",
    "integration-impact",
    "integration-summary",
    "software-m5-certify",
    "branch-gc",
)
VALID_SCOPES = ("full", "hosted-ruleset")


class GovernanceError(RuntimeError):
    """Live or fixture governance evidence is structurally invalid."""


class GitHubClient:
    def __init__(self, repo: str, token: str | None = None) -> None:
        self.repo = repo
        self.token = token

    def get(self, path: str) -> Any:
        headers = {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": API_VERSION,
            "User-Agent": "llm-agent-native-governance",
        }
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        request = urllib.request.Request(
            f"https://api.github.com{path}",
            headers=headers,
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return json.load(response)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise GovernanceError(
                f"GitHub API GET {path} failed with HTTP {exc.code}: {body}"
            ) from exc
        except urllib.error.URLError as exc:
            raise GovernanceError(f"GitHub API GET {path} failed: {exc}") from exc


def desired_ruleset_payload(
    branch: str = "main",
    ruleset_name: str = DEFAULT_RULESET_NAME,
    required_checks: tuple[str, ...] = DEFAULT_REQUIRED_CHECKS,
) -> dict[str, Any]:
    return {
        "name": ruleset_name,
        "target": "branch",
        "enforcement": "active",
        "bypass_actors": [],
        "conditions": {
            "ref_name": {
                "include": [f"refs/heads/{branch}"],
                "exclude": [],
            }
        },
        "rules": [
            {
                "type": "pull_request",
                "parameters": {
                    "allowed_merge_methods": ["squash"],
                    "dismiss_stale_reviews_on_push": False,
                    "require_code_owner_review": False,
                    "require_last_push_approval": False,
                    "required_approving_review_count": 0,
                    "required_review_thread_resolution": False,
                },
            },
            {
                "type": "required_status_checks",
                "parameters": {
                    "do_not_enforce_on_create": False,
                    "strict_required_status_checks_policy": True,
                    "required_status_checks": [
                        {"context": context} for context in required_checks
                    ],
                },
            },
            {"type": "non_fast_forward"},
            {"type": "deletion"},
        ],
    }


def _targets_branch(
    ruleset: dict[str, Any],
    branch: str,
    default_branch: str,
) -> bool:
    if ruleset.get("target") != "branch" or ruleset.get("enforcement") != "active":
        return False
    conditions = ruleset.get("conditions")
    if not isinstance(conditions, dict):
        return False
    ref_name = conditions.get("ref_name")
    if not isinstance(ref_name, dict):
        return False
    includes = {
        item for item in ref_name.get("include", []) if isinstance(item, str)
    }
    excludes = {
        item for item in ref_name.get("exclude", []) if isinstance(item, str)
    }
    ref = f"refs/heads/{branch}"
    matches = (
        ref in includes
        or branch in includes
        or "~ALL" in includes
        or (branch == default_branch and "~DEFAULT_BRANCH" in includes)
    )
    excluded = (
        ref in excludes
        or branch in excludes
        or "~ALL" in excludes
        or (branch == default_branch and "~DEFAULT_BRANCH" in excludes)
    )
    return matches and not excluded


def _ruleset_evidence(
    rulesets: list[dict[str, Any]],
    branch: str,
    default_branch: str,
) -> dict[str, Any]:
    applicable = [
        ruleset
        for ruleset in rulesets
        if _targets_branch(ruleset, branch, default_branch)
    ]
    rule_types: set[str] = set()
    required_contexts: set[str] = set()
    approval_counts: list[int | None] = []
    merge_methods: list[list[str]] = []
    strict_policies: list[bool | None] = []
    for ruleset in applicable:
        rules = ruleset.get("rules", [])
        if not isinstance(rules, list):
            continue
        for rule in rules:
            if not isinstance(rule, dict):
                continue
            rule_type = rule.get("type")
            if not isinstance(rule_type, str):
                continue
            rule_types.add(rule_type)
            parameters = rule.get("parameters")
            if not isinstance(parameters, dict):
                parameters = {}
            if rule_type == "pull_request":
                count = parameters.get("required_approving_review_count")
                approval_counts.append(count if isinstance(count, int) else None)
                methods = parameters.get("allowed_merge_methods")
                if isinstance(methods, list):
                    merge_methods.append(
                        sorted(item for item in methods if isinstance(item, str))
                    )
                else:
                    merge_methods.append([])
            elif rule_type == "required_status_checks":
                strict = parameters.get("strict_required_status_checks_policy")
                strict_policies.append(strict if isinstance(strict, bool) else None)
                checks = parameters.get("required_status_checks", [])
                if isinstance(checks, list):
                    for check in checks:
                        context = check.get("context") if isinstance(check, dict) else None
                        if isinstance(context, str):
                            required_contexts.add(context)
    return {
        "applicable": applicable,
        "rule_types": rule_types,
        "required_contexts": required_contexts,
        "approval_counts": approval_counts,
        "merge_methods": merge_methods,
        "strict_policies": strict_policies,
    }


def evaluate_state(
    repository: dict[str, Any],
    branch_state: dict[str, Any],
    rulesets: list[dict[str, Any]],
    *,
    branch_name: str = "main",
    required_checks: tuple[str, ...] = DEFAULT_REQUIRED_CHECKS,
    scope: str = "full",
) -> dict[str, Any]:
    if scope not in VALID_SCOPES:
        raise GovernanceError(f"unsupported governance evidence scope: {scope!r}")

    default_branch = str(repository.get("default_branch") or "main")
    evidence = _ruleset_evidence(rulesets, branch_name, default_branch)
    applicable = evidence["applicable"]
    rule_types = evidence["rule_types"]
    required_contexts = evidence["required_contexts"]
    approval_counts = evidence["approval_counts"]
    merge_methods = evidence["merge_methods"]
    strict_policies = evidence["strict_policies"]

    if not isinstance(applicable, list):
        raise GovernanceError("internal ruleset evidence is invalid")
    if not isinstance(rule_types, set) or not isinstance(required_contexts, set):
        raise GovernanceError("internal ruleset evidence sets are invalid")
    if not isinstance(approval_counts, list) or not isinstance(merge_methods, list):
        raise GovernanceError("internal pull-request evidence is invalid")
    if not isinstance(strict_policies, list):
        raise GovernanceError("internal status-check evidence is invalid")

    missing_contexts = sorted(set(required_checks) - required_contexts)
    active_ruleset = bool(applicable)
    pull_request_required = "pull_request" in rule_types
    required_status_checks_present = "required_status_checks" in rule_types
    solo_zero_required_approvals = bool(approval_counts) and all(
        count == 0 for count in approval_counts
    )
    squash_only = bool(merge_methods) and all(
        methods == ["squash"] for methods in merge_methods
    )
    strict_required_status_checks = bool(strict_policies) and all(
        policy is True for policy in strict_policies
    )
    no_ruleset_bypass = bool(applicable) and all(
        not ruleset.get("bypass_actors") for ruleset in applicable
    )

    hosted_checks = {
        "default_branch_is_main": default_branch == branch_name == "main",
        "main_protected": bool(branch_state.get("protected")),
        "active_main_ruleset": active_ruleset,
        "pull_request_required": pull_request_required,
        "solo_zero_required_approvals": solo_zero_required_approvals,
        "no_ruleset_bypass": no_ruleset_bypass,
        "ruleset_squash_only": squash_only,
        "required_status_checks_present": required_status_checks_present,
        "strict_required_status_checks": strict_required_status_checks,
        "all_required_checks_enforced": not missing_contexts,
        "force_push_blocked": "non_fast_forward" in rule_types,
        "branch_deletion_blocked": "deletion" in rule_types,
    }
    full_checks = {
        **hosted_checks,
        "delete_branch_on_merge": repository.get("delete_branch_on_merge") is True,
    }
    checks = full_checks if scope == "full" else hosted_checks

    violations: list[str] = []
    remediation: list[str] = []
    if not hosted_checks["default_branch_is_main"]:
        violations.append("default/main branch identity does not match the LTA-01 contract")
        remediation.append("keep main as the protected default branch")
    if not hosted_checks["main_protected"]:
        violations.append("main is not protected by native GitHub governance")
        remediation.append("create or enable an active native ruleset covering main")
    if not hosted_checks["active_main_ruleset"]:
        violations.append("no active native repository ruleset covers main")
        remediation.append("create the canonical solo-maintainer main ruleset")
    if not hosted_checks["pull_request_required"]:
        violations.append("native ruleset does not require pull requests")
        remediation.append("add a pull_request rule")
    if not hosted_checks["solo_zero_required_approvals"]:
        violations.append("native ruleset does not preserve zero required human approvals")
        remediation.append("set required_approving_review_count to 0")
    if not hosted_checks["no_ruleset_bypass"]:
        violations.append("native ruleset has a bypass actor")
        remediation.append("remove unconditional ruleset bypass actors")
    if not hosted_checks["ruleset_squash_only"]:
        violations.append("native ruleset does not restrict merge methods to squash")
        remediation.append("set allowed merge methods to squash only")
    if not hosted_checks["required_status_checks_present"]:
        violations.append("native ruleset does not require status checks")
        remediation.append("add a required_status_checks rule")
    if not hosted_checks["strict_required_status_checks"]:
        violations.append("required status checks do not require an up-to-date branch")
        remediation.append("enable strict_required_status_checks_policy")
    if missing_contexts:
        violations.append("required status checks missing: " + ", ".join(missing_contexts))
        remediation.append("require every canonical llm_agent PR qualification context")
    if not hosted_checks["force_push_blocked"]:
        violations.append("native ruleset does not block non-fast-forward updates")
        remediation.append("add a non_fast_forward rule")
    if not hosted_checks["branch_deletion_blocked"]:
        violations.append("native ruleset does not block main branch deletion")
        remediation.append("add a deletion rule")
    if scope == "full" and not full_checks["delete_branch_on_merge"]:
        violations.append("native delete_branch_on_merge is not enabled")
        remediation.append("enable delete_branch_on_merge")

    status = "pass" if all(checks.values()) else "blocked_external_admin"
    full_compliant: bool | None = all(full_checks.values()) if scope == "full" else None
    return {
        "schema": CHECK_SCHEMA,
        "scope": scope,
        "status": status,
        "qualification": "LTA-01",
        "implementation_status": "certifier-ready",
        "repository": repository.get("full_name"),
        "branch": branch_name,
        "checks": checks,
        "hosted_checks": hosted_checks,
        "full_checks": full_checks,
        "full_compliant": full_compliant,
        "repository_admin_settings_authoritative": scope == "full",
        "required_status_checks": list(required_checks),
        "observed_status_checks": sorted(required_contexts),
        "missing_status_checks": missing_contexts,
        "observed_required_approval_counts": approval_counts,
        "observed_pull_request_merge_methods": merge_methods,
        "observed_strict_required_status_checks_policies": strict_policies,
        "active_rulesets": [
            {
                "id": ruleset.get("id"),
                "name": ruleset.get("name"),
                "bypass_actors": ruleset.get("bypass_actors", []),
            }
            for ruleset in applicable
        ],
        "violations": violations,
        "remediation": remediation,
        "desired_ruleset": desired_ruleset_payload(
            branch_name,
            DEFAULT_RULESET_NAME,
            required_checks,
        ),
    }


def fetch_live_state(
    repo: str,
    branch_name: str,
    token: str | None,
) -> tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]]]:
    client = GitHubClient(repo, token)
    repository = client.get(f"/repos/{repo}")
    branch = client.get(f"/repos/{repo}/branches/{branch_name}")
    summaries = client.get(f"/repos/{repo}/rulesets")
    if not isinstance(repository, dict) or not isinstance(branch, dict):
        raise GovernanceError("repository or branch response is not an object")
    if not isinstance(summaries, list):
        raise GovernanceError("repository rulesets response is not a list")
    details: list[dict[str, Any]] = []
    for summary in summaries:
        if not isinstance(summary, dict):
            continue
        ruleset_id = summary.get("id")
        if ruleset_id is None:
            continue
        detail = client.get(f"/repos/{repo}/rulesets/{ruleset_id}")
        if not isinstance(detail, dict):
            raise GovernanceError("repository ruleset detail is not an object")
        details.append(detail)
    return repository, branch, details


def load_fixture(path: Path) -> tuple[dict[str, Any], dict[str, Any], list[dict[str, Any]]]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise GovernanceError(f"governance fixture is invalid: {path}") from exc
    if not isinstance(payload, dict):
        raise GovernanceError("governance fixture must be a JSON object")
    repository = payload.get("repository")
    branch = payload.get("branch")
    rulesets = payload.get("rulesets")
    if not isinstance(repository, dict) or not isinstance(branch, dict):
        raise GovernanceError("governance fixture repository/branch must be objects")
    if not isinstance(rulesets, list) or not all(
        isinstance(item, dict) for item in rulesets
    ):
        raise GovernanceError("governance fixture rulesets must be a list of objects")
    return repository, branch, list(rulesets)


def _render(result: dict[str, Any], *, summary_json: bool, out: Path | None) -> None:
    compact = json.dumps(
        result,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    rendered = compact if summary_json else json.dumps(
        result,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    )
    if out:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(
            json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    print(rendered)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Fail-closed LTA-01 native repository governance certifier"
    )
    parser.add_argument(
        "--repo",
        default=os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPOSITORY),
    )
    parser.add_argument("--branch", default="main")
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--required-check", action="append", dest="required_checks")
    parser.add_argument("--scope", choices=VALID_SCOPES, default="full")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)

    required_checks = tuple(args.required_checks or DEFAULT_REQUIRED_CHECKS)
    try:
        if args.fixture:
            repository, branch, rulesets = load_fixture(args.fixture)
        else:
            token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
            repository, branch, rulesets = fetch_live_state(args.repo, args.branch, token)
        result = evaluate_state(
            repository,
            branch,
            rulesets,
            branch_name=args.branch,
            required_checks=required_checks,
            scope=args.scope,
        )
        exit_code = 0 if result["status"] == "pass" else 2
    except (GovernanceError, OSError, ValueError) as exc:
        result = {
            "schema": CHECK_SCHEMA,
            "scope": args.scope,
            "status": "fail",
            "qualification": "LTA-01",
            "error": str(exc),
        }
        exit_code = 1

    _render(result, summary_json=args.summary_json, out=args.out)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
