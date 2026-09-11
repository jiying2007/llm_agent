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

from tools.control_plane.receipts import bind_receipt, content_sha256

_ALLOWED_EVIDENCE_CLASSES = {"source", "test", "runtime", "field", "release"}
_ALLOWED_CACHE_POLICIES = {"disabled", "content-addressed"}


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
    depends_on: list[str]
    blocked_by: list[str]
    inputs: list[str]
    input_digests: dict[str, str]
    outputs: list[str]
    cache_policy: str
    cache_key: str
    cache_hit: bool


def _manifest_path(root: Path) -> Path:
    return root / "manifests" / "gates.json"


def _load(root: Path) -> dict[str, Any]:
    data = json.loads(_manifest_path(root).read_text(encoding="utf-8"))
    if data.get("schema") not in {"llm-agent-gates/v1", "llm-agent-gates/v2"}:
        raise ValueError("unsupported gate manifest schema")
    if not isinstance(data.get("gates"), dict) or not isinstance(data.get("profiles"), dict):
        raise ValueError("gate manifest requires gates and profiles objects")
    return data


def _dependency_names(name: str, raw: Any, gates: dict[str, Any]) -> list[str]:
    if not isinstance(raw, dict):
        raise ValueError(f"gate {name} must be an object")
    dependencies = raw.get("depends_on", [])
    if not isinstance(dependencies, list) or not all(isinstance(item, str) and item for item in dependencies):
        raise ValueError(f"gate {name} depends_on must be a string list")
    unknown = [item for item in dependencies if item not in gates]
    if unknown:
        raise ValueError(f"gate {name} depends on unknown gates: {', '.join(unknown)}")
    return dependencies


def _expand_profile(manifest: dict[str, Any], profile: str) -> list[str]:
    profiles = manifest["profiles"]
    gates = manifest["gates"]
    visiting_profiles: set[str] = set()
    visiting_gates: set[str] = set()
    result: list[str] = []
    emitted: set[str] = set()

    def visit_gate(name: str) -> None:
        if name in emitted:
            return
        if name in visiting_gates:
            raise ValueError(f"gate dependency cycle detected at: {name}")
        visiting_gates.add(name)
        for dependency in _dependency_names(name, gates[name], gates):
            visit_gate(dependency)
        visiting_gates.remove(name)
        emitted.add(name)
        result.append(name)

    def visit(name: str) -> None:
        if name in gates:
            visit_gate(name)
            return
        if name not in profiles:
            raise ValueError(f"unknown gate/profile reference: {name}")
        if name in visiting_profiles:
            raise ValueError(f"gate profile cycle detected at: {name}")
        visiting_profiles.add(name)
        entries = profiles[name]
        if not isinstance(entries, list):
            raise ValueError(f"profile {name} must be a list")
        for entry in entries:
            if not isinstance(entry, str):
                raise ValueError(f"profile {name} contains a non-string entry")
            visit(entry)
        visiting_profiles.remove(name)

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


def _validated_spec(
    name: str,
    raw: Any,
    gates: dict[str, Any],
) -> tuple[list[str], list[str], str, str, int, list[str], list[str], list[str], str]:
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
    depends_on = _dependency_names(name, raw, gates)
    inputs = raw.get("inputs", [])
    outputs = raw.get("outputs", [])
    if not isinstance(inputs, list) or not all(isinstance(item, str) and item for item in inputs):
        raise ValueError(f"gate {name} inputs must be a string list")
    if not isinstance(outputs, list) or not all(isinstance(item, str) and item for item in outputs):
        raise ValueError(f"gate {name} outputs must be a string list")
    cache_policy = raw.get("cache_policy", "disabled")
    if cache_policy not in _ALLOWED_CACHE_POLICIES:
        raise ValueError(f"gate {name} has invalid cache_policy: {cache_policy}")
    return argv, required, owner, evidence_class, timeout_seconds, depends_on, inputs, outputs, cache_policy


def _digest_path(root: Path, input_path: str) -> str:
    path = (root / input_path).resolve()
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"gate input escapes repository root: {input_path}") from exc
    if not path.exists():
        raise ValueError(f"gate input does not exist: {input_path}")
    digest = hashlib.sha256()
    if path.is_file():
        digest.update(path.read_bytes())
        return digest.hexdigest()
    for child in sorted(item for item in path.rglob("*") if item.is_file() and ".git" not in item.parts):
        relative = child.relative_to(root).as_posix().encode("utf-8")
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        content = child.read_bytes()
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
    return digest.hexdigest()


def _input_digests(root: Path, inputs: list[str]) -> dict[str, str]:
    return {item: _digest_path(root, item) for item in inputs}


def _cache_key(
    *,
    name: str,
    raw: dict[str, Any],
    source: dict[str, str],
    input_digests: dict[str, str],
    capabilities: set[str],
) -> str:
    return content_sha256(
        {
            "gate": name,
            "spec": raw,
            "source_tree": source["tree"],
            "gate_manifest_sha256": source["gate_manifest_sha256"],
            "input_digests": input_digests,
            "capabilities": sorted(capabilities),
        }
    )


def _cache_path(cache_dir: Path | None, key: str) -> Path | None:
    if cache_dir is None:
        return None
    return cache_dir / f"{key}.json"


def _cached_pass(path: Path | None, key: str) -> bool:
    if path is None or not path.is_file():
        return False
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    return data.get("cache_key") == key and data.get("status") == "pass"


def _write_cache(path: Path | None, key: str) -> None:
    if path is None:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"cache_key": key, "status": "pass"}, sort_keys=True) + "\n", encoding="utf-8")


def run_profile(
    root: Path,
    profile: str,
    capabilities: set[str],
    failure_lines: int,
    cache_dir: Path | None = None,
) -> dict[str, Any]:
    root = root.resolve()
    manifest = _load(root)
    source = _source_identity(root)
    order = _expand_profile(manifest, profile)
    results: list[GateResult] = []
    by_name: dict[str, GateResult] = {}
    run_started = time.monotonic_ns()

    for name in order:
        raw = manifest["gates"][name]
        (
            argv,
            required,
            owner,
            evidence_class,
            timeout_seconds,
            depends_on,
            inputs,
            outputs,
            cache_policy,
        ) = _validated_spec(name, raw, manifest["gates"])
        missing = sorted(set(required) - capabilities)
        blocked_by = sorted(dep for dep in depends_on if by_name.get(dep) is None or by_name[dep].status != "pass")

        if missing or blocked_by:
            input_digests: dict[str, str] = {}
            cache_key = content_sha256({"gate": name, "blocked": True, "missing": missing, "blocked_by": blocked_by})
            result = GateResult(
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
                failure_reason="missing-capability" if missing else "dependency-blocked",
                depends_on=depends_on,
                blocked_by=blocked_by,
                inputs=inputs,
                input_digests=input_digests,
                outputs=outputs,
                cache_policy=cache_policy,
                cache_key=cache_key,
                cache_hit=False,
            )
            results.append(result)
            by_name[name] = result
            continue

        input_digests = _input_digests(root, inputs)
        cache_key = _cache_key(
            name=name,
            raw=raw,
            source=source,
            input_digests=input_digests,
            capabilities=capabilities,
        )
        cached = cache_policy == "content-addressed" and _cached_pass(_cache_path(cache_dir, cache_key), cache_key)
        if cached:
            result = GateResult(
                name=name,
                status="pass",
                exit_code=0,
                elapsed_ms=0,
                owner=owner,
                evidence_class=evidence_class,
                argv=argv,
                timeout_seconds=timeout_seconds,
                output_tail=[],
                missing_capabilities=[],
                failure_reason=None,
                depends_on=depends_on,
                blocked_by=[],
                inputs=inputs,
                input_digests=input_digests,
                outputs=outputs,
                cache_policy=cache_policy,
                cache_key=cache_key,
                cache_hit=True,
            )
            results.append(result)
            by_name[name] = result
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
            result = GateResult(
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
                depends_on=depends_on,
                blocked_by=[],
                inputs=inputs,
                input_digests=input_digests,
                outputs=outputs,
                cache_policy=cache_policy,
                cache_key=cache_key,
                cache_hit=False,
            )
            if passed and cache_policy == "content-addressed":
                _write_cache(_cache_path(cache_dir, cache_key), cache_key)
        except subprocess.TimeoutExpired as exc:
            elapsed_ms = (time.monotonic_ns() - started) // 1_000_000
            captured = exc.stdout or ""
            if isinstance(captured, bytes):
                captured = captured.decode(errors="replace")
            result = GateResult(
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
                depends_on=depends_on,
                blocked_by=[],
                inputs=inputs,
                input_digests=input_digests,
                outputs=outputs,
                cache_policy=cache_policy,
                cache_key=cache_key,
                cache_hit=False,
            )
        results.append(result)
        by_name[name] = result

    total_elapsed_ms = int((time.monotonic_ns() - run_started) // 1_000_000)
    status = "pass"
    if any(item.status == "fail" for item in results):
        status = "fail"
    elif any(item.status == "blocked" for item in results):
        status = "blocked"
    blocked_capabilities = sorted(
        {capability for item in results for capability in item.missing_capabilities}
    )

    receipt = {
        "schema": "llm-agent-gate-run/v2",
        "gate_manifest_schema": manifest["schema"],
        "profile": profile,
        "status": status,
        "source": source,
        "capabilities": sorted(capabilities),
        "blocked_capabilities": blocked_capabilities,
        "graph_order": order,
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
                "depends_on": item.depends_on,
                "blocked_by": item.blocked_by,
                "inputs": item.inputs,
                "input_digests": item.input_digests,
                "outputs": item.outputs,
                "cache_policy": item.cache_policy,
                "cache_key": item.cache_key,
                "cache_hit": item.cache_hit,
                "output_tail": item.output_tail,
            }
            for item in results
        ],
    }
    return bind_receipt(receipt)


def _render(result: dict[str, Any]) -> None:
    print(
        f"Gate profile: {result['profile']} status={result['status']} "
        f"head={result['source']['head'][:12]} elapsed={result['total_elapsed_ms']}ms "
        f"receipt={result['receipt_sha256'][:12]}"
    )
    for item in result["gates"]:
        suffix = ""
        if item["missing_capabilities"]:
            suffix = " missing=" + ",".join(item["missing_capabilities"])
        if item["blocked_by"]:
            suffix += " blocked_by=" + ",".join(item["blocked_by"])
        if item["failure_reason"]:
            suffix += " reason=" + item["failure_reason"]
        if item["cache_hit"]:
            suffix += " cache=hit"
        print(f"[{item['status'].upper()}] {item['name']} ({item['elapsed_ms']} ms){suffix}")
        if item["status"] == "fail":
            for line in item["output_tail"]:
                print(f"  {line}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run a declarative content-addressed llm_agent gate graph")
    parser.add_argument("--root", default=".")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--capability", action="append", default=[])
    parser.add_argument("--failure-lines", type=int, default=80)
    parser.add_argument("--cache-dir", help="Optional local content-addressed pass cache")
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
            Path(args.cache_dir).resolve() if args.cache_dir else None,
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
