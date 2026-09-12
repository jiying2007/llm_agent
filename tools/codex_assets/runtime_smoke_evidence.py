#!/usr/bin/env python3
"""Collect schema-bound Software M5 measured-runtime smoke evidence.

The collector can either execute the pinned ADK runtime evaluator or validate and
wrap an existing raw runtime report. Production evidence is fail-closed against
adk.lock and the checked-out agent-dev-kit gitlink identity.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


EVIDENCE_SCHEMA = "llm-agent-runtime-smoke-evidence/v1"
DEFAULT_MODEL = "gpt-5.5"
DEFAULT_LIMIT = 1


class SmokeEvidenceError(RuntimeError):
    """Fail-closed runtime smoke evidence error."""


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _digest(value: Any) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SmokeEvidenceError(f"invalid {label}: {path}") from exc
    if not isinstance(value, dict):
        raise SmokeEvidenceError(f"{label} must be a JSON object")
    return value


def _write_json(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _read_lock(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise SmokeEvidenceError(f"cannot read ADK lock: {path}") from exc
    for line in lines:
        if not line or line.lstrip().startswith("#"):
            continue
        if "=" not in line:
            raise SmokeEvidenceError(f"invalid ADK lock line: {line}")
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    required = (
        "agent-dev-kit.version",
        "agent-dev-kit.commit",
        "agent-dev-kit.tree",
        "agent-dev-kit.manifest_blob",
    )
    missing = [key for key in required if not values.get(key)]
    if missing:
        raise SmokeEvidenceError("ADK lock is missing fields: " + ", ".join(missing))
    return values


def _run_git(adk_root: Path, *args: str) -> str:
    try:
        completed = subprocess.run(
            ["git", "-C", str(adk_root), *args],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeEvidenceError("cannot inspect checked-out agent-dev-kit git identity") from exc
    if completed.returncode != 0 or not completed.stdout.strip():
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise SmokeEvidenceError(f"cannot inspect checked-out agent-dev-kit git identity: {detail}")
    return completed.stdout.strip()


def _manifest_digest(manifest: Mapping[str, Any]) -> str:
    payload = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _parse_generated_at(value: str | None) -> datetime:
    if value is None:
        return datetime.now(timezone.utc).replace(microsecond=0)
    if not value.endswith("Z"):
        raise SmokeEvidenceError("--generated-at must be an ISO-8601 UTC timestamp ending in Z")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise SmokeEvidenceError("--generated-at is invalid") from exc
    return parsed.astimezone(timezone.utc).replace(microsecond=0)


def _format_time(value: datetime) -> str:
    return value.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _validate_source_identity(root: Path) -> tuple[dict[str, str], dict[str, Any], Path]:
    lock = _read_lock(root / "adk.lock")
    adk_root = (root / "agent-dev-kit").resolve()
    manifest_path = adk_root / "manifest.json"
    if not manifest_path.is_file():
        raise SmokeEvidenceError("agent-dev-kit/manifest.json is missing; initialize the pinned gitlink/submodule first")
    manifest = _load_json(manifest_path, "ADK manifest")
    if manifest.get("version") != lock["agent-dev-kit.version"]:
        raise SmokeEvidenceError("ADK manifest version does not match adk.lock")

    actual_commit = _run_git(adk_root, "rev-parse", "HEAD")
    actual_tree = _run_git(adk_root, "rev-parse", "HEAD^{tree}")
    actual_manifest_blob = _run_git(adk_root, "rev-parse", "HEAD:manifest.json")
    expected = {
        "commit": lock["agent-dev-kit.commit"],
        "tree": lock["agent-dev-kit.tree"],
        "manifest_blob": lock["agent-dev-kit.manifest_blob"],
    }
    actual = {
        "commit": actual_commit,
        "tree": actual_tree,
        "manifest_blob": actual_manifest_blob,
    }
    for field, value in expected.items():
        if actual[field] != value:
            raise SmokeEvidenceError(f"checked-out ADK {field} does not match adk.lock")
    return lock, manifest, adk_root


def _validate_raw_report(report: Mapping[str, Any], model: str, limit: int) -> None:
    if report.get("schema_version") != 1 or report.get("suite") != "runtime-routing":
        raise SmokeEvidenceError("runtime report schema/suite is invalid")
    if report.get("runtime") != "codex" or report.get("condition") != "adk":
        raise SmokeEvidenceError("runtime report must be codex/adk")
    if report.get("requested_model") != model:
        raise SmokeEvidenceError("runtime report requested_model does not match collector model")
    if not isinstance(report.get("runtime_version"), str) or not str(report["runtime_version"]).strip():
        raise SmokeEvidenceError("runtime report runtime_version is missing")
    if report.get("status") != "pass":
        raise SmokeEvidenceError("runtime report is not passing")
    total = report.get("total")
    passed = report.get("passed")
    if isinstance(total, bool) or not isinstance(total, int) or total != limit:
        raise SmokeEvidenceError("runtime report total does not match requested limit")
    if passed != total:
        raise SmokeEvidenceError("runtime report did not pass every measured task")
    gates = report.get("quality_gate")
    if not isinstance(gates, dict) or not gates or not all(value is True for value in gates.values()):
        raise SmokeEvidenceError("runtime report quality gates are not all passing")
    results = report.get("results")
    if not isinstance(results, list) or len(results) != total:
        raise SmokeEvidenceError("runtime report result count is invalid")
    for index, item in enumerate(results):
        if not isinstance(item, dict):
            raise SmokeEvidenceError(f"runtime result {index} is not an object")
        if item.get("status") != "pass" or item.get("route_ok") is not True or item.get("safe_ok") is not True:
            raise SmokeEvidenceError(f"runtime result {index} is not a complete route+safety pass")
        if item.get("error") is not None:
            raise SmokeEvidenceError(f"runtime result {index} contains a runtime error")
        usage = item.get("usage")
        if not isinstance(usage, dict) or not isinstance(usage.get("total_tokens"), int) or usage["total_tokens"] < 0:
            raise SmokeEvidenceError(f"runtime result {index} token usage is invalid")


def _execute_runtime(
    root: Path,
    adk_root: Path,
    raw_output: Path,
    model: str,
    limit: int,
    tasks: Path,
) -> None:
    devkit = adk_root / "bin" / "devkit.sh"
    if not devkit.is_file():
        raise SmokeEvidenceError("pinned ADK devkit.sh is missing")
    if not tasks.is_file():
        raise SmokeEvidenceError(f"runtime smoke tasks are missing: {tasks}")
    raw_output.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "bash",
        str(devkit),
        "eval",
        "run",
        "--suite",
        "runtime",
        "--tasks",
        str(tasks),
        "--limit",
        str(limit),
        "--runtime",
        "codex",
        "--model",
        model,
        "--condition",
        "adk",
        "--execute",
        "--output",
        str(raw_output),
    ]
    try:
        completed = subprocess.run(command, cwd=str(adk_root), check=False, timeout=600)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise SmokeEvidenceError("ADK runtime smoke execution could not complete") from exc
    if completed.returncode != 0:
        raise SmokeEvidenceError(f"ADK runtime smoke execution failed with exit code {completed.returncode}")
    if not raw_output.is_file():
        raise SmokeEvidenceError("ADK runtime smoke execution did not write the raw report")


def collect(
    root: Path,
    output: Path,
    *,
    raw_result: Path | None,
    raw_output: Path | None,
    execute: bool,
    model: str,
    limit: int,
    tasks: Path | None,
    runtime_binary: Path | None,
    generated_at: str | None,
    review_days: int,
) -> dict[str, Any]:
    root = root.resolve()
    lock, manifest, adk_root = _validate_source_identity(root)
    if execute == (raw_result is not None):
        raise SmokeEvidenceError("choose exactly one of --execute or --raw-result")
    if limit < 1 or limit > 10:
        raise SmokeEvidenceError("--limit must be between 1 and 10")
    if review_days < 1 or review_days > 90:
        raise SmokeEvidenceError("--review-days must be between 1 and 90")

    if execute:
        if raw_output is None:
            raise SmokeEvidenceError("--raw-output is required with --execute")
        raw_path = raw_output.resolve()
        task_path = tasks.resolve() if tasks else adk_root / "tests" / "fixtures" / "software_m5_eval_tasks.jsonl"
        _execute_runtime(root, adk_root, raw_path, model, limit, task_path)
    else:
        assert raw_result is not None
        raw_path = raw_result.resolve()
        task_path = tasks.resolve() if tasks else adk_root / "tests" / "fixtures" / "software_m5_eval_tasks.jsonl"

    report = _load_json(raw_path, "runtime smoke report")
    _validate_raw_report(report, model, limit)

    runtime_path = runtime_binary.resolve() if runtime_binary else None
    if runtime_path is None:
        executable = shutil.which("codex")
        if executable is None:
            raise SmokeEvidenceError("codex runtime binary is not installed")
        runtime_path = Path(executable).resolve()
    if not runtime_path.is_file():
        raise SmokeEvidenceError(f"runtime binary is not a regular file: {runtime_path}")

    generated = _parse_generated_at(generated_at)
    review_after = (generated + timedelta(days=review_days)).date().isoformat()
    manifest_version = str(manifest["version"])
    evidence_id = f"codex-{manifest_version}-runtime-smoke-{generated.date().strftime('%Y%m%d')}"

    evidence: dict[str, Any] = {
        "schema": EVIDENCE_SCHEMA,
        "evidence_id": evidence_id,
        "generated_at": _format_time(generated),
        "review_after": review_after,
        "runtime": "codex",
        "runtime_version": report["runtime_version"],
        "runtime_binary_sha256": _sha256_file(runtime_path),
        "requested_model": model,
        "adk_commit": lock["agent-dev-kit.commit"],
        "adk_tree": lock["agent-dev-kit.tree"],
        "manifest_blob": lock["agent-dev-kit.manifest_blob"],
        "manifest_version": manifest_version,
        "manifest_sha256": _manifest_digest(manifest),
        "raw_result_sha256": _sha256_file(raw_path),
        "collection": {
            "collector": "tools.codex_assets.runtime_smoke_evidence",
            "task_limit": limit,
            "tasks_sha256": _sha256_file(task_path) if task_path.is_file() else None,
            "raw_report_retained_in_repository": False,
        },
        "result": report,
        "raw_content_stored": False,
    }
    evidence["evidence_sha256"] = _digest(evidence)
    _write_json(output.resolve(), evidence)
    return evidence


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="runtime_smoke_evidence")
    parser.add_argument("--root", default=".")
    parser.add_argument("--output", required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--execute", action="store_true")
    mode.add_argument("--raw-result")
    parser.add_argument("--raw-output")
    parser.add_argument("--tasks")
    parser.add_argument("--runtime-binary")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    parser.add_argument("--generated-at")
    parser.add_argument("--review-days", type=int, default=30)
    parser.add_argument("--summary-json", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        evidence = collect(
            Path(args.root),
            Path(args.output),
            raw_result=Path(args.raw_result) if args.raw_result else None,
            raw_output=Path(args.raw_output) if args.raw_output else None,
            execute=bool(args.execute),
            model=args.model,
            limit=args.limit,
            tasks=Path(args.tasks) if args.tasks else None,
            runtime_binary=Path(args.runtime_binary) if args.runtime_binary else None,
            generated_at=args.generated_at,
            review_days=args.review_days,
        )
    except SmokeEvidenceError as exc:
        if args.summary_json:
            print(json.dumps({"status": "fail", "error": str(exc)}, ensure_ascii=False, separators=(",", ":")))
        else:
            print(f"[FAIL] {exc}", file=sys.stderr)
        return 1
    summary = {
        "status": "pass",
        "evidence_id": evidence["evidence_id"],
        "manifest_version": evidence["manifest_version"],
        "adk_commit": evidence["adk_commit"],
        "runtime": evidence["runtime"],
        "runtime_version": evidence["runtime_version"],
        "requested_model": evidence["requested_model"],
        "evidence_sha256": evidence["evidence_sha256"],
        "output": str(Path(args.output)),
    }
    if args.summary_json:
        print(json.dumps(summary, ensure_ascii=False, separators=(",", ":")))
    else:
        print("[PASS] runtime smoke evidence collected")
        for key, value in summary.items():
            if key != "status":
                print(f"{key}={value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
