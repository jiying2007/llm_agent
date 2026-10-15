"""Repository-local evidence file resolver with fail-closed symlink policy.

Source / evidence identity is path-based.  Resolving an in-repository symlink
before checking is_symlink() silently loses that fact, even if the content hash
happens to match; use this helper for untrusted evidence path inputs.
"""

from __future__ import annotations

from pathlib import Path


def resolve_regular_evidence_path(root: Path, candidate: Path, *, label: str) -> Path:
    """Resolve one in-root path, refusing symlinks at every path component."""
    trusted_root = root.resolve()
    raw = candidate if candidate.is_absolute() else trusted_root / candidate
    if not raw.is_relative_to(trusted_root):
        raise ValueError(f"{label} must stay inside the repository")
    relative = raw.relative_to(trusted_root)
    if ".." in relative.parts:
        raise ValueError(f"{label} must not traverse a parent directory")
    current = trusted_root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"{label} must not contain symlink components")
    resolved = current.resolve()
    if not resolved.is_relative_to(trusted_root):
        raise ValueError(f"{label} escapes the repository")
    return resolved
