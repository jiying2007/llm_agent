"""Classify a repository diff into the minimum evidence-preserving validation tier."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Sequence, Tuple


TIERS = {
    "L1": ["rtk git diff --check", "rtk scripts/check-doc-sync.sh ."],
    "L2": ["rtk git diff --check", "rtk bash <targeted-tests>"],
    "L3": [
        "rtk bash tests/run_all.sh --fail-fast",
        "rtk bash agent-dev-kit/tests/run_all.sh --quick",
        "rtk scripts/check-all.sh --quick --working-tree",
    ],
    "L4": [
        "rtk bash agent-dev-kit/scripts/run-local-ci-parity.sh --python all --mode full",
        "rtk bash tests/run_all.sh --fail-fast",
        "rtk scripts/check-all.sh --quick --working-tree",
    ],
}

REFERENCE_ROOTS = {"OpenSpec", "superpowers", "vibeflow", "oh-my-codex", "planning-with-files", "scale-engine"}
RUNTIME_OUTPUT_ROOTS = {"hermes", "hermes_data", "team-codex-assets"}
RELEASE_CRITICAL = (
    "adk.lock",
    "agent-dev-kit",
    "agent-dev-kit/.version-lock",
    "agent-dev-kit/manifest.json",
    "agent-dev-kit/manifest.yaml",
    "agent-dev-kit/pyproject.toml",
    "agent-dev-kit/src/agent_dev_kit/release.py",
    "agent-dev-kit/manifests/software_m5",
    ".github/workflows/release",
    "manifests/software_m5",
    "manifests/product_maturity_scorecard.json",
    "reports/current-status.md",
)
SHARED_CONTRACT = (
    "agent-dev-kit/schemas/",
    "agent-dev-kit/manifests/",
    "agent-dev-kit/src/agent_dev_kit/runtime_control/",
    "agent-dev-kit/src/agent_dev_kit/targets.py",
    "tools/codex_assets/",
    "scripts/check-",
)
CODE_PREFIXES = (
    "agent-dev-kit/src/", "agent-dev-kit/scripts/", "agent-dev-kit/tests/",
    "tools/", "scripts/", "tests/",
)
SSOT_EVIDENCE = (
    "reports/current-status.md", "reports/adk-v", "reports/runtime-evidence/",
    "manifests/", "adk.lock", "agent-dev-kit",
)


def _git(root: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", "--literal-pathspecs", "-C", str(root), *args], check=False, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        raise ValueError("git {} failed".format(" ".join(args)))
    return result.stdout


def _changed_paths(root: Path, base: str, staged: bool, *, workspace_exclusions: bool = True) -> Tuple[List[str], str]:
    diff_args = ["diff", "--no-ext-diff", "--no-textconv", "--ignore-submodules=none"]
    untracked: List[str] = []
    if staged:
        diff_args.append("--cached")
        scope = "staged"
        baseline = "HEAD"
    else:
        scope = "working-tree"
        baseline = base
        untracked = _git(root, "ls-files", "--others", "--exclude-standard", "-z").split("\0")
    revision = [] if staged else [base]
    names = _git(root, *diff_args, "--name-only", "-z", "--diff-filter=ACDMRTUXB", *revision, "--").split("\0")
    paths = sorted(set(item for item in names + untracked if item))
    managed = [path for path in paths if not workspace_exclusions or not _excluded(path)]
    # Bind the baseline as well as the diff. A clean tree is not a universal snapshot.
    baseline_tree = _git(root, "rev-parse", "--verify", baseline + "^{tree}").strip()
    digest = hashlib.sha256()

    def bind(*parts: str) -> None:
        digest.update(json.dumps(parts, ensure_ascii=True, separators=(",", ":")).encode("ascii"))
        digest.update(b"\n")

    bind("managed-diff-v2", scope, baseline_tree, *managed)
    if managed:
        # Exclusions apply before reading or hashing content, not just to tier selection.
        bind(_git(root, *diff_args, "--binary", *revision, "--", *managed))
    if not staged:
        for relative in sorted(set(untracked) & set(managed)):
            path = root / relative
            if path.is_symlink():
                bind("symlink", relative, os.readlink(path))
            elif path.is_file():
                file_digest = hashlib.sha256()
                with path.open("rb") as stream:
                    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                        file_digest.update(chunk)
                bind("file", relative, str(path.stat().st_mode & 0o111), file_digest.hexdigest())
            else:
                raise ValueError("untracked managed path cannot be fingerprinted: " + relative)
        # A parent's patch represents dirty submodules only as '<commit>-dirty'.
        # Hash each changed managed gitlink in its own repository; staged mode
        # intentionally binds the indexed gitlink only, never unstaged child data.
        for entry in _git(root, "ls-files", "--stage", "-z").split("\0"):
            if not entry:
                continue
            metadata, relative = entry.split("\t", 1)
            if metadata.split()[0] != "160000" or relative not in managed:
                continue
            child = root / relative
            if not child.exists():
                bind("gitlink-worktree-absent", relative)
                continue
            if child.is_symlink() or root.resolve() not in child.resolve().parents:
                raise ValueError("managed gitlink escapes repository: " + relative)
            child_root = Path(_git(child, "rev-parse", "--show-toplevel").strip()).resolve()
            if child_root != child.resolve():
                raise ValueError("managed gitlink is not an initialized repository: " + relative)
            _, child_digest = _changed_paths(child, "HEAD", False, workspace_exclusions=False)
            bind("gitlink-worktree", relative, child_digest)
    return paths, digest.hexdigest()


def _excluded(path: str) -> bool:
    return path.split("/", 1)[0] in REFERENCE_ROOTS | RUNTIME_OUTPUT_ROOTS or path.startswith(".cache/")


def _matches(path: str, patterns: Sequence[str]) -> bool:
    return any(path == pattern or path.startswith(pattern) for pattern in patterns)


def classify(paths: Sequence[str], snapshot_sha256: str, scope: str) -> Dict[str, object]:
    excluded = [path for path in paths if _excluded(path)]
    managed = [path for path in paths if path not in excluded]
    release = [path for path in managed if _matches(path, RELEASE_CRITICAL)]
    contracts = [path for path in managed if _matches(path, SHARED_CONTRACT)]
    code = [
        path for path in managed
        if _matches(path, CODE_PREFIXES) and Path(path).suffix not in {".md", ".json", ".jsonl"}
    ]
    evidence_only = bool(managed) and all(
        path.startswith(("docs/", "reports/")) and not _matches(path, SSOT_EVIDENCE)
        for path in managed
    )
    if release:
        tier = "L4"
        reason = "release/version/M5/lock surface changed"
    elif contracts or code:
        tier = "L3"
        reason = "shared contract or executable code changed"
    elif evidence_only:
        tier = "L1"
        reason = "human-facing documentation/evidence-only diff"
    elif managed:
        tier = "L2"
        reason = "bounded non-release repository change"
    else:
        tier = "L1"
        reason = "no managed product change"
    skipped = []
    if tier != "L4":
        skipped.append({"check": "supported-full-parity", "reason": "no release-critical surface changed"})
    if evidence_only:
        skipped.append({"check": "code-regression", "reason": "diff is documentation/evidence-only"})
    return {
        "schema": "llm-agent-validation-plan/v1",
        "status": "planned",
        "scope": scope,
        "snapshot_sha256": snapshot_sha256,
        "snapshot_contract": "managed-diff-v2",
        "tier": tier,
        "reason": reason,
        "managed_paths": managed,
        "excluded_paths": excluded,
        "release_critical_paths": release,
        "shared_contract_paths": contracts,
        "code_paths": code,
        "evidence_only": evidence_only,
        "required_checks": TIERS[tier],
        "deferred_until_clean_commit": [
            "rtk bash agent-dev-kit/scripts/devkit.sh release build --out <out>",
            "rtk bash agent-dev-kit/scripts/devkit.sh release rehearse --previous-artifact <previous> --candidate-artifact <candidate>",
            "rtk scripts/check-all.sh --quick --release-clean",
        ] if tier == "L4" else [],
        "skipped_checks": skipped,
        "release_execution_boundary": "clean-commit-only" if tier == "L4" else "not-applicable",
    }


def main(argv: Sequence[str] = ()) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--base", default="HEAD")
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(list(argv) if argv else None)
    root = Path(args.root).resolve()
    try:
        paths, digest = _changed_paths(root, args.base, args.staged)
        value = classify(paths, digest, "staged" if args.staged else "working-tree")
    except (OSError, ValueError) as exc:
        print("[FAIL] {}".format(exc), file=sys.stderr)
        return 2
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":") if args.summary_json else None))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
