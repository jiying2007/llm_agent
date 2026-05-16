#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIX=0

if [[ $# -gt 0 && "${1}" != -* ]]; then
  ROOT="$1"
  shift
fi

for arg in "$@"; do
  case "${arg}" in
    --fix)
      FIX=1
      ;;
    -h|--help)
      cat <<USAGE
usage: scripts/check-file-modes.sh [root] [--fix]

Checks tracked regular files against Git index modes:
  100644 -> not executable
  100755 -> executable

Use --fix to chmod the working tree to match the index.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: ${arg}" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "${ROOT}/.git" ]]; then
  echo "[FAIL] not a git repository: ${ROOT}" >&2
  exit 1
fi

missing=0
unexpected_exec=0
missing_exec=0

while IFS= read -r -d '' record; do
  mode="${record%% *}"
  path="${record#*$'\t'}"

  case "${mode}" in
    100644|100755) ;;
    *) continue ;;
  esac

  full_path="${ROOT}/${path}"
  if [[ ! -f "${full_path}" ]]; then
    echo "[FAIL] tracked file missing: ${path}" >&2
    missing=$((missing + 1))
    continue
  fi

  if [[ "${mode}" == "100755" ]]; then
    if [[ ! -x "${full_path}" ]]; then
      missing_exec=$((missing_exec + 1))
      if [[ "${FIX}" -eq 1 ]]; then
        echo "[FIX] add executable bit: ${path}"
        chmod 755 "${full_path}"
      else
        echo "[FAIL] missing executable bit: ${path}" >&2
      fi
    fi
  else
    if [[ -x "${full_path}" ]]; then
      unexpected_exec=$((unexpected_exec + 1))
      if [[ "${FIX}" -eq 1 ]]; then
        echo "[FIX] remove executable bit: ${path}"
        chmod 644 "${full_path}"
      else
        echo "[FAIL] unexpected executable bit: ${path}" >&2
      fi
    fi
  fi
done < <(git -C "${ROOT}" ls-files -z -s)

total=$((missing + unexpected_exec + missing_exec))
if [[ "${total}" -ne 0 ]]; then
  if [[ "${FIX}" -eq 1 ]]; then
    if [[ "${missing}" -eq 0 ]]; then
      echo "[PASS] file modes normalized: unexpected_exec=${unexpected_exec} missing_exec=${missing_exec}"
      exit 0
    fi
    echo "[FAIL] file modes partially normalized but tracked files are missing: missing=${missing}" >&2
    exit 1
  fi
  echo "[FAIL] file mode drift found: missing=${missing} unexpected_exec=${unexpected_exec} missing_exec=${missing_exec}" >&2
  echo "[INFO] run scripts/check-file-modes.sh ${ROOT} --fix to normalize working tree permissions" >&2
  exit 1
fi

echo "[PASS] file modes match git index"
