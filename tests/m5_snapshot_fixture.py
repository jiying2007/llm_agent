"""Copy owned source only; never copy worktrees, caches or reference payloads."""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def snapshot(source, destination, extra=(), *, include_subrepos=True):
    subprocess.run(["git", "clone", "--shared", "--no-checkout", "--quiet",
                    str(source), str(destination)], check=True)
    subprocess.run(["git", "-C", str(destination), "read-tree", "HEAD"], check=True)
    files = {name for name in git(source, "ls-files", "-z").decode().split("\0") if name}
    files.update(extra)
    for name in sorted(files):
        src, dst = source / name, destination / name
        if src.is_symlink():
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.symlink_to(src.readlink())
        elif src.is_file():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
    for entry in git(source, "ls-files", "--stage", "-z").decode().split("\0"):
        if include_subrepos and entry.startswith("160000 "):
            child = entry.split("\t", 1)[1]
            marker = source / child / ".git"
            if marker.exists() and subprocess.run(
                    ["git", "-C", str(source / child), "rev-parse", "--git-dir"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                snapshot(source / child, destination / child)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--owned-only", action="store_true")
    args = parser.parse_args()
    source, destination = args.source, args.destination
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from tools.codex_assets.validation_plan import _changed_paths
    changed, _ = _changed_paths(source, "HEAD", False)
    snapshot(source, destination, changed, include_subrepos=not args.owned_only)
