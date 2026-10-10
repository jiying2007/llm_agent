"""Explicit pinned offline Sigstore verification for M5 consumers.

Trust is supplied by the operator, never by the evidence or executable PATH.
Verified payload, bundle, trust root and executable are frozen before execution.
"""

from __future__ import annotations

import hashlib
import argparse
import base64
import json
import os
import re
import subprocess
import tempfile
from contextlib import contextmanager
from contextvars import ContextVar
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

from tools.codex_assets.intake_io import decode_json, read_bytes


# Official Linux amd64 Cosign v3.1.3 is 141,178,250 bytes.
# Keep a finite bound while accepting the pinned production verifier.
MAX_VERIFIER_BYTES = 256 * 1024 * 1024


@dataclass(frozen=True)
class Trust:
    verifier: Path
    verifier_sha256: str
    trusted_root: Path
    trusted_root_sha256: str


_trust: ContextVar[Trust | None] = ContextVar("m5_signature_trust", default=None)


@contextmanager
def using(trust: Trust | None) -> Iterator[None]:
    token = _trust.set(trust)
    try:
        yield
    finally:
        _trust.reset(token)


def add_arguments(parser) -> None:
    parser.add_argument("--cosign-binary")
    parser.add_argument("--cosign-sha256")
    parser.add_argument("--trusted-root")
    parser.add_argument("--trusted-root-sha256")


def from_arguments(args) -> Trust | None:
    values = (args.cosign_binary, args.cosign_sha256, args.trusted_root, args.trusted_root_sha256)
    if not any(values):
        return None
    if not all(values):
        raise ValueError("all four pinned signature verification arguments are required")
    return Trust(Path(values[0]).absolute(), values[1], Path(values[2]).absolute(), values[3])


def verify(payload: bytes, bundle: bytes, *, repository: str) -> dict[str, str]:
    trust = _trust.get()
    if trust is None:
        raise ValueError("explicit pinned cosign binary and trusted root are required")
    if repository not in {"jiying2007/agent-dev-kit", "jiying2007/llm_agent"}:
        raise ValueError("signature repository is not approved")
    for pin in (trust.verifier_sha256, trust.trusted_root_sha256):
        if not isinstance(pin, str) or re.fullmatch(r"[0-9a-f]{64}", pin) is None:
            raise ValueError("signature trust SHA256 pins are invalid")
    binary = read_bytes(trust.verifier.absolute(), label="pinned cosign", max_bytes=MAX_VERIFIER_BYTES)
    root = read_bytes(trust.trusted_root.absolute(), label="pinned trusted root", max_bytes=1024 * 1024)
    if hashlib.sha256(binary).hexdigest() != trust.verifier_sha256:
        raise ValueError("cosign binary digest does not match pin")
    if hashlib.sha256(root).hexdigest() != trust.trusted_root_sha256:
        raise ValueError("trusted-root digest does not match pin")
    with tempfile.TemporaryDirectory(prefix="m5-signature-") as directory:
        frozen = Path(directory)
        executable = frozen / "cosign"
        executable.write_bytes(binary)
        executable.chmod(0o700)
        (frozen / "root.json").write_bytes(root)
        (frozen / "bundle.json").write_bytes(bundle)
        try:
            completed = subprocess.run(
                [str(executable), "verify-blob", "--offline", "--new-bundle-format", "--bundle", str(frozen / "bundle.json"),
                 "--trusted-root", str(frozen / "root.json"), "--certificate-identity",
                 f"https://github.com/{repository}/.github/workflows/ci.yml@refs/heads/main",
                 "--certificate-oidc-issuer", "https://token.actions.githubusercontent.com", "/dev/stdin"],
                input=payload, env={"PATH": os.defpath, "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"},
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False, timeout=45,
            )
        except (OSError, subprocess.SubprocessError) as exc:
            raise ValueError("pinned Sigstore verification could not complete") from exc
    if completed.returncode != 0:
        raise ValueError("pinned Sigstore verification failed")
    return {"evidence_sha256": hashlib.sha256(payload).hexdigest(),
            "attestation_sha256": hashlib.sha256(bundle).hexdigest()}


def prepare_ci_trust(output: Path) -> None:
    """Materialize reviewed public trust data from explicit owner CI variables."""
    for key in ("M5_COSIGN_SHA256", "M5_TRUSTED_ROOT_SHA256"):
        if re.fullmatch(r"[0-9a-f]{64}", os.environ.get(key, "")) is None:
            raise ValueError("M5 owner CI trust configuration is missing or invalid")
    encoded = os.environ.get("M5_TRUSTED_ROOT_BASE64", "")
    if not encoded or len(encoded) > 2 * 1024 * 1024:
        raise ValueError("M5 owner CI trusted root is missing or exceeds budget")
    raw = base64.b64decode(encoded, validate=True)
    if len(raw) > 1024 * 1024 or hashlib.sha256(raw).hexdigest() != os.environ["M5_TRUSTED_ROOT_SHA256"]:
        raise ValueError("M5 owner CI trusted root does not match reviewed pin")
    if not isinstance(decode_json(raw, label="owner CI trusted root"), dict):
        raise ValueError("M5 owner CI trusted root must be an object")
    output = output.absolute()
    if output.exists() or output.is_symlink() or any(parent.is_symlink() for parent in output.parents):
        raise ValueError("CI trusted-root output must be new and without links")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as stream:
        stream.write(raw)


def main() -> int:
    parser = argparse.ArgumentParser(description="Prepare reviewed CI trust data; never authorize a release")
    parser.add_argument("--ci-trusted-root-output", required=True)
    args = parser.parse_args()
    try:
        prepare_ci_trust(Path(args.ci_trusted_root_output))
    except (ValueError, OSError, RuntimeError) as exc:
        print(json.dumps({"status": "blocked", "error": str(exc)}))
        return 1
    print(json.dumps({"status": "prepared", "release_authorized": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
