#!/usr/bin/env bash
set -euo pipefail

# check-wechat-intake-ledger.sh
#
# Pure checkouts validate the committed ledger against a hash-bound snapshot
# manifest. When the external article corpus is available, the checker also
# regenerates the ledger and compares it byte-for-byte.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTICLES_DIR=""
REQUIRE_CORPUS=0
ROOT_SET=0
MIN_ARTICLES="${WECHAT_INTAKE_MIN_ARTICLES:-300}"

[[ "${MIN_ARTICLES}" =~ ^[1-9][0-9]*$ ]] || {
  echo "[FAIL] WECHAT_INTAKE_MIN_ARTICLES must be a positive integer" >&2
  exit 1
}

usage() {
  cat <<USAGE
Usage:
  scripts/check-wechat-intake-ledger.sh [root] [options]

Options:
  --articles-dir <path>  External article corpus. Defaults to <root>/wechat-articles.
  --require-corpus       Fail unless the article corpus is available for strict regeneration.
  -h, --help             Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --articles-dir)
      [[ $# -ge 2 ]] || { echo "[FAIL] --articles-dir requires a path" >&2; exit 1; }
      ARTICLES_DIR="$2"
      shift 2
      ;;
    --require-corpus)
      REQUIRE_CORPUS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "[FAIL] unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      [[ "${ROOT_SET}" -eq 0 ]] || { echo "[FAIL] multiple workspace roots provided" >&2; exit 1; }
      ROOT="$1"
      ROOT_SET=1
      shift
      ;;
  esac
done

ROOT="$(cd "${ROOT}" && pwd)"
ARTICLES_DIR="${ARTICLES_DIR:-${ROOT}/wechat-articles}"
LEDGER="${ROOT}/reports/wechat-article-intake.jsonl"
MANIFEST="${ROOT}/reports/wechat-article-intake.manifest.json"
GENERATOR="${ROOT}/scripts/generate-wechat-intake-ledger.sh"
DECISIONS="${ROOT}/reports/wechat-article-decisions.tsv"

[[ -x "${GENERATOR}" || -f "${GENERATOR}" ]] || {
  echo "[FAIL] missing generator: ${GENERATOR}" >&2
  exit 1
}

[[ -f "${LEDGER}" ]] || {
  echo "[FAIL] missing ledger: ${LEDGER}" >&2
  echo "Run with the source corpus: rtk scripts/generate-wechat-intake-ledger.sh" >&2
  exit 1
}

[[ -f "${MANIFEST}" ]] || {
  echo "[FAIL] missing portable snapshot manifest: ${MANIFEST}" >&2
  echo "Run with the source corpus: rtk scripts/generate-wechat-intake-ledger.sh" >&2
  exit 1
}

snapshot_count="$({
  python3 - "${ROOT}" "${LEDGER}" "${MANIFEST}" "${DECISIONS}" "${MIN_ARTICLES}" <<'PY'
import csv
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
ledger_path = pathlib.Path(sys.argv[2]).resolve()
manifest_path = pathlib.Path(sys.argv[3]).resolve()
decisions_path = pathlib.Path(sys.argv[4]).resolve()
minimum_articles = int(sys.argv[5])


def fail(message: str) -> None:
    raise SystemExit("[FAIL] {}".format(message))


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


required_keys = {
    "id",
    "path",
    "category",
    "title",
    "chars",
    "priority",
    "batch",
    "topics",
    "candidate_type",
    "risk",
    "external_code",
    "external_code_policy",
    "code_links",
    "decision",
    "status",
    "target_asset",
    "evidence",
}
rows = []
for line_no, line in enumerate(ledger_path.read_text(encoding="utf-8").splitlines(), 1):
    if not line.strip():
        fail("ledger contains a blank row at line {}".format(line_no))
    try:
        row = json.loads(line)
    except json.JSONDecodeError as exc:
        fail("invalid ledger JSON at line {}: {}".format(line_no, exc))
    if not isinstance(row, dict):
        fail("ledger row {} must be an object".format(line_no))
    missing = sorted(required_keys.difference(row))
    if missing:
        fail("ledger row {} missing keys: {}".format(line_no, ", ".join(missing)))
    expected_id = "wechat-{:04d}".format(line_no)
    if row.get("id") != expected_id:
        fail("ledger row {} has non-sequential id: {}".format(line_no, row.get("id")))
    article_path = str(row.get("path", ""))
    if not article_path.startswith("wechat-articles/") or ".." in pathlib.PurePosixPath(article_path).parts:
        fail("ledger row {} has unsafe article path".format(line_no))
    if row.get("external_code") is True and row.get("external_code_policy") != "report-only-until-security-review":
        fail("ledger row {} violates external-code report-only policy".format(line_no))
    rows.append(row)

if len(rows) < minimum_articles:
    fail("unexpected ledger row count: {} (<{})".format(len(rows), minimum_articles))

known_ids = {str(row["id"]) for row in rows}
if len(known_ids) != len(rows):
    fail("ledger contains duplicate ids")

decision_sha = None
if decisions_path.exists():
    with decisions_path.open("r", encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        required_columns = {"id", "decision", "status", "target_asset", "evidence", "notes"}
        if reader.fieldnames is None or not required_columns.issubset(set(reader.fieldnames)):
            fail("decisions header is missing required columns")
        decision_ids = []
        for row_no, row in enumerate(reader, 2):
            row_id = str(row.get("id", "")).strip()
            if not row_id:
                fail("decisions row {} has an empty id".format(row_no))
            if row_id not in known_ids:
                fail("decisions row {} references unknown id {}".format(row_no, row_id))
            decision_ids.append(row_id)
        if len(decision_ids) != len(set(decision_ids)):
            fail("decisions file contains duplicate ids")
    decision_sha = sha256(decisions_path)

try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    fail("invalid portable snapshot manifest: {}".format(exc))

expected = {
    "schema_version": 1,
    "artifact_kind": "wechat-intake-portable-snapshot",
    "source_mode": "external-untracked-corpus",
    "logical_corpus_path": "wechat-articles",
    "article_count": len(rows),
    "ledger_path": "reports/wechat-article-intake.jsonl",
    "ledger_sha256": sha256(ledger_path),
    "decisions_path": "reports/wechat-article-decisions.tsv" if decisions_path.exists() else None,
    "decisions_sha256": decision_sha,
    "strict_live_check_required_when_corpus_present": True,
}
if manifest != expected:
    differing = sorted(key for key in set(manifest) | set(expected) if manifest.get(key) != expected.get(key))
    fail("portable snapshot manifest mismatch: {}".format(", ".join(differing)))

print(len(rows))
PY
} 2>&1)" || {
  echo "${snapshot_count}" >&2
  exit 1
}

if [[ -e "${ARTICLES_DIR}" && ! -d "${ARTICLES_DIR}" ]]; then
  echo "[FAIL] article corpus path is not a directory: ${ARTICLES_DIR}" >&2
  exit 1
fi

if [[ ! -d "${ARTICLES_DIR}" ]]; then
  if [[ "${REQUIRE_CORPUS}" -eq 1 ]]; then
    echo "[FAIL] strict live corpus check requested but directory is missing: ${ARTICLES_DIR}" >&2
    exit 1
  fi
  echo "[OK] wechat intake ledger portable snapshot healthy: articles=${snapshot_count} mode=committed-snapshot"
  exit 0
fi

article_count="$(find "${ARTICLES_DIR}" -type f -name '*.md' ! -path "${ARTICLES_DIR}/_reports/*" ! -name 'INDEX.md' ! -name 'REPORT.md' | wc -l | tr -d ' ')"
if [[ "${article_count}" -lt "${MIN_ARTICLES}" ]]; then
  echo "[FAIL] unexpected live article count: ${article_count} (<${MIN_ARTICLES})" >&2
  exit 1
fi
if [[ "${article_count}" != "${snapshot_count}" ]]; then
  echo "[FAIL] ledger/live article count mismatch: ledger=${snapshot_count} articles=${article_count}" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT
bash "${GENERATOR}" \
  --root "${ROOT}" \
  --articles-dir "${ARTICLES_DIR}" \
  --out "${tmp}" \
  --decisions "${DECISIONS}" \
  --no-batch-report \
  --no-manifest >/dev/null
if ! cmp -s "${tmp}" "${LEDGER}"; then
  echo "[FAIL] ledger is stale against the live article corpus; regenerate it with:" >&2
  echo "  rtk scripts/generate-wechat-intake-ledger.sh --articles-dir '${ARTICLES_DIR}'" >&2
  exit 1
fi

echo "[OK] wechat intake ledger healthy: articles=${article_count} mode=live-corpus"
