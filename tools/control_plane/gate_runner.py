from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class GateResult:
    name: str
    status: str
    exit_code: int | None
    elapsed_ms: int
    owner: str
    evidence_class: str
    output_tail: list[str]
    missing_capabilities: list[str]


def _load(root: Path) -> dict[str, Any]:
    path = root / "manifests" / "gates.json"
    data = json.loads(path.read_text(encoding="utf-8"))
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
    lines = text.splitlines()
    return lines[-limit:]


def run_profile(
    root: Path,
    profile: str,
    capabilities: set[str],
    failure_lines: int,
) -> dict[str, Any]:
    manifest = _load(root)
    order = _expand_profile(manifest, profile)
    results: list[GateResult] = []

    for name in order:
        spec = manifest["gates"][name]
        if spec.get("side_effect") != "none":
            raise ValueError(f"gate {name} must be side_effect=none")
        argv = spec.get("argv")
        if not isinstance(argv, list) or not argv or not all(isinstance(item, str) for item in argv):
            raise ValueError(f"gate {name} requires string argv list")
        required = spec.get("requires", [])
        if not isinstance(required, list) or not all(isinstance(item, str) for item in required):
            raise ValueError(f"gate {name} requires must be a string list")
        missing = sorted(set(required) - capabilities)
        if missing:
            results.append(
                GateResult(
                    name=name,
                    status="blocked",
                    exit_code=None,
                    elapsed_ms=0,
                    owner=str(spec.get("owner", "unknown")),
                    evidence_class=str(spec.get("evidence_class", "unknown")),
                    output_tail=[],
                    missing_capabilities=missing,
                )
            )
            continue

        started = time.monotonic_ns()
        completed = subprocess.run(
            argv,
            cwd=root,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        elapsed_ms = (time.monotonic_ns() - started) // 1_000_000
        results.append(
            GateResult(
                name=name,
                status="pass" if completed.returncode == 0 else "fail",
                exit_code=completed.returncode,
                elapsed_ms=int(elapsed_ms),
                owner=str(spec.get("owner", "unknown")),
                evidence_class=str(spec.get("evidence_class", "unknown")),
                output_tail=_tail(completed.stdout, failure_lines),
                missing_capabilities=[],
            )
        )

    status = "pass"
    if any(item.status == "fail" for item in results):
        status = "fail"
    elif any(item.status == "blocked" for item in results):
        status = "blocked"

    return {
        "schema": "llm-agent-gate-run/v1",
        "profile": profile,
        "status": status,
        "capabilities": sorted(capabilities),
        "gates": [
            {
                "name": item.name,
                "status": item.status,
                "exit_code": item.exit_code,
                "elapsed_ms": item.elapsed_ms,
                "owner": item.owner,
                "evidence_class": item.evidence_class,
                "missing_capabilities": item.missing_capabilities,
                "output_tail": item.output_tail,
            }
            for item in results
        ],
    }


def _render(result: dict[str, Any]) -> None:
    print(f"Gate profile: {result['profile']} status={result['status']}")
    for item in result["gates"]:
        suffix = ""
        if item["missing_capabilities"]:
            suffix = " missing=" + ",".join(item["missing_capabilities"])
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
