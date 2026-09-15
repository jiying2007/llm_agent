from __future__ import annotations

import subprocess
import sys
from collections.abc import Sequence

_COMMAND_MODULES = {
    "gate": "tools.control_plane.gate_runner",
    "status": "tools.control_plane.status_projection",
    "impact": "tools.control_plane.impact",
    "runtime-chain": "tools.control_plane.runtime_chain",
    "consumer-chain": "tools.control_plane.consumer_chain",
    "native-governance": "tools.control_plane.native_repository_governance",
    "runtime-portability": "tools.control_plane.runtime_portability",
    "longitudinal-operation": "tools.control_plane.longitudinal_operation",
    "promotion-evidence": "tools.control_plane.adk_promotion_evidence",
}


def _usage() -> str:
    commands = "\n".join(f"  {name:<20} -> {module}" for name, module in _COMMAND_MODULES.items())
    return (
        "usage: llm-ctl <command> [command args...]\n\n"
        "Typed entrypoint for the llm_agent evidence/composition control plane.\n\n"
        f"commands:\n{commands}\n"
    )


def main(argv: Sequence[str] | None = None) -> int:
    args = list(argv) if argv is not None else sys.argv[1:]
    if not args or args[0] in {"-h", "--help", "help"}:
        print(_usage(), end="")
        return 0
    command = args.pop(0)
    module = _COMMAND_MODULES.get(command)
    if module is None:
        print(f"unknown command: {command}\n\n{_usage()}", file=sys.stderr, end="")
        return 2
    completed = subprocess.run([sys.executable, "-m", module, *args], check=False)
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
