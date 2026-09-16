#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class BranchGCError(RuntimeError):
    pass


@dataclass(frozen=True)
class Candidate:
    branch: str
    sha: str
    basis: str
    registry_reason: str | None = None

    def as_dict(self) -> dict[str, Any]:
        value: dict[str, Any] = {
            "branch": self.branch,
            "sha": self.sha,
            "basis": self.basis,
        }
        if self.registry_reason is not None:
            value["registry_reason"] = self.registry_reason
        return value


class GitHubClient:
    def __init__(self, repo: str, token: str) -> None:
        if "/" not in repo:
            raise BranchGCError("repository must use owner/name")
        if not token:
            raise BranchGCError("GitHub token is required")
        self.repo = repo
        self.owner = repo.split("/", 1)[0]
        self.token = token
        self.base_url = f"https://api.github.com/repos/{repo}"

    def request(
        self,
        method: str,
        path: str,
        query: dict[str, str] | None = None,
    ) -> Any:
        url = self.base_url + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        req = urllib.request.Request(
            url,
            method=method,
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {self.token}",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "llm-agent-branch-gc",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise BranchGCError(
                f"GitHub API {method} {path} failed: HTTP {exc.code}: {detail}"
            ) from exc
        except urllib.error.URLError as exc:
            raise BranchGCError(f"GitHub API {method} {path} failed: {exc}") from exc

    def list_branches(self) -> list[dict[str, Any]]:
        out: list[dict[str, Any]] = []
        page = 1
        while True:
            batch = self.request(
                "GET", "/branches", {"per_page": "100", "page": str(page)}
            )
            if not isinstance(batch, list):
                raise BranchGCError("branches response is not a list")
            out.extend(x for x in batch if isinstance(x, dict))
            if len(batch) < 100:
                return out
            page += 1

    def get_branch(self, branch: str) -> dict[str, Any]:
        value = self.request(
            "GET", "/branches/" + urllib.parse.quote(branch, safe="")
        )
        if not isinstance(value, dict):
            raise BranchGCError(f"invalid branch response: {branch}")
        return value

    def pulls(self, branch: str, base: str, state: str) -> list[dict[str, Any]]:
        value = self.request(
            "GET",
            "/pulls",
            {
                "state": state,
                "head": f"{self.owner}:{branch}",
                "base": base,
                "per_page": "100",
            },
        )
        if not isinstance(value, list):
            raise BranchGCError(f"invalid pull response: {branch}")
        return [x for x in value if isinstance(x, dict)]

    def compare_sha_to_base(self, sha: str, base: str) -> dict[str, Any]:
        value = self.request(
            "GET", f"/compare/{sha}...{urllib.parse.quote(base, safe='')}"
        )
        if not isinstance(value, dict):
            raise BranchGCError(f"invalid compare response for {sha}...{base}")
        return value

    def compare_base_to_sha(self, base: str, sha: str) -> dict[str, Any]:
        value = self.request(
            "GET", f"/compare/{urllib.parse.quote(base, safe='')}...{sha}"
        )
        if not isinstance(value, dict):
            raise BranchGCError(f"invalid compare response for {base}...{sha}")
        return value

    def content_sha(self, path: str, ref: str) -> str:
        value = self.request(
            "GET",
            "/contents/" + urllib.parse.quote(path, safe="/"),
            {"ref": ref},
        )
        if not isinstance(value, dict) or not isinstance(value.get("sha"), str):
            raise BranchGCError(f"invalid content response for {path}@{ref}")
        return value["sha"]

    def workflow_run(self, run_id: int) -> dict[str, Any]:
        value = self.request("GET", f"/actions/runs/{run_id}")
        if not isinstance(value, dict):
            raise BranchGCError(f"invalid workflow run response: {run_id}")
        return value

    def delete_branch(self, branch: str) -> None:
        self.request(
            "DELETE", "/git/refs/heads/" + urllib.parse.quote(branch, safe="/")
        )


def branch_sha(branch: dict[str, Any]) -> str:
    commit = branch.get("commit")
    sha = commit.get("sha") if isinstance(commit, dict) else None
    if not isinstance(sha, str) or len(sha) != 40:
        raise BranchGCError("branch SHA is missing or invalid")
    return sha


def valid_repo_path(file_path: Any) -> bool:
    return (
        isinstance(file_path, str)
        and bool(file_path)
        and not file_path.startswith("/")
        and ".." not in Path(file_path).parts
    )


def valid_sha(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 40


def validate_run_contract(branch: str, label: str, value: Any) -> None:
    if not isinstance(value, dict):
        raise BranchGCError(f"terminal-probe {label} is missing: {branch}")
    if not isinstance(value.get("id"), int) or value["id"] < 1:
        raise BranchGCError(f"terminal-probe {label} id is invalid: {branch}")
    if not isinstance(value.get("name"), str) or not value["name"]:
        raise BranchGCError(f"terminal-probe {label} name is invalid: {branch}")
    if not valid_repo_path(value.get("path")) or not str(value["path"]).startswith(
        ".github/workflows/"
    ):
        raise BranchGCError(f"terminal-probe {label} path is invalid: {branch}")
    if not isinstance(value.get("head_branch"), str) or not value["head_branch"]:
        raise BranchGCError(f"terminal-probe {label} head_branch is invalid: {branch}")
    if not valid_sha(value.get("head_sha")):
        raise BranchGCError(f"terminal-probe {label} head_sha is invalid: {branch}")
    if value.get("status") != "completed":
        raise BranchGCError(f"terminal-probe {label} status must be completed: {branch}")
    if not isinstance(value.get("conclusion"), str) or not value["conclusion"]:
        raise BranchGCError(f"terminal-probe {label} conclusion is invalid: {branch}")
    if not isinstance(value.get("event"), str) or not value["event"]:
        raise BranchGCError(f"terminal-probe {label} event is invalid: {branch}")


def load_retired_registry(path: Path | None) -> dict[str, dict[str, Any]]:
    if path is None:
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BranchGCError(f"invalid retired registry: {path}") from exc
    if (
        not isinstance(payload, dict)
        or payload.get("schema") != "llm-agent-branch-gc-retired/v1"
    ):
        raise BranchGCError("unsupported retired registry schema")
    entries = payload.get("entries")
    if not isinstance(entries, list):
        raise BranchGCError("retired registry entries must be a list")
    result: dict[str, dict[str, Any]] = {}
    for item in entries:
        if not isinstance(item, dict):
            raise BranchGCError("retired registry entry must be an object")
        branch, sha = item.get("branch"), item.get("sha")
        if not isinstance(branch, str) or not branch or branch in {"main", "master"}:
            raise BranchGCError("retired registry branch is invalid")
        if not valid_sha(sha):
            raise BranchGCError(f"retired registry SHA is invalid: {branch}")
        if item.get("disposition") != "delete":
            raise BranchGCError(f"retired registry disposition is invalid: {branch}")
        proof = item.get("proof")
        if proof not in {"ancestor-of-main", "absorbed-path-blobs", "terminal-probe"}:
            raise BranchGCError(f"retired registry proof is invalid: {branch}")
        reason = item.get("reason")
        if not isinstance(reason, str) or not reason:
            raise BranchGCError(f"retired registry reason is missing: {branch}")
        if proof == "absorbed-path-blobs":
            count = item.get("unique_commit_count")
            paths = item.get("paths")
            if not isinstance(count, int) or count < 1:
                raise BranchGCError(
                    f"absorbed-path-blobs unique_commit_count is invalid: {branch}"
                )
            if not isinstance(paths, dict) or not paths:
                raise BranchGCError(f"absorbed-path-blobs paths are missing: {branch}")
            for file_path, blob_sha in paths.items():
                if not valid_repo_path(file_path):
                    raise BranchGCError(
                        f"absorbed-path-blobs path is invalid: {branch}"
                    )
                if not valid_sha(blob_sha):
                    raise BranchGCError(
                        f"absorbed-path-blobs SHA is invalid: {branch}:{file_path}"
                    )
        if proof == "terminal-probe":
            if item.get("unique_commit_count") != 1:
                raise BranchGCError(
                    f"terminal-probe unique_commit_count must be 1: {branch}"
                )
            file_path = item.get("path")
            if not valid_repo_path(file_path) or not str(file_path).startswith(
                ".github/workflows/"
            ):
                raise BranchGCError(f"terminal-probe path is invalid: {branch}")
            name = Path(str(file_path)).name.lower()
            if "probe" not in name or Path(str(file_path)).suffix not in {".yml", ".yaml"}:
                raise BranchGCError(
                    f"terminal-probe path is outside probe workflow namespace: {branch}"
                )
            if not valid_sha(item.get("blob_sha")):
                raise BranchGCError(f"terminal-probe blob_sha is invalid: {branch}")
            validate_run_contract(branch, "probe_run", item.get("probe_run"))
            validate_run_contract(branch, "superseding_run", item.get("superseding_run"))
            probe_run = item["probe_run"]
            superseding_run = item["superseding_run"]
            if (
                probe_run["head_branch"] != branch
                or probe_run["head_sha"] != sha
                or probe_run["path"] != file_path
            ):
                raise BranchGCError(
                    f"terminal-probe probe_run identity is invalid: {branch}"
                )
            if (
                superseding_run["head_branch"] not in {"main", "master"}
                or superseding_run["conclusion"] != "success"
            ):
                raise BranchGCError(
                    f"terminal-probe superseding_run must be successful main/master evidence: {branch}"
                )
        if branch in result:
            raise BranchGCError(f"duplicate retired registry branch: {branch}")
        result[branch] = item
    return result


def open_prs(client: GitHubClient, branch: str, base: str) -> list[int]:
    return sorted(
        pr["number"]
        for pr in client.pulls(branch, base, "open")
        if isinstance(pr.get("number"), int)
    )


def contained_in_base(client: GitHubClient, sha: str, base: str) -> bool:
    comparison = client.compare_sha_to_base(sha, base)
    merge_base = comparison.get("merge_base_commit")
    merge_sha = merge_base.get("sha") if isinstance(merge_base, dict) else None
    return (
        merge_sha == sha
        and comparison.get("behind_by") == 0
        and comparison.get("status") in {"ahead", "identical"}
    )


def absorbed_paths_match(
    client: GitHubClient,
    sha: str,
    base: str,
    retirement: dict[str, Any],
) -> bool:
    comparison = client.compare_base_to_sha(base, sha)
    expected_count = retirement["unique_commit_count"]
    if comparison.get("ahead_by") != expected_count:
        return False
    files = comparison.get("files")
    if not isinstance(files, list):
        return False
    actual_paths = {
        item.get("filename")
        for item in files
        if isinstance(item, dict) and isinstance(item.get("filename"), str)
    }
    expected_paths = set(retirement["paths"])
    if actual_paths != expected_paths:
        return False
    for path, expected_blob in retirement["paths"].items():
        if client.content_sha(path, sha) != expected_blob:
            return False
        if client.content_sha(path, base) != expected_blob:
            return False
    return True


def workflow_run_matches(
    client: GitHubClient,
    expected: dict[str, Any],
) -> tuple[bool, dict[str, Any]]:
    actual = client.workflow_run(expected["id"])
    for key in (
        "name",
        "path",
        "head_branch",
        "head_sha",
        "status",
        "conclusion",
        "event",
    ):
        if actual.get(key) != expected[key]:
            return False, actual
    return True, actual


def terminal_probe_match(
    client: GitHubClient,
    sha: str,
    base: str,
    retirement: dict[str, Any],
) -> bool:
    comparison = client.compare_base_to_sha(base, sha)
    if comparison.get("ahead_by") != 1:
        return False
    commits = comparison.get("commits")
    if (
        not isinstance(commits, list)
        or len(commits) != 1
        or not isinstance(commits[0], dict)
        or commits[0].get("sha") != sha
    ):
        return False
    files = comparison.get("files")
    if not isinstance(files, list):
        return False
    actual_paths = {
        item.get("filename")
        for item in files
        if isinstance(item, dict) and isinstance(item.get("filename"), str)
    }
    expected_path = retirement["path"]
    if actual_paths != {expected_path}:
        return False
    if client.content_sha(expected_path, sha) != retirement["blob_sha"]:
        return False
    probe_ok, probe = workflow_run_matches(client, retirement["probe_run"])
    if not probe_ok:
        return False
    superseding_ok, superseding = workflow_run_matches(
        client, retirement["superseding_run"]
    )
    if not superseding_ok:
        return False
    probe_time = probe.get("updated_at") or probe.get("created_at")
    superseding_time = superseding.get("created_at")
    if (
        not isinstance(probe_time, str)
        or not isinstance(superseding_time, str)
        or superseding_time <= probe_time
    ):
        return False
    superseding_sha = retirement["superseding_run"]["head_sha"]
    if not contained_in_base(client, superseding_sha, base):
        return False
    return True


def retirement_safe(
    client: GitHubClient,
    sha: str,
    base: str,
    retirement: dict[str, Any],
) -> bool:
    proof = retirement["proof"]
    if proof == "ancestor-of-main":
        return contained_in_base(client, sha, base)
    if proof == "absorbed-path-blobs":
        return absorbed_paths_match(client, sha, base, retirement)
    if proof == "terminal-probe":
        return terminal_probe_match(client, sha, base, retirement)
    return False


def eligible(
    client: GitHubClient,
    branch: dict[str, Any],
    base: str,
    prefixes: tuple[str, ...],
    protected: set[str],
    retired: dict[str, dict[str, Any]],
) -> tuple[Candidate | None, str]:
    name = branch.get("name")
    if not isinstance(name, str) or not name:
        return None, "invalid-name"
    if name in protected or name == base:
        return None, "protected-name"
    if not any(name.startswith(prefix) for prefix in prefixes):
        return None, "prefix-not-allowed"
    if branch.get("protected") is True:
        return None, "github-protected"
    sha = branch_sha(branch)
    current_open = open_prs(client, name, base)
    if current_open:
        return None, "open-pr:" + ",".join(map(str, current_open))
    retirement = retired.get(name)
    if retirement is None:
        return None, "not-explicitly-retired"
    if retirement["sha"] != sha:
        return None, "retired-sha-mismatch"
    if not retirement_safe(client, sha, base, retirement):
        return None, "retired-proof-no-longer-valid"
    return (
        Candidate(
            name,
            sha,
            "explicit-retired-" + retirement["proof"],
            registry_reason=retirement["reason"],
        ),
        "eligible",
    )


def revalidate(
    client: GitHubClient,
    candidate: Candidate,
    base: str,
    retired: dict[str, dict[str, Any]],
) -> tuple[bool, str]:
    current = client.get_branch(candidate.branch)
    if current.get("protected") is True:
        return False, "github-protected"
    if branch_sha(current) != candidate.sha:
        return False, "sha-changed"
    current_open = open_prs(client, candidate.branch, base)
    if current_open:
        return False, "open-pr:" + ",".join(map(str, current_open))
    if not candidate.basis.startswith("explicit-retired-"):
        return False, "non-retirement-candidate"
    retirement = retired.get(candidate.branch)
    if retirement is None or retirement.get("sha") != candidate.sha:
        return False, "retired-registry-changed"
    if not retirement_safe(client, candidate.sha, base, retirement):
        return False, "retired-proof-no-longer-valid"
    return True, "eligible"


def run(
    client: GitHubClient,
    apply: bool,
    base: str,
    prefixes: tuple[str, ...],
    protected: set[str],
    retired: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    if not prefixes or any(not prefix for prefix in prefixes):
        raise BranchGCError("at least one non-empty prefix is required")
    candidates: list[Candidate] = []
    skipped: list[dict[str, Any]] = []
    for branch in client.list_branches():
        candidate, reason = eligible(
            client, branch, base, prefixes, protected, retired
        )
        name = branch.get("name")
        if candidate is None:
            if isinstance(name, str) and any(
                name.startswith(prefix) for prefix in prefixes
            ):
                skipped.append(
                    {"branch": name, "sha": branch_sha(branch), "reason": reason}
                )
        else:
            candidates.append(candidate)
    candidates.sort(key=lambda item: item.branch)
    deleted: list[dict[str, Any]] = []
    revalidation_skips: list[dict[str, Any]] = []
    if apply:
        for candidate in candidates:
            ok, reason = revalidate(client, candidate, base, retired)
            if not ok:
                revalidation_skips.append(
                    {
                        "branch": candidate.branch,
                        "sha": candidate.sha,
                        "basis": candidate.basis,
                        "reason": reason,
                    }
                )
                continue
            client.delete_branch(candidate.branch)
            deleted.append(candidate.as_dict())
    return {
        "schema": "llm-agent-branch-gc-report/v1",
        "repository": client.repo,
        "base": base,
        "mode": "apply" if apply else "dry-run",
        "prefixes": list(prefixes),
        "protected_names": sorted(protected),
        "retired_registry_entries": len(retired),
        "candidate_policy": "explicit-retirement-only",
        "candidates": [candidate.as_dict() for candidate in candidates],
        "deleted": deleted,
        "revalidation_skips": revalidation_skips,
        "skipped": sorted(skipped, key=lambda item: item["branch"]),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="branch-gc")
    parser.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY", ""))
    parser.add_argument("--token", default=os.getenv("GITHUB_TOKEN", ""))
    parser.add_argument("--base", default="main")
    parser.add_argument("--prefix", action="append", default=[])
    parser.add_argument("--protected", action="append", default=[])
    parser.add_argument("--retired-registry")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--report", required=True)
    args = parser.parse_args(argv)
    path = Path(args.report)
    try:
        retired_path = Path(args.retired_registry) if args.retired_registry else None
        retired = load_retired_registry(retired_path)
        report = run(
            GitHubClient(args.repo, args.token),
            args.apply,
            args.base,
            tuple(args.prefix),
            set(args.protected) | {"main", "master"},
            retired,
        )
        report["status"] = "pass"
        return_code = 0
    except BranchGCError as exc:
        report = {
            "schema": "llm-agent-branch-gc-report/v1",
            "repository": args.repo,
            "base": args.base,
            "mode": "apply" if args.apply else "dry-run",
            "status": "fail",
            "error": str(exc),
        }
        return_code = 1
    path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
    return return_code


if __name__ == "__main__":
    raise SystemExit(main())
