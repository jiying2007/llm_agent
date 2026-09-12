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
    pr_number: int
    merged_at: str

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

    def delete_branch(self, branch: str) -> None:
        self.request("DELETE", "/git/refs/heads/" + urllib.parse.quote(branch, safe="/"))

def branch_sha(branch: dict[str, Any]) -> str:
    commit = branch.get("commit")
    sha = commit.get("sha") if isinstance(commit, dict) else None
    if not isinstance(sha, str) or len(sha) != 40:
        raise BranchGCError("branch SHA is missing or invalid")
    return sha

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
            matches.append(Candidate(branch, sha, pr["number"], pr["merged_at"]))
    if not matches:
        return None
    return sorted(matches, key=lambda x: (x.merged_at, x.pr_number), reverse=True)[0]

def eligible(client: GitHubClient, branch: dict[str, Any], base: str, prefixes: tuple[str, ...], protected: set[str]) -> tuple[Candidate | None, str]:
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
    if merged is None:
        return None, "no-exact-merged-pr"
    return merged, "eligible"

def revalidate(client: GitHubClient, c: Candidate, base: str) -> tuple[bool, str]:
    current = client.get_branch(c.branch)
    if current.get("protected") is True:
        return False, "github-protected"
    if branch_sha(current) != c.sha:
        return False, "sha-changed"
    current_open = open_prs(client, c.branch, base)
    if current_open:
        return False, "open-pr:" + ",".join(map(str, current_open))
    if exact_merged_pr(client, c.branch, c.sha, base) is None:
        return False, "merged-pr-no-longer-exact"
    return True, "eligible"

def run(client: GitHubClient, apply: bool, base: str, prefixes: tuple[str, ...], protected: set[str]) -> dict[str, Any]:
    if not prefixes or any(not p for p in prefixes):
        raise BranchGCError("at least one non-empty prefix is required")
    candidates: list[Candidate] = []
    skipped: list[dict[str, Any]] = []
    for branch in client.list_branches():
        c, reason = eligible(client, branch, base, prefixes, protected)
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
            ok, reason = revalidate(client, c, base)
            if not ok:
                revalidation_skips.append({"branch": c.branch, "sha": c.sha, "reason": reason})
                continue
            client.delete_branch(c.branch)
            deleted.append({"branch": c.branch, "sha": c.sha, "merged_pr": c.pr_number, "merged_at": c.merged_at})
    return {
        "schema": "llm-agent-branch-gc-report/v1",
        "repository": client.repo,
        "base": base,
        "mode": "apply" if apply else "dry-run",
        "prefixes": list(prefixes),
        "protected_names": sorted(protected),
        "candidates": [{"branch": c.branch, "sha": c.sha, "merged_pr": c.pr_number, "merged_at": c.merged_at} for c in candidates],
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
    p.add_argument("--apply", action="store_true")
    p.add_argument("--report", required=True)
    a = p.parse_args(argv)
    path = Path(a.report)
    try:
        report = run(GitHubClient(a.repo, a.token), a.apply, a.base, tuple(a.prefix), set(a.protected) | {"main", "master"})
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
