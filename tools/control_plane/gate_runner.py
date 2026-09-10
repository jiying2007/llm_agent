from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

_ALLOWED_EVIDENCE_CLASSES = {"source", "test", "runtime", "field", "release"}


@dataclass(frozen=True)
class GateResult:
    name: str
    status: str
    exit_code: int | None
    elapsed_ms: int
    owner: str
    evidence_class: str
    argv: list[str]
    timeout_seconds: int
    output_tail: list[str]
    missing_capabilities: list[str]
    failure_reason: str | None


def _manifest_path(root: Path) -> Path:
    return root / "manifests" / "gates.json"


def _load(root: Path) -> dict[str, Any]:
    data = json.loads(_manifest_path(root).read_text(encoding="utf-8"))
    if data.get("schema") != "llm-agent-gates/v1":
        raise ValueError("unsupported gate manifest schema")
    if not isinstance(data.get("gates"), dict) or not isinstance(data.get("profiles"), dict):
        raise ValueError("gate manifest requires gates and profiles objects")
    return data


def _expand_profile(manifest: dict[str, Any], profile: str) -> list[str]:
    profiles = manifest["profiles"]
    gates = manifest["gates"]
    visiting: set[str] = set()
    result: list[str] = []
    emitted: set[str] = set()

    def visit(name: str) -> None:
        if name in gates:
            if name not in emitted:
                emitted.add(name)
                result.append(name)
            return
        if name not in profiles:
            raise ValueError(f"unknown gate/profile reference: {name}")
        if name in visiting:
            raise ValueError(f"gate profile cycle detected at: {name}")
        visiting.add(name)
        entries = profiles[name]
        if not isinstance(entries, list):
            raise ValueError(f"profile {name} must be a list")
        for entry in entries:
            if not isinstance(entry, str):
                raise ValueError(f"profile {name} contains a non-string entry")
            visit(entry)
        visiting.remove(name)

    visit(profile)
    return result


def _tail(text: str, limit: int) -> list[str]:
    if limit == 0:
        return []
    return text.splitlines()[-limit:]


def _source_identity(root: Path) -> dict[str, str]:
    completed = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD", "HEAD^{tree}"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise ValueError(completed.stderr.strip() or "unable to resolve source identity")
    lines = completed.stdout.splitlines()
    if len(lines) != 2:
        raise ValueError("unexpected git source identity output")
    manifest_bytes = _manifest_path(root).read_bytes()
    return {
        "head": lines[0],
        "tree": lines[1],
        "gate_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
    }


def _validated_spec(name: str, raw: Any) -> tuple[list[str], list[str], str, str, int]:
    if not isinstance(raw, dict):
        raise ValueError(f"gate {name} must be an object")
    if raw.get("side_effect") != "none":
        raise ValueError(f"gate {name} must be side_effect=none")
    argv = raw.get("argv")
    if not isinstance(argv, list) or not argv or not all(isinstance(item, str) and item for item in argv):
        raise ValueError(f"gate {name} requires non-empty string argv list")
    required = raw.get("requires", [])
    if not isinstance(required, list) or not all(isinstance(item, str) and item for item in required):
        raise ValueError(f"gate {name} requires must be a string list")
    owner = raw.get("owner")
    if not isinstance(owner, str) or not owner:
        raise ValueError(f"gate {name} requires owner")
    evidence_class = raw.get("evidence_class")
    if evidence_class not in _ALLOWED_EVIDENCE_CLASSES:
        raise ValueError(f"gate {name} has invalid evidence_class: {evidence_class}")
    timeout_seconds = raw.get("timeout_seconds")
    if not isinstance(timeout_seconds, int) or isinstance(timeout_seconds, bool) or timeout_seconds <= 0:
        raise ValueError(f"gate {name} requires positive integer timeout_seconds")
    return argv, required, owner, evidence_class, timeout_seconds


def run_profile(
    root: Path,
    profile: str,
    capabilities: set[str],
    failure_lines: int,
) -> dict[str, Any]:
    root = root.resolve()
    manifest = _load(root)
    source = _source_identity(root)
    order = _expand_profile(manifest, profile)
    results: list[GateResult] = []
    run_started = time.monotonic_ns()

    for name in order:
        argv, required, owner, evidence_class, timeout_seconds = _validated_spec(
            name, manifest["gates"][name]
        )
        missing = sorted(set(required) - capabilities)
        if missing:
            results.append(
                GateResult(
                    name=name,
                    status="blocked",
                    exit_code=None,
                    elapsed_ms=0,
                    owner=owner,
                    evidence_class=evidence_class,
                    argv=argv,
                    timeout_seconds=timeout_seconds,
                    output_tail=[],
                    missing_capabilities=missing,
                    failure_reason="missing-capability",
                )
            )
            continue

        started = time.monotonic_ns()
        try:
            completed = subprocess.run(
                argv,
                cwd=root,
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=timeout_seconds,
            )
            elapsed_ms = (time.monotonic_ns() - started) // 1_000_000
            passed = completed.returncode == 0
            results.append(
                GateResult(
                    name=name,
                    status="pass" if passed else "fail",
                    exit_code=completed.returncode,
                    elapsed_ms=int(elapsed_ms),
                    owner=owner,
                    evidence_class=evidence_class,
                    argv=argv,
                    timeout_seconds=timeout_seconds,
                    output_tail=_tail(completed.stdout, failure_lines),
                    missing_capabilities=[],
                    failure_reason=None if passed else "nonzero-exit",
                )
            )
        except subprocess.TimeoutExpired as exc:
            elapsed_ms = (time.monotonic_ns() - started) // 1_000_000
            captured = exc.stdout or ""
            if isinstance(captured, bytes):
                captured = captured.decode(errors="replace")
            results.append(
                GateResult(
                    name=name,
                    status="fail",
                    exit_code=None,
                    elapsed_ms=int(elapsed_ms),
                    owner=owner,
                    evidence_class=evidence_class,
                    argv=argv,
                    timeout_seconds=timeout_seconds,
                    output_tail=_tail(captured, failure_lines),
                    missing_capabilities=[],
                    failure_reason="timeout",
                )
            )

    total_elapsed_ms = int((time.monotonic_ns() - run_started) // 1_000_000)
    status = "pass"
    if any(item.status == "fail" for item in results):
        status = "fail"
    elif any(item.status == "blocked" for item in results):
        status = "blocked"
    blocked_capabilities = sorted(
        {capability for item in results for capability in item.missing_capabilities}
    )

    return {
        "schema": "llm-agent-gate-run/v2",
        "profile": profile,
        "status": status,
        "source": source,
        "capabilities": sorted(capabilities),
        "blocked_capabilities": blocked_capabilities,
        "total_elapsed_ms": total_elapsed_ms,
        "gates": [
            {
                "name": item.name,
                "status": item.status,
                "exit_code": item.exit_code,
                "elapsed_ms": item.elapsed_ms,
                "owner": item.owner,
                "evidence_class": item.evidence_class,
                "argv": item.argv,
                "timeout_seconds": item.timeout_seconds,
                "missing_capabilities": item.missing_capabilities,
                "failure_reason": item.failure_reason,
                "output_tail": item.output_tail,
            }
            for item in results
        ],
    }


def _render(result: dict[str, Any]) -> None:
    print(
        f"Gate profile: {result['profile']} status={result['status']} "
        f"head={result['source']['head'][:12]} elapsed={result['total_elapsed_ms']}ms"
    )
    for item in result["gates"]:
        suffix = ""
        if item["missing_capabilities"]:
            suffix = " missing=" + ",".join(item["missing_capabilities"])
        if item["failure_reason"]:
            suffix += " reason=" + item["failure_reason"]
        print(f"[{item['status'].upper()}] {item['name']} ({item['elapsed_ms']} ms){suffix}")
        if item["status"] == "fail":
            for line in item["output_tail"]:
                print(f"  {line}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run a declarative llm_agent gate profile")
    parser.add_argument("--root", default=".")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--capability", action="append", default=[])
    parser.add_argument("--failure-lines", type=int, default=80)
    parser.add_argument("--summary-json", action="store_true")
    parser.add_argument("--output-json")
    args = parser.parse_args(argv)
    if args.failure_lines < 0:
        parser.error("--failure-lines must be >= 0")

    try:
        result = run_profile(
            Path(args.root).resolve(),
            args.profile,
            set(args.capability),
            args.failure_lines,
        )
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"[FAIL] gate runner configuration error: {exc}", file=sys.stderr)
        return 2

    if args.output_json:
        output = Path(args.output_json)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        _render(result)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
