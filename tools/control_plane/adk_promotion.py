from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from collections.abc import Mapping
from dataclasses import asdict, dataclass
from pathlib import Path

from tools.control_plane.adk_interface import render_interface_lock
from tools.control_plane.receipts import bind_receipt, write_receipt
from tools.control_plane.status_projection import project, refresh_current_status

LOCK_SCHEMA = "llm-agent-adk-lock/v2"
PROMOTION_SCHEMA = "llm-agent-adk-promotion/v4"
INTERFACE_PATH = "manifests/adk_interface.lock.json"
EVIDENCE_PATH = "reports/promotion/agent-dev-kit/promotion-evidence.json"
ATTESTATION_PATH = "reports/promotion/agent-dev-kit/promotion-attestation.json"
PROMOTION_PATHS = (
    "agent-dev-kit",
    "adk.lock",
    INTERFACE_PATH,
    "reports/current-status.md",
    EVIDENCE_PATH,
    ATTESTATION_PATH,
)


@dataclass(frozen=True)
class CandidateIdentity:
    version: str
    commit: str
    tree: str
    manifest_blob: str


def _git(cwd: Path, *args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout.strip()


def _git_stdout_preserve(cwd: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"git {' '.join(args)} failed")
    return completed.stdout


def _root_identity(root: Path) -> dict[str, str]:
    values = _git(root, "rev-parse", "HEAD", "HEAD^{tree}").splitlines()
    if len(values) != 2:
        raise RuntimeError("unable to resolve root source identity")
    return {"head": values[0], "tree": values[1]}


def candidate_identity(candidate_dir: Path, ref: str) -> CandidateIdentity:
    commit = _git(candidate_dir, "rev-parse", f"{ref}^{{commit}}")
    tree = _git(candidate_dir, "rev-parse", f"{commit}^{{tree}}")
    manifest_text = _git(candidate_dir, "show", f"{commit}:manifest.json")
    manifest = json.loads(manifest_text)
    version = manifest.get("version")
    if not isinstance(version, str) or not version:
        raise RuntimeError("candidate manifest.json is missing version")
    manifest_blob = _git(candidate_dir, "rev-parse", f"{commit}:manifest.json")
    return CandidateIdentity(version=version, commit=commit, tree=tree, manifest_blob=manifest_blob)


def render_lock(identity: CandidateIdentity, updated_at: str) -> str:
    return (
        f"schema={LOCK_SCHEMA}\n"
        f"agent-dev-kit.version={identity.version}\n"
        f"agent-dev-kit.commit={identity.commit}\n"
        f"agent-dev-kit.tree={identity.tree}\n"
        f"agent-dev-kit.manifest_blob={identity.manifest_blob}\n"
        f"updated_at={updated_at}\n"
    )


def _staged_paths(root: Path) -> list[str]:
    output = _git(root, "diff", "--cached", "--name-only", "--diff-filter=ACDMRTUXB")
    return sorted(line for line in output.splitlines() if line)


def _root_clean_for_promotion(root: Path) -> bool:
    if _staged_paths(root):
        return False
    status = _git_stdout_preserve(root, "status", "--porcelain=v1", "--untracked-files=all")
    allowed = {"agent-dev-kit"}
    for line in status.splitlines():
        if not line:
            continue
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if path not in allowed:
            return False
    return True


def _current_gitlink(root: Path) -> str:
    value = _git(root, "ls-files", "-s", "agent-dev-kit")
    fields = value.split()
    if len(fields) < 2 or fields[0] != "160000":
        raise RuntimeError("agent-dev-kit is not a tracked gitlink")
    return fields[1]


def _atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def _restore(path: Path, previous: str | None) -> None:
    if previous is None:
        path.unlink(missing_ok=True)
    else:
        _atomic_write(path, previous)


def _read_json_text(path: Path, label: str) -> tuple[str, Mapping[str, object]]:
    text = path.read_text(encoding="utf-8")
    value = json.loads(text)
    if not isinstance(value, Mapping):
        raise RuntimeError(f"{label} root must be a JSON object")
    return text, value


def _validate_portable_inputs(
    identity: CandidateIdentity,
    evidence_path: Path,
    attestation_path: Path,
) -> tuple[str, str]:
    evidence_text, evidence = _read_json_text(evidence_path, "promotion evidence")
    source = evidence.get("source")
    provenance = evidence.get("provenance")
    if evidence.get("schema") != "adk-promotion-evidence/v1":
        raise RuntimeError("promotion evidence schema must be adk-promotion-evidence/v1")
    if not isinstance(source, Mapping):
        raise RuntimeError("promotion evidence source must be an object")
    expected = asdict(identity)
    for key, value in expected.items():
        if source.get(key) != value:
            raise RuntimeError(f"promotion evidence source.{key} does not match candidate identity")
    if not isinstance(provenance, Mapping):
        raise RuntimeError("promotion evidence provenance must be an object")
    if provenance.get("subject") != "promotion-evidence.json" or provenance.get("format") != "sigstore-bundle/v1":
        raise RuntimeError("promotion evidence provenance contract is invalid")

    attestation_text, attestation = _read_json_text(attestation_path, "promotion attestation")
    if not attestation:
        raise RuntimeError("promotion attestation bundle must not be empty")
    return evidence_text, attestation_text


def _rollback_transaction(
    root: Path,
    lock_path: Path,
    interface_path: Path,
    status_path: Path,
    evidence_path: Path,
    attestation_path: Path,
    previous_lock: str | None,
    previous_interface: str | None,
    previous_status: str | None,
    previous_evidence: str | None,
    previous_attestation: str | None,
) -> None:
    _restore(lock_path, previous_lock)
    _restore(interface_path, previous_interface)
    _restore(status_path, previous_status)
    _restore(evidence_path, previous_evidence)
    _restore(attestation_path, previous_attestation)
    _git(root, "reset", "-q", "HEAD", "--", *PROMOTION_PATHS, check=False)


def apply_promotion(
    root: Path,
    identity: CandidateIdentity,
    lock_text: str,
    interface_text: str,
    evidence_text: str,
    attestation_text: str,
) -> list[str]:
    if not _root_clean_for_promotion(root):
        raise RuntimeError(
            "promotion requires a clean index and an isolated worktree; only the agent-dev-kit worktree may differ"
        )

    lock_path = root / "adk.lock"
    interface_path = root / INTERFACE_PATH
    status_path = root / "reports" / "current-status.md"
    evidence_path = root / EVIDENCE_PATH
    attestation_path = root / ATTESTATION_PATH
    previous_lock = lock_path.read_text(encoding="utf-8") if lock_path.exists() else None
    previous_interface = interface_path.read_text(encoding="utf-8") if interface_path.exists() else None
    previous_status = status_path.read_text(encoding="utf-8") if status_path.exists() else None
    previous_evidence = evidence_path.read_text(encoding="utf-8") if evidence_path.exists() else None
    previous_attestation = attestation_path.read_text(encoding="utf-8") if attestation_path.exists() else None
    previous_gitlink = _current_gitlink(root)
    if identity.commit == previous_gitlink:
        raise RuntimeError("candidate ADK commit is already pinned; promotion requires a new commit")

    try:
        _atomic_write(lock_path, lock_text)
        _atomic_write(interface_path, interface_text)
        _atomic_write(evidence_path, evidence_text)
        _atomic_write(attestation_path, attestation_text)
        _git(root, "update-index", "--add", "--cacheinfo", f"160000,{identity.commit},agent-dev-kit")
        refresh_current_status(root)
        _git(
            root,
            "add",
            "--",
            "adk.lock",
            INTERFACE_PATH,
            "reports/current-status.md",
            EVIDENCE_PATH,
            ATTESTATION_PATH,
        )

        staged_paths = _staged_paths(root)
        expected_paths = sorted(PROMOTION_PATHS)
        if staged_paths != expected_paths:
            raise RuntimeError(
                "promotion staged transaction is incomplete: "
                f"expected={expected_paths}, actual={staged_paths}"
            )

        completed = subprocess.run(
            ["bash", "scripts/check-adk-lock.sh", ".", "--pin-only"],
            cwd=root,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        if completed.returncode != 0:
            raise RuntimeError("post-apply pin validation failed: " + completed.stdout.strip())
        projection = project(root, dt.date.today())
        if projection.get("status") != "pass":
            raise RuntimeError("post-apply status projection validation failed")
        return staged_paths
    except Exception:
        _rollback_transaction(
            root,
            lock_path,
            interface_path,
            status_path,
            evidence_path,
            attestation_path,
            previous_lock,
            previous_interface,
            previous_status,
            previous_evidence,
            previous_attestation,
        )
        raise


def promotion_receipt(
    *,
    root: Path,
    before_gitlink: str,
    identity: CandidateIdentity,
    updated_at: str,
    mode: str,
    status: str,
    lock_lines: list[str],
    interface_sha256: str,
    evidence_sha256: str | None,
    attestation_sha256: str | None,
    staged_paths: list[str],
) -> dict[str, object]:
    payload: dict[str, object] = {
        "schema": PROMOTION_SCHEMA,
        "mode": mode,
        "status": status,
        "source": _root_identity(root),
        "before_gitlink": before_gitlink,
        "candidate": asdict(identity),
        "lock_schema": LOCK_SCHEMA,
        "lock": lock_lines,
        "interface_schema": "llm-agent-adk-interface-lock/v1",
        "interface_sha256": interface_sha256,
        "promotion_evidence_sha256": evidence_sha256,
        "promotion_attestation_sha256": attestation_sha256,
        "staged_paths": staged_paths,
        "staged_transaction_complete": staged_paths == sorted(PROMOTION_PATHS),
        "updated_at": updated_at,
        "requires_fresh_cross_repo_verification": True,
        "verification_model": "portable-attested-evidence",
        "release_authorized": False,
    }
    return bind_receipt(payload)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Plan or apply an atomic ADK source+portable-evidence promotion"
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--candidate-dir", default="agent-dev-kit")
    parser.add_argument("--ref", default="HEAD")
    parser.add_argument("--updated-at", required=True, help="Explicit YYYY-MM-DD provenance date")
    parser.add_argument("--promotion-evidence", help="Portable ADK promotion-evidence.json")
    parser.add_argument("--promotion-attestation", help="Detached Sigstore promotion attestation bundle")
    parser.add_argument(
        "--apply",
        action="store_true",
        help=(
            "Stage gitlink, lock, interface, generated current-status, promotion evidence and attestation "
            "as one transaction; default is dry-run"
        ),
    )
    parser.add_argument("--receipt-out", help="Atomically write the content-addressed promotion receipt")
    parser.add_argument("--summary-json", action="store_true")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    candidate_dir = Path(args.candidate_dir)
    if not candidate_dir.is_absolute():
        candidate_dir = (root / candidate_dir).resolve()

    try:
        identity = candidate_identity(candidate_dir, args.ref)
        lock_text = render_lock(identity, args.updated_at)
        interface_text = render_interface_lock(asdict(identity), args.updated_at)
        lock_lines = lock_text.splitlines()
        before = _current_gitlink(root)
        mode = "apply" if args.apply else "dry-run"
        status = "planned"
        staged_paths: list[str] = []
        evidence_text: str | None = None
        attestation_text: str | None = None
        if args.promotion_evidence or args.promotion_attestation or args.apply:
            if not args.promotion_evidence or not args.promotion_attestation:
                raise RuntimeError("promotion evidence and attestation are both required for an applied promotion")
            evidence_text, attestation_text = _validate_portable_inputs(
                identity,
                Path(args.promotion_evidence),
                Path(args.promotion_attestation),
            )
        if args.apply:
            assert evidence_text is not None and attestation_text is not None
            staged_paths = apply_promotion(
                root,
                identity,
                lock_text,
                interface_text,
                evidence_text,
                attestation_text,
            )
            status = "applied-not-verified"
        result = promotion_receipt(
            root=root,
            before_gitlink=before,
            identity=identity,
            updated_at=args.updated_at,
            mode=mode,
            status=status,
            lock_lines=lock_lines,
            interface_sha256=hashlib.sha256(interface_text.encode("utf-8")).hexdigest(),
            evidence_sha256=hashlib.sha256(evidence_text.encode("utf-8")).hexdigest() if evidence_text else None,
            attestation_sha256=(
                hashlib.sha256(attestation_text.encode("utf-8")).hexdigest() if attestation_text else None
            ),
            staged_paths=staged_paths,
        )
        if args.receipt_out:
            write_receipt(Path(args.receipt_out), result)
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        failure = bind_receipt({"schema": PROMOTION_SCHEMA, "status": "fail", "error": str(exc)})
        print(f"[FAIL] {exc}", file=sys.stderr)
        if args.summary_json:
            print(json.dumps(failure, ensure_ascii=False, sort_keys=True))
        return 1

    if args.summary_json:
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    else:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
