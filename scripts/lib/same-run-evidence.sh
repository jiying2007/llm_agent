#!/usr/bin/env bash

# Same-run evidence helpers for the root aggregate gate.
#
# This library deliberately does not enable `set -euo pipefail`: it is sourced by
# callers that own their shell policy. Evidence is an optimization only. Callers
# must fall back to the original command whenever any helper returns non-zero.

llm_agent_process_start_token() {
  local process_id="$1"
  python3 - "${process_id}" <<'PY'
import pathlib
import sys

pid = sys.argv[1]
raw = pathlib.Path(f"/proc/{pid}/stat").read_text(encoding="utf-8")
end = raw.rfind(")")
if end < 0:
    raise SystemExit(1)
fields_after_comm = raw[end + 2 :].split()
# /proc/<pid>/stat field 22 is process starttime. fields_after_comm[0] is field 3.
if len(fields_after_comm) <= 19:
    raise SystemExit(1)
print(fields_after_comm[19])
PY
}

llm_agent_workspace_fingerprint() {
  local workspace_root="$1"
  python3 - "${workspace_root}" <<'PY'
import hashlib
import os
import pathlib
import stat
import subprocess
import sys

root = pathlib.Path(sys.argv[1]).resolve()
digest = hashlib.sha256()


def add(label, value):
    if isinstance(value, str):
        value = value.encode("utf-8", errors="surrogateescape")
    label_bytes = label.encode("utf-8")
    digest.update(len(label_bytes).to_bytes(4, "big"))
    digest.update(label_bytes)
    digest.update(len(value).to_bytes(8, "big"))
    digest.update(value)


def git(repo, *args):
    env = dict(os.environ)
    env["GIT_OPTIONAL_LOCKS"] = "0"
    completed = subprocess.run(
        ["git", "-C", os.fspath(repo), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )
    return completed.stdout


def is_git_worktree(repo):
    try:
        return git(repo, "rev-parse", "--is-inside-work-tree").strip() == b"true"
    except (OSError, subprocess.CalledProcessError):
        return False


def add_untracked_file(repo, relative_bytes):
    relative = os.fsdecode(relative_bytes)
    path = repo / relative
    add("untracked-path", relative_bytes)
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        add("untracked-type", b"missing")
        return
    add("untracked-mode", str(stat.S_IFMT(metadata.st_mode)))
    if stat.S_ISLNK(metadata.st_mode):
        add("untracked-symlink", os.readlink(os.fspath(path)))
        return
    if not stat.S_ISREG(metadata.st_mode):
        # Nested repositories and opaque directories are represented by their path
        # and type. The only nested repository in the reuse dependency scope,
        # agent-dev-kit, is fingerprinted separately below.
        add("untracked-type", b"non-regular")
        return
    file_digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            file_digest.update(chunk)
    add("untracked-content-sha256", file_digest.digest())


def add_repo(label, repo):
    add("repo-label", label)
    add("repo-path", os.fspath(repo.resolve()))
    add("repo-head", git(repo, "rev-parse", "HEAD"))
    add(
        "repo-status",
        git(
            repo,
            "status",
            "--porcelain=v2",
            "--untracked-files=all",
            "--ignore-submodules=none",
        ),
    )
    add("repo-diff", git(repo, "diff", "--no-ext-diff", "--binary", "HEAD", "--"))
    untracked = git(repo, "ls-files", "-o", "--exclude-standard", "-z").split(b"\0")
    for relative in sorted(item for item in untracked if item):
        add_untracked_file(repo, relative)


if not is_git_worktree(root):
    raise SystemExit("workspace root is not a Git worktree")

add("fingerprint-schema", "llm-agent-workspace-v1")
add_repo("root", root)

adk = root / "agent-dev-kit"
if is_git_worktree(adk):
    add_repo("agent-dev-kit", adk)
else:
    add("agent-dev-kit", "absent")

print(digest.hexdigest())
PY
}

llm_agent_same_run_init() {
  local evidence_dir="$1"
  local producer_pid="$2"
  local producer_start_token="$3"
  local workspace_root="$4"
  local workspace_fingerprint="$5"

  mkdir -p "${evidence_dir}"
  chmod 700 "${evidence_dir}"
  python3 - \
    "${evidence_dir}/context.json" \
    "${producer_pid}" \
    "${producer_start_token}" \
    "${workspace_root}" \
    "${workspace_fingerprint}" <<'PY'
import json
import os
import pathlib
import sys
import time

target = pathlib.Path(sys.argv[1])
payload = {
    "schema_version": 1,
    "suite": "llm-agent-check-all",
    "producer_pid": int(sys.argv[2]),
    "producer_start_token": sys.argv[3],
    "workspace_root": os.path.realpath(sys.argv[4]),
    "workspace_fingerprint": sys.argv[5],
    "created_at_epoch": int(time.time()),
}
temporary = target.with_suffix(".tmp")
temporary.write_text(
    json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n",
    encoding="utf-8",
)
os.chmod(temporary, 0o600)
os.replace(temporary, target)
PY
}

llm_agent_same_run_record() {
  local evidence_dir="$1"
  local producer_pid="$2"
  local producer_start_token="$3"
  local workspace_root="$4"
  local workspace_fingerprint="$5"
  local check_name="$6"
  local script_path="$7"
  local exit_code="$8"
  local output_path="$9"

  [[ "${check_name}" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [[ -f "${script_path}" && ! -L "${script_path}" ]] || return 1
  [[ -f "${output_path}" && ! -L "${output_path}" ]] || return 1

  python3 - \
    "${evidence_dir}/${check_name}.json" \
    "${producer_pid}" \
    "${producer_start_token}" \
    "${workspace_root}" \
    "${workspace_fingerprint}" \
    "${check_name}" \
    "${script_path}" \
    "${exit_code}" \
    "${output_path}" <<'PY'
import hashlib
import json
import os
import pathlib
import sys


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


target = pathlib.Path(sys.argv[1])
script = pathlib.Path(sys.argv[7]).resolve(strict=True)
output = pathlib.Path(sys.argv[9]).resolve(strict=True)
exit_code = int(sys.argv[8])
payload = {
    "schema_version": 1,
    "suite": "llm-agent-check-all",
    "producer_pid": int(sys.argv[2]),
    "producer_start_token": sys.argv[3],
    "workspace_root": os.path.realpath(sys.argv[4]),
    "workspace_fingerprint": sys.argv[5],
    "check_name": sys.argv[6],
    "script_path": os.fspath(script),
    "script_sha256": sha256(script),
    "exit_code": exit_code,
    "status": "pass" if exit_code == 0 else "fail",
    "output_path": os.fspath(output),
    "output_sha256": sha256(output),
}
temporary = target.with_suffix(".tmp")
temporary.write_text(
    json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n",
    encoding="utf-8",
)
os.chmod(temporary, 0o600)
os.replace(temporary, target)
PY
}

llm_agent_same_run_validate() {
  local evidence_dir="$1"
  local expected_producer_pid="$2"
  local expected_producer_start_token="$3"
  local workspace_root="$4"
  local workspace_fingerprint="$5"
  local check_name="$6"
  local script_path="$7"
  local required_marker="${8:-}"

  [[ "${check_name}" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  python3 - \
    "${evidence_dir}" \
    "${expected_producer_pid}" \
    "${expected_producer_start_token}" \
    "${workspace_root}" \
    "${workspace_fingerprint}" \
    "${check_name}" \
    "${script_path}" \
    "${required_marker}" <<'PY'
import hashlib
import inspect
import json
import os
import pathlib
import stat
import sys


def fail():
    if os.environ.get("LLM_AGENT_REUSE_DEBUG") == "1":
        caller = inspect.currentframe().f_back
        print(
            f"same-run evidence rejected at validator line {caller.f_lineno}",
            file=sys.stderr,
        )
    raise SystemExit(1)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def secure_regular_file(path, owner, require_private=False):
    try:
        metadata = path.lstat()
    except OSError:
        fail()
    if not stat.S_ISREG(metadata.st_mode) or path.is_symlink():
        fail()
    if metadata.st_uid != owner or (
        require_private and metadata.st_mode & 0o022
    ):
        if os.environ.get("LLM_AGENT_REUSE_DEBUG") == "1":
            print(
                "same-run insecure file: "
                f"path={path} owner={metadata.st_uid}/{owner} "
                f"mode={oct(stat.S_IMODE(metadata.st_mode))}",
                file=sys.stderr,
            )
        fail()


evidence_dir = pathlib.Path(sys.argv[1])
expected_pid = int(sys.argv[2])
expected_start = sys.argv[3]
expected_root = os.path.realpath(sys.argv[4])
expected_fingerprint = sys.argv[5]
check_name = sys.argv[6]
expected_script = pathlib.Path(sys.argv[7]).resolve(strict=True)
required_marker = sys.argv[8]
owner = os.getuid()

try:
    directory_metadata = evidence_dir.lstat()
except OSError:
    fail()
if (
    not stat.S_ISDIR(directory_metadata.st_mode)
    or evidence_dir.is_symlink()
    or directory_metadata.st_uid != owner
    or directory_metadata.st_mode & 0o022
):
    fail()

context_path = evidence_dir / "context.json"
metadata_path = evidence_dir / f"{check_name}.json"
secure_regular_file(context_path, owner, require_private=True)
secure_regular_file(metadata_path, owner, require_private=True)
try:
    context = json.loads(context_path.read_text(encoding="utf-8"))
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
except (OSError, UnicodeError, json.JSONDecodeError):
    fail()

for payload in (context, metadata):
    if payload.get("schema_version") != 1:
        fail()
    if payload.get("suite") != "llm-agent-check-all":
        fail()
    if payload.get("producer_pid") != expected_pid:
        fail()
    if payload.get("producer_start_token") != expected_start:
        fail()
    if os.path.realpath(payload.get("workspace_root", "")) != expected_root:
        fail()
    if payload.get("workspace_fingerprint") != expected_fingerprint:
        fail()

if metadata.get("check_name") != check_name:
    fail()
if metadata.get("exit_code") != 0 or metadata.get("status") != "pass":
    fail()
if pathlib.Path(metadata.get("script_path", "")).resolve() != expected_script:
    fail()
secure_regular_file(expected_script, owner)
if metadata.get("script_sha256") != sha256(expected_script):
    fail()

try:
    output_declared = pathlib.Path(metadata.get("output_path", ""))
    output = output_declared.resolve(strict=True)
except (OSError, RuntimeError):
    fail()
if output_declared.is_symlink():
    fail()
if output.parent != evidence_dir.resolve().parent:
    fail()
secure_regular_file(output, owner)
if metadata.get("output_sha256") != sha256(output):
    fail()
if required_marker:
    try:
        lines = output.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        fail()
    if required_marker not in lines:
        fail()

print(os.fspath(output))
PY
}

llm_agent_same_run_report_append() {
  local evidence_dir="$1"
  local report_path="$2"
  local consumer_name="$3"
  local producer_name="$4"

  [[ "${consumer_name}" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [[ "${producer_name}" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  python3 - \
    "${evidence_dir}" \
    "${report_path}" \
    "${consumer_name}" \
    "${producer_name}" <<'PY'
import os
import pathlib
import stat
import sys

evidence_dir = pathlib.Path(sys.argv[1])
report_declared = pathlib.Path(sys.argv[2])
owner = os.getuid()

try:
    evidence_metadata = evidence_dir.lstat()
    report_metadata = report_declared.lstat()
    evidence_parent = evidence_dir.resolve(strict=True).parent
    report = report_declared.resolve(strict=True)
except (OSError, RuntimeError):
    raise SystemExit(1)

if (
    not stat.S_ISDIR(evidence_metadata.st_mode)
    or evidence_dir.is_symlink()
    or evidence_metadata.st_uid != owner
    or evidence_metadata.st_mode & 0o022
):
    raise SystemExit(1)
if (
    not stat.S_ISREG(report_metadata.st_mode)
    or report_declared.is_symlink()
    or report_metadata.st_uid != owner
    or report_metadata.st_mode & 0o022
    or report.parent != evidence_parent
):
    raise SystemExit(1)

flags = os.O_WRONLY | os.O_APPEND
if hasattr(os, "O_NOFOLLOW"):
    flags |= os.O_NOFOLLOW
descriptor = os.open(os.fspath(report_declared), flags)
try:
    line = f"{sys.argv[3]}\t{sys.argv[4]}\n".encode("utf-8")
    if os.write(descriptor, line) != len(line):
        raise SystemExit(1)
finally:
    os.close(descriptor)
PY
}
