"""Read-only, bounded GitHub Actions job-time observation; never billing authority.

GitHub Actions workflow/run "usage" endpoints are being retired. Sum observed
job started_at/completed_at wall time as a *proxy*, never dollars or billable minutes.
No raw logs, artifacts, secrets, model usage, or repository writes are requested.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import datetime
import json
import os
from pathlib import Path
import re
import urllib.request
from typing import Any

SCHEMA = "llm-agent-actions-cost-observation/v1"
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
MAX_RESPONSE = 3 * 1024 * 1024


def _utc(value: Any) -> datetime:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise ValueError("job timestamp must be explicit UTC Z")
    stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if stamp.utcoffset() is None or stamp.utcoffset().total_seconds() != 0:
        raise ValueError("job timestamp is not UTC")
    return stamp


def summarize(repository: str, samples: list[dict[str, Any]]) -> dict[str, Any]:
    if not REPO_RE.fullmatch(repository) or ".." in repository.split("/") or len(samples) > 100:
        raise ValueError("invalid repository or excessive sample size")
    counts: Counter[str] = Counter()
    by_name: dict[str, dict[str, Any]] = defaultdict(lambda: {
        "runs": 0, "jobs": 0, "observed_job_seconds": 0,
        "jobs_without_finished_timestamps": 0, "cancelled_runs": 0, "skipped_jobs": 0,
    })
    seen_ids: set[int] = set()
    identical_heads: Counter[tuple[str, str, str]] = Counter()
    for sample in samples:
        if not isinstance(sample, dict):
            raise ValueError("run sample must be an object")
        run_id, name, jobs = sample.get("id"), sample.get("name"), sample.get("jobs")
        if type(run_id) is not int or run_id <= 0 or run_id in seen_ids:
            raise ValueError("run ids must be unique positive integers")
        if not isinstance(name, str) or not name.strip() or len(name) > 160:
            raise ValueError("workflow display name is invalid")
        if not isinstance(jobs, list) or len(jobs) > 100:
            raise ValueError("job collection missing or incomplete")
        seen_ids.add(run_id)
        count = by_name[name]
        count["runs"] += 1
        conclusion = sample.get("conclusion")
        if conclusion == "cancelled":
            count["cancelled_runs"] += 1
        elif conclusion not in (None, "success", "failure", "skipped", "timed_out", "action_required", "neutral"):
            raise ValueError("unsupported workflow conclusion")
        sha = sample.get("head_sha")
        event = sample.get("event")
        if isinstance(sha, str) and re.fullmatch(r"[a-f0-9]{40}", sha) and isinstance(event, str):
            identical_heads[(name, event, sha)] += 1
        seen_jobs: set[int] = set()
        for job in jobs:
            if not isinstance(job, dict):
                raise ValueError("job must be an object")
            job_id = job.get("id")
            if type(job_id) is not int or job_id <= 0 or job_id in seen_jobs:
                raise ValueError("duplicate or invalid job id in a run")
            seen_jobs.add(job_id)
            count["jobs"] += 1
            if job.get("conclusion") == "skipped":
                count["skipped_jobs"] += 1
                continue
            start, end = job.get("started_at"), job.get("completed_at")
            if start is None or end is None:
                count["jobs_without_finished_timestamps"] += 1
                continue
            seconds = int((_utc(end) - _utc(start)).total_seconds())
            if not 0 <= seconds <= 86400:
                raise ValueError("negative or implausibly long job duration")
            count["observed_job_seconds"] += seconds
        counts["runs"] += 1
    rows = []
    for name, values in sorted(by_name.items(), key=lambda pair: (-pair[1]["observed_job_seconds"], pair[0])):
        rows.append({"workflow": name, **values,
                     "observed_job_wall_minutes": round(values["observed_job_seconds"] / 60, 2)})
    return {
        "schema": SCHEMA, "status": "observation-only",
        "source": "github-actions-runs-and-latest-attempt-jobs",
        "repository": repository, "sampled_runs": counts["runs"],
        "observed_job_wall_minutes": round(sum(x["observed_job_seconds"] for x in rows) / 60, 2),
        "possible_same_head_repetitions": sum(max(0, count - 1) for count in identical_heads.values()),
        "workflow_breakdown": rows,
        "billable_minutes": None, "usd_cost": None,
        "limitations": [
            "Job wall duration is not billing, rate, token use or actual provider spend.",
            "Only latest-attempt job pages are counted; retries and older attempts can be omitted.",
            "Sample is most recent N runs, not a representative historical billing period.",
            "Skipped and unfinished jobs do not have observable completed wall durations.",
        ],
        "qualification_authority": "none",
    }


def _api_json(url: str, token: str | None) -> dict[str, Any]:
    if not url.startswith("https://api.github.com/repos/"):
        raise ValueError("API URL must use the fixed GitHub REST host")
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "llm-agent-readonly-cost-audit"}
    if token:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(url, headers=headers, method="GET")
    with urllib.request.urlopen(request, timeout=8) as response:
        raw = response.read(MAX_RESPONSE + 1)
    if len(raw) > MAX_RESPONSE:
        raise ValueError("GitHub API payload exceeded size budget")
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise ValueError("GitHub API payload must be object")
    return value


def sample_live(repository: str, limit: int, token: str | None) -> list[dict[str, Any]]:
    if not REPO_RE.fullmatch(repository) or ".." in repository.split("/") or not 1 <= limit <= 30:
        raise ValueError("repository or run sample limit is invalid")
    base = "https://api.github.com/repos/" + repository + "/actions"
    data = _api_json(base + "/runs?per_page=" + str(limit), token)
    runs = data.get("workflow_runs")
    if not isinstance(runs, list) or len(runs) > limit:
        raise ValueError("workflow run API returned invalid sample")
    samples = []
    for run in runs:
        if not isinstance(run, dict) or type(run.get("id")) is not int:
            raise ValueError("invalid workflow run")
        data = _api_json(base + "/runs/" + str(run["id"]) + "/jobs?per_page=100", token)
        jobs = data.get("jobs")
        if not isinstance(jobs, list) or data.get("total_count") != len(jobs):
            raise ValueError("job page is incomplete, refusing silent undercount")
        samples.append({**run, "jobs": jobs})
    return samples


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.fixture is None:
            samples = sample_live(args.repository, args.limit, os.environ.get("GITHUB_TOKEN"))
        else:
            if args.fixture.stat().st_size > MAX_RESPONSE:
                raise ValueError("fixture exceeded size budget")
            samples = json.loads(args.fixture.read_text(encoding="utf-8"))
            if not isinstance(samples, list):
                raise ValueError("fixture must contain a JSON array")
        report = summarize(args.repository, samples)
    except (ValueError, OSError, TimeoutError, KeyError, json.JSONDecodeError) as exc:
        # No false all-clear on API unavailability. Do not print token, request
        # header, URL, or exception detail from a remote service.
        report = {"schema": SCHEMA, "status": "unavailable",
                  "reason": type(exc).__name__, "repository": args.repository,
                  "billable_minutes": None, "usd_cost": None, "qualification_authority": "none"}
    output = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        stream.write(output)
    print(json.dumps({"schema": SCHEMA, "status": report["status"], "path": str(args.output),
                      "sampled_runs": report.get("sampled_runs", 0)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
