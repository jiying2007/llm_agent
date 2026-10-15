#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Strictly local adversarial fixtures: no runtime/provider calls, no network.
python3 - <<'PY'
import tempfile
from pathlib import Path

from tools.control_plane.evidence_paths import resolve_regular_evidence_path
from tools.control_plane.effect_readiness import _safe_path
from tools.control_plane.longitudinal_operation import LongitudinalError, _repo_file
from tools.control_plane.terminal_closure import _git_blob_sha1, _indexed_object

with tempfile.TemporaryDirectory(prefix="evidence-path-contract-") as temporary:
    root = Path(temporary).resolve()
    evidence_root = root / "reports" / "runtime-evidence" / "test-campaign"
    evidence_root.mkdir(parents=True)
    real = evidence_root / "real.json"
    real.write_text('{"status":"fixture"}\n', encoding="utf-8")
    relative = real.relative_to(root).as_posix()
    ref = {"path": relative, "git_blob_sha1": _git_blob_sha1(real)}
    assert _indexed_object(root, evidence_root, ref, "safe")[0]["status"] == "fixture"
    assert _repo_file(root, relative, "safe") == real
    assert _safe_path(root, evidence_root, relative, "safe") == real
    assert resolve_regular_evidence_path(root, Path(relative), label="safe") == real

    leaf = evidence_root / "leaf-link.json"
    leaf.symlink_to(real.name)
    nested_dir = evidence_root / "nested"
    nested_dir.mkdir()
    (nested_dir / "real.json").write_bytes(real.read_bytes())
    dir_link = evidence_root / "dir-link"
    dir_link.symlink_to(nested_dir.name, target_is_directory=True)
    refs = (
        leaf.relative_to(root).as_posix(),
        (dir_link / "real.json").relative_to(root).as_posix(),
    )
    for item in refs:
        for label, thunk in (
            ("G9", lambda item=item: _indexed_object(
                root, evidence_root,
                {"path": item, "git_blob_sha1": _git_blob_sha1(real)}, "G9"
            )),
            ("G22", lambda item=item: _safe_path(root, evidence_root, item, "G22")),
            ("LTA-04", lambda item=item: _repo_file(root, item, "LTA-04")),
        ):
            try:
                thunk()
            except (ValueError, LongitudinalError) as exc:
                assert "symlink" in str(exc).lower(), (label, item, exc)
            else:
                raise AssertionError(f"{label} accepted symlink path: {item}")

    # A symlink outside root is also forbidden; no untrusted external file reads.
    external = root.parent / "outside-path-fixture.json"
    outside = evidence_root / "outside-link.json"
    outside.symlink_to(external)
    for thunk in (
        lambda: _safe_path(root, evidence_root, outside.relative_to(root).as_posix(), "outside"),
        lambda: _repo_file(root, outside.relative_to(root).as_posix(), "outside"),
    ):
        try:
            thunk()
        except (ValueError, LongitudinalError) as exc:
            assert "symlink" in str(exc).lower(), exc
        else:
            raise AssertionError("external symlink accepted")
print("[PASS] evidence file paths reject leaf and parent symlinks")
PY
