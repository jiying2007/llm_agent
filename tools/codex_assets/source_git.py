"""Read-only Git queries for source identity, isolated from caller configuration."""
from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path


def run(root: Path, *arguments: str, input: bytes | None = None,
        timeout: int = 20) -> subprocess.CompletedProcess[bytes]:
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
    command = ["git", "--no-optional-locks", "--no-replace-objects", "-c", "core.fsmonitor=false",
               "-c", "core.hooksPath=" + os.devnull, "-c", "core.attributesFile=" + os.devnull,
               "-C", str(root)]
    # Status/diff can run a repository's clean/process filter. Disable those
    # commands, including required drivers, before examining worktree content.
    if arguments[:1] in {("status",), ("diff",)}:
        configured = subprocess.run(
            [*command, "config", "--name-only", "--get-regexp", r"^filter\..*\.(clean|smudge|process)$"],
            env=environment, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
        if configured.returncode not in {0, 1}:
            raise ValueError("source Git filters cannot be inspected")
        drivers = set()
        for key in configured.stdout.decode("utf-8").splitlines():
            match = re.fullmatch(r"filter\.([A-Za-z0-9_-]+)\.(clean|smudge|process)", key)
            if match is None:
                raise ValueError("source Git filter identity is unsafe")
            command.extend(["-c", key + "="])
            drivers.add(match.group(1))
        for driver in sorted(drivers):
            command.extend(["-c", "filter." + driver + ".required=false"])
    return subprocess.run([*command, *arguments], input=input, env=environment, check=False,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
