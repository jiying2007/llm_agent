#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="${ROOT}/scripts/check-file-modes.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

expect_fail() {
  local case_name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "[FAIL] negative fixture unexpectedly passed: ${case_name}" >&2
    exit 1
  fi
}

repo="${TMP_DIR}/repo"
linked="${TMP_DIR}/linked-worktree"
mkdir -p "${repo}"
git -C "${repo}" init -q
git -C "${repo}" config user.email "fixture@example.invalid"
git -C "${repo}" config user.name "Fixture"
printf 'plain\n' > "${repo}/plain.txt"
printf '#!/usr/bin/env bash\nexit 0\n' > "${repo}/tool.sh"
chmod 755 "${repo}/tool.sh"
git -C "${repo}" add plain.txt tool.sh
git -C "${repo}" commit -q -m "fixture"
git -C "${repo}" worktree add -q "${linked}" -b linked-fixture

[[ -f "${linked}/.git" ]] || {
  echo "[FAIL] fixture is not a linked worktree" >&2
  exit 1
}
"${CHECKER}" "${linked}" >/dev/null

chmod 755 "${linked}/plain.txt"
expect_fail "unexpected executable bit" "${CHECKER}" "${linked}"
"${CHECKER}" "${linked}" --fix >/dev/null
"${CHECKER}" "${linked}" >/dev/null

chmod 644 "${linked}/tool.sh"
expect_fail "missing executable bit" "${CHECKER}" "${linked}"
"${CHECKER}" "${linked}" --fix >/dev/null
"${CHECKER}" "${linked}" >/dev/null

rm "${linked}/plain.txt"
"${CHECKER}" "${linked}" >/dev/null

echo "[PASS] file-mode checker supports linked worktrees and preserves mode policy"
