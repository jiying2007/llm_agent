#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, os, urllib.error, urllib.parse, urllib.request
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
    pr_number: int | None = None
    merged_at: str | None = None
    registry_reason: str | None = None

    def as_dict(self) -> dict[str, Any]:
        value: dict[str, Any] = {"branch": self.branch, "sha": self.sha, "basis": self.basis}
        if self.pr_number is not None:
            value["merged_pr"] = self.pr_number
        if self.merged_at is not None:
            value["merged_at"] = self.merged_at
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

    def request(self, method: str, path: str, query: dict[str, str] | None = None) -> Any:
        url = self.base_url + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        req = urllib.request.Request(url, method=method, headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {self.token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "llm-agent-branch-gc",
        })
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                body = resp.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise BranchGCError(f"GitHub API {method} {path} failed: HTTP {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise BranchGCError(f"GitHub API {method} {path} failed: {exc}") from exc

    def list_branches(self) -> list[dict[str, Any]]:
        out: list[dict[str, Any]] = []
        page = 1
        while True:
            batch = self.request("GET", "/branches", {"per_page": "100", "page": str(page)})
            if not isinstance(batch, list):
                raise BranchGCError("branches response is not a list")
            out.extend(x for x in batch if isinstance(x, dict))
            if len(batch) < 100:
                return out
            page += 1

    def get_branch(self, branch: str) -> dict[str, Any]:
        value = self.request("GET", "/branches/" + urllib.parse.quote(branch, safe=""))
        if not isinstance(value, dict):
            raise BranchGCError(f"invalid branch response: {branch}")
        return value

    def pulls(self, branch: str, base: str, state: str) -> list[dict[str, Any]]:
        value = self.request("GET", "/pulls", {
            "state": state,
            "head": f"{self.owner}:{branch}",
            "base": base,
            "per_page": "100",
        })
        if not isinstance(value, list):
            raise BranchGCError(f"invalid pull response: {branch}")
        return [x for x in value if isinstance(x, dict)]

    def compare_sha_to_base(self, sha: str, base: str) -> dict[str, Any]:
        value = self.request("GET", f"/compare/{sha}...{urllib.parse.quote(base, safe='')}")
        if not isinstance(value, dict):
            raise BranchGCError(f"invalid compare response for {sha}...{base}")
        return value

    def delete_branch(self, branch: str) -> None:
        self.request("DELETE", "/git/refs/heads/" + urllib.parse.quote(branch, safe="/"))

def branch_sha(branch: dict[str, Any]) -> str:
    commit = branch.get("commit")
    sha = commit.get("sha") if isinstance(commit, dict) else None
    if not isinstance(sha, str) or len(sha) != 40:
        raise BranchGCError("branch SHA is missing or invalid")
    return sha

def load_retired_registry(path: Path | None) -> dict[str, dict[str, str]]:
    if path is None:
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BranchGCError(f"invalid retired registry: {path}") from exc
    if not isinstance(payload, dict) or payload.get("schema") != "llm-agent-branch-gc-retired/v1":
        raise BranchGCError("unsupported retired registry schema")
    entries = payload.get("entries")
    if not isinstance(entries, list):
        raise BranchGCError("retired registry entries must be a list")
    result: dict[str, dict[str, str]] = {}
    for item in entries:
        if not isinstance(item, dict):
            raise BranchGCError("retired registry entry must be an object")
        branch, sha = item.get("branch"), item.get("sha")
        if not isinstance(branch, str) or not branch.startswith("codex/"):
            raise BranchGCError("retired registry branch must use codex/*")
        if not isinstance(sha, str) or len(sha) != 40:
            raise BranchGCError(f"retired registry SHA is invalid: {branch}")
        if item.get("disposition") != "delete" or item.get("proof") != "ancestor-of-main":
            raise BranchGCError(f"retired registry disposition/proof is invalid: {branch}")
        reason = item.get("reason")
        if not isinstance(reason, str) or not reason:
            raise BranchGCError(f"retired registry reason is missing: {branch}")
        if branch in result:
            raise BranchGCError(f"duplicate retired registry branch: {branch}")
        result[branch] = {"sha": sha, "reason": reason}
    return result

def open_prs(client: GitHubClient, branch: str, base: str) -> list[int]:
    return sorted(
        pr["number"] for pr in client.pulls(branch, base, "open")
        if isinstance(pr.get("number"), int)
    )

def exact_merged_pr(client: GitHubClient, branch: str, sha: str, base: str) -> Candidate | None:
    matches: list[Candidate] = []
    for pr in client.pulls(branch, base, "closed"):
        head, base_obj = pr.get("head"), pr.get("base")
        if not isinstance(head, dict) or not isinstance(base_obj, dict) or pr.get("merged_at") is None:
            continue
        if head.get("ref") != branch or head.get("sha") != sha or base_obj.get("ref") != base:
            continue
        if isinstance(pr.get("number"), int) and isinstance(pr.get("merged_at"), str):
            matches.append(Candidate(branch, sha, "exact-merged-pr", pr["number"], pr["merged_at"]))
    if not matches:
        return None
    return sorted(matches, key=lambda x: (x.merged_at or "", x.pr_number or 0), reverse=True)[0]

def contained_in_base(client: GitHubClient, sha: str, base: str) -> bool:
    comparison = client.compare_sha_to_base(sha, base)
    merge_base = comparison.get("merge_base_commit")
    merge_sha = merge_base.get("sha") if isinstance(merge_base, dict) else None
    return merge_sha == sha and comparison.get("behind_by") == 0 and comparison.get("status") in {"ahead", "identical"}

def eligible(client: GitHubClient, branch: dict[str, Any], base: str, prefixes: tuple[str, ...], protected: set[str], retired: dict[str, dict[str, str]]) -> tuple[Candidate | None, str]:
    name = branch.get("name")
    if not isinstance(name, str) or not name:
        return None, "invalid-name"
    if name in protected or name == base:
        return None, "protected-name"
    if not any(name.startswith(p) for p in prefixes):
        return None, "prefix-not-allowed"
    if branch.get("protected") is True:
        return None, "github-protected"
    sha = branch_sha(branch)
    current_open = open_prs(client, name, base)
    if current_open:
        return None, "open-pr:" + ",".join(map(str, current_open))
    merged = exact_merged_pr(client, name, sha, base)
    if merged is not None:
        return merged, "eligible"
    retirement = retired.get(name)
    if retirement is None:
        return None, "no-exact-merged-pr"
    if retirement["sha"] != sha:
        return None, "retired-sha-mismatch"
    if not contained_in_base(client, sha, base):
        return None, "retired-not-contained-in-base"
    return Candidate(name, sha, "explicit-retired-ancestor", registry_reason=retirement["reason"]), "eligible"

def revalidate(client: GitHubClient, c: Candidate, base: str, retired: dict[str, dict[str, str]]) -> tuple[bool, str]:
    current = client.get_branch(c.branch)
    if current.get("protected") is True:
        return False, "github-protected"
    if branch_sha(current) != c.sha:
        return False, "sha-changed"
    current_open = open_prs(client, c.branch, base)
    if current_open:
        return False, "open-pr:" + ",".join(map(str, current_open))
    if c.basis == "exact-merged-pr":
        if exact_merged_pr(client, c.branch, c.sha, base) is None:
            return False, "merged-pr-no-longer-exact"
        return True, "eligible"
    if c.basis == "explicit-retired-ancestor":
        retirement = retired.get(c.branch)
        if retirement is None or retirement.get("sha") != c.sha:
            return False, "retired-registry-changed"
        if not contained_in_base(client, c.sha, base):
            return False, "retired-no-longer-contained-in-base"
        return True, "eligible"
    return False, "unknown-candidate-basis"

def run(client: GitHubClient, apply: bool, base: str, prefixes: tuple[str, ...], protected: set[str], retired: dict[str, dict[str, str]]) -> dict[str, Any]:
    if not prefixes or any(not p for p in prefixes):
        raise BranchGCError("at least one non-empty prefix is required")
    candidates: list[Candidate] = []
    skipped: list[dict[str, Any]] = []
    for branch in client.list_branches():
        c, reason = eligible(client, branch, base, prefixes, protected, retired)
        name = branch.get("name")
        if c is None:
            if isinstance(name, str) and any(name.startswith(p) for p in prefixes):
                skipped.append({"branch": name, "sha": branch_sha(branch), "reason": reason})
        else:
            candidates.append(c)
    candidates.sort(key=lambda x: x.branch)
    deleted, revalidation_skips = [], []
    if apply:
        for c in candidates:
            ok, reason = revalidate(client, c, base, retired)
            if not ok:
                revalidation_skips.append({"branch": c.branch, "sha": c.sha, "basis": c.basis, "reason": reason})
                continue
            client.delete_branch(c.branch)
            deleted.append(c.as_dict())
    return {
        "schema": "llm-agent-branch-gc-report/v1",
        "repository": client.repo,
        "base": base,
        "mode": "apply" if apply else "dry-run",
        "prefixes": list(prefixes),
        "protected_names": sorted(protected),
        "retired_registry_entries": len(retired),
        "candidates": [c.as_dict() for c in candidates],
        "deleted": deleted,
        "revalidation_skips": revalidation_skips,
        "skipped": sorted(skipped, key=lambda x: x["branch"]),
    }

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="branch-gc")
    p.add_argument("--repo", default=os.getenv("GITHUB_REPOSITORY", ""))
    p.add_argument("--token", default=os.getenv("GITHUB_TOKEN", ""))
    p.add_argument("--base", default="main")
    p.add_argument("--prefix", action="append", default=[])
    p.add_argument("--protected", action="append", default=[])
    p.add_argument("--retired-registry")
    p.add_argument("--apply", action="store_true")
    p.add_argument("--report", required=True)
    a = p.parse_args(argv)
    path = Path(a.report)
    try:
        retired_path = Path(a.retired_registry) if a.retired_registry else None
        retired = load_retired_registry(retired_path)
        report = run(GitHubClient(a.repo, a.token), a.apply, a.base, tuple(a.prefix), set(a.protected) | {"main", "master"}, retired)
        report["status"] = "pass"
        rc = 0
    except BranchGCError as exc:
        report = {"schema": "llm-agent-branch-gc-report/v1", "repository": a.repo, "base": a.base, "mode": "apply" if a.apply else "dry-run", "status": "fail", "error": str(exc)}
        rc = 1
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
    return rc

if __name__ == "__main__":
    raise SystemExit(main())
