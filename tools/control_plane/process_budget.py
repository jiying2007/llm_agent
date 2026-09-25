"""Bounded, shell-free subprocess I/O for repository evidence collection."""

from __future__ import annotations

import os
import queue
import signal
import subprocess
import threading
import time
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import BinaryIO


class ProcessBudgetError(RuntimeError):
    """A command exceeded its declared wall-clock or byte budget."""


def run_bounded(
    command: Sequence[str],
    cwd: Path | None = None,
    *,
    timeout: float = 60.0,
    max_stdout: int = 2 * 1024 * 1024,
    max_stderr: int = 64 * 1024,
    stdout_sink: BinaryIO | None = None,
    env: Mapping[str, str] | None = None,
) -> subprocess.CompletedProcess[bytes]:
    """Drain both pipes concurrently; cap memory even when stdout goes to disk."""
    if not command or any(not isinstance(part, str) or "\0" in part for part in command):
        raise ValueError("command must contain non-NUL string arguments")
    if not 0 < timeout < float("inf") or isinstance(timeout, bool):
        raise ValueError("timeout must be positive and finite")
    if any(not isinstance(n, int) or isinstance(n, bool) or n <= 0 for n in (max_stdout, max_stderr)):
        raise ValueError("output budgets must be positive integers")
    process = subprocess.Popen(
        list(command), cwd=cwd, env=env, stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        start_new_session=os.name == "posix",
    )
    events: queue.Queue[tuple[int, bytes | BaseException | None]] = queue.Queue(maxsize=8)
    stopped = threading.Event()

    def put(item: tuple[int, bytes | BaseException | None]) -> None:
        while not stopped.is_set():
            try:
                events.put(item, timeout=0.05)
                return
            except queue.Full:
                continue

    def drain(index: int, pipe: BinaryIO) -> None:
        try:
            while not stopped.is_set():
                chunk = os.read(pipe.fileno(), 64 * 1024)
                if not chunk:
                    break
                put((index, chunk))
        except OSError as exc:
            put((index, exc))
        finally:
            put((index, None))

    assert process.stdout is not None and process.stderr is not None
    pipes = (process.stdout, process.stderr)
    readers = [threading.Thread(target=drain, args=(i, pipe), daemon=True) for i, pipe in enumerate(pipes)]
    for reader in readers:
        reader.start()
    deadline = time.monotonic() + timeout
    counts = [0, 0]
    output = [bytearray(), bytearray()]
    closed: set[int] = set()
    try:
        while len(closed) != 2:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise ProcessBudgetError("command timeout exceeded")
            try:
                index, chunk = events.get(timeout=min(remaining, 0.05))
            except queue.Empty:
                continue
            if chunk is None:
                closed.add(index)
                continue
            if isinstance(chunk, BaseException):
                raise RuntimeError("unable to read command output") from chunk
            counts[index] += len(chunk)
            if counts[index] > (max_stdout, max_stderr)[index]:
                raise ProcessBudgetError("command {} byte budget exceeded".format(("stdout", "stderr")[index]))
            if index == 0 and stdout_sink is not None:
                stdout_sink.write(chunk)
            else:
                output[index].extend(chunk)
        try:
            return_code = process.wait(timeout=max(0.001, deadline - time.monotonic()))
        except subprocess.TimeoutExpired as exc:
            raise ProcessBudgetError("command timeout exceeded") from exc
        return subprocess.CompletedProcess(list(command), return_code, bytes(output[0]), bytes(output[1]))
    finally:
        stopped.set()
        if os.name == "posix":
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        elif process.poll() is None:
            process.kill()
        process.wait(timeout=5)
        for reader in readers:
            reader.join(timeout=1)
        for pipe in pipes:
            pipe.close()
