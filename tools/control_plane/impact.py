from __future__ import annotations

import argparse
import fnmatch
import json
import subprocess
from collections import defaultdict, deque
from pathlib import Path
from typing import Any, Iterable

SCHEMA = "llm-agent-gate-impact/v1"


def _load_manifest(root: Path) -> dict[str, Any]:
    path = root / "manifests" / "gates.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "llm-agent-gates/v2":
        raise ValueError("gate impact requires llm-agent-gates/v2")
    gates = data.get("gates")
    if not isinstance(gates, dict) or not gates:
        raise ValueError("gate manifest requires non-empty gates")
    for name, spec in gates.items():
        if not isinstance(spec, dict):
            raise ValueError(f"gate {name} must be an object")
        dependencies = spec.get("depends_on", [])
        if not isinstance(dependencies, list) or not all(isinstance(item, str) and item for item in dependencies):
            raise ValueError(f"gate {name} depends_on must be a string list")
        unknown = [item for item in dependencies if item not in gates]
        if unknown:
            raise ValueError(f"gate {name} depends on unknown gates: {', '.join(unknown)}")
        for field in ("inputs", "impact_inputs", "impact_groups"):
            value = spec.get(field, [])
            if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
                raise ValueError(f"gate {name} {field} must be a string list")
    return data


def _normalize_path(value: str) -> str:
    normalized = value.strip().replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    return normalized.rstrip("/")


def _path_matches(spec: str, changed: str) -> bool:
    spec = _normalize_path(spec)
    changed = _normalize_path(changed)
    if not spec or not changed:
        return False
    if any(char in spec for char in "*?["):
        return fnmatch.fnmatchcase(changed, spec)
    return changed == spec or changed.startswith(spec + "/")


def _git_changed_paths(root: Path, base: str, head: str, mode: str) -> list[str]:
    if not base or not head:
        return []
    exists = subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", f"{base}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if exists.returncode != 0:
        return []
    separator = "..." if mode == "three-dot" else ".."
    completed = subprocess.run(
        ["git", "-C", str(root), "diff", "--name-only", f"{base}{separator}{head}"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise ValueError(completed.stderr.strip() or "unable to calculate changed paths")
    return sorted({_normalize_path(line) for line in completed.stdout.splitlines() if _normalize_path(line)})


def _direct_impacts(gates: dict[str, Any], changed_paths: Iterable[str]) -> tuple[set[str], dict[str, list[str]]]:
    changed = tuple(sorted({_normalize_path(path) for path in changed_paths if _normalize_path(path)}))
    direct: set[str] = set()
    matched: dict[str, list[str]] = {}
    for name, spec in gates.items():
        declared = list(spec.get("inputs", [])) + list(spec.get("impact_inputs", []))
        gate_matches = sorted(
            path
            for path in changed
            if any(_path_matches(input_path, path) for input_path in declared)
        )
        if gate_matches:
            direct.add(name)
            matched[name] = gate_matches
    return direct, matched


def _expand_downstream(gates: dict[str, Any], direct: set[str]) -> set[str]:
    reverse: dict[str, set[str]] = defaultdict(set)
    for name, spec in gates.items():
        for dependency in spec.get("depends_on", []):
            reverse[dependency].add(name)
    impacted = set(direct)
    queue: deque[str] = deque(sorted(direct))
    while queue:
        current = queue.popleft()
        for dependent in sorted(reverse.get(current, set())):
            if dependent not in impacted:
                impacted.add(dependent)
                queue.append(dependent)
    return impacted


def calculate_impact(
    root: Path,
    changed_paths: Iterable[str],
    *,
    group: str,
    force: bool = False,
) -> dict[str, Any]:
    manifest = _load_manifest(root)
    gates = manifest["gates"]
    changed = sorted({_normalize_path(path) for path in changed_paths if _normalize_path(path)})
    direct, matched = _direct_impacts(gates, changed)
    impacted = _expand_downstream(gates, direct)

    # A gate owns the impact policy for its declared input surface. Dependency
    # closure is still reported so callers can schedule downstream work, but a
    # group is required only when a directly changed surface is explicitly
    # tagged for that group. This prevents unrelated upstream documentation
    # changes from inheriting every downstream integration policy.
    group_gates = sorted(name for name in direct if group in gates[name].get("impact_groups", []))
    downstream_group_gates = sorted(
        name for name in impacted - direct if group in gates[name].get("impact_groups", [])
    )
    required = force or bool(group_gates)
    if force:
        reason = "workflow-dispatch"
    elif group_gates:
        reason = "gate-impact:" + ",".join(group_gates)
    else:
        reason = "not-required"
    return {
        "schema": SCHEMA,
        "status": "pass",
        "group": group,
        "required": required,
        "reason": reason,
        "changed_paths": changed,
        "direct_gates": sorted(direct),
        "impacted_gates": sorted(impacted),
        "group_gates": group_gates,
        "downstream_group_gates": downstream_group_gates,
        "matched_paths": {name: matched[name] for name in sorted(matched)},
    }


def _write_github_output(path: str, receipt: dict[str, Any]) -> None:
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(f"required={'true' if receipt['required'] else 'false'}\n")
        handle.write(f"reason={receipt['reason']}\n")
        handle.write("group_gates=" + ",".join(receipt["group_gates"]) + "\n")


def _write_step_summary(path: str, receipt: dict[str, Any]) -> None:
    with open(path, "a", encoding="utf-8") as handle:
        handle.write("### Gate dependency impact\n")
        handle.write(f"- group: {receipt['group']}\n")
        handle.write(f"- required: {str(receipt['required']).lower()}\n")
        handle.write(f"- reason: {receipt['reason']}\n")
        handle.write(f"- changed paths: {len(receipt['changed_paths'])}\n")
        handle.write(f"- directly impacted gates: {', '.join(receipt['direct_gates']) or 'none'}\n")
        handle.write(f"- group gates: {', '.join(receipt['group_gates']) or 'none'}\n")
        handle.write(
            f"- downstream group gates (informational): {', '.join(receipt['downstream_group_gates']) or 'none'}\n"
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Calculate CI impact from manifests/gates.json")
    parser.add_argument("--root", default=".")
    parser.add_argument("--group", default="integration-deep")
    parser.add_argument("--changed-file", action="append", default=[])
    parser.add_argument("--base")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--mode", choices=("two-dot", "three-dot"), default="two-dot")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    parser.add_argument("--github-output")
    parser.add_argument("--step-summary")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    root = Path(args.root).resolve()
    changed = list(args.changed_file)
    if args.base:
        changed.extend(_git_changed_paths(root, args.base, args.head, args.mode))
    receipt = calculate_impact(root, changed, group=args.group, force=args.force)
    if args.github_output:
        _write_github_output(args.github_output, receipt)
    if args.step_summary:
        _write_step_summary(args.step_summary, receipt)
    if args.summary_json or not args.github_output:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
