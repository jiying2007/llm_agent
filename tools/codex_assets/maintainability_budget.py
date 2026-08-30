"""Deterministic maintainability growth budgets for llm_agent and agent-dev-kit."""

from __future__ import annotations

import argparse
import ast
import fnmatch
import hashlib
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


ALLOWED_METRICS = {"file_count", "max_lines", "max_import_fan_out", "duplicate_content_groups"}
EVIDENCE_METRICS = {
    "churn": "git-history-numstat",
    "owner_concentration": "reviewed-ownership-snapshot",
    "inactive_assets": "sanitized-invocation-ledger",
}
EVIDENCE_SCHEMA = "llm-agent-maintainability-evidence/v1"
HEX64 = re.compile(r"^[0-9a-f]{64}$")
IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
UTC = timezone.utc
SECRET_PATTERNS = (
    ("openai-api-key", re.compile(r"\bsk-[A-Za-z0-9_-]{8,}\b")),
    ("github-token", re.compile(r"\b(?:ghp_[A-Za-z0-9]{8,}|github_pat_[A-Za-z0-9_]{8,})\b")),
    ("bearer-token", re.compile(r"\bBearer\s+[A-Za-z0-9._~+/-]{8,}=*", re.IGNORECASE)),
    ("aws-access-key", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    ("private-key", re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")),
    ("slack-token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{8,}\b")),
    (
        "credential-assignment",
        re.compile(
            r"\b(?:password|credentials?|api[_-]?key|secret|token)\s*[:=]\s*\S+",
            re.IGNORECASE,
        ),
    ),
    (
        "raw-content",
        re.compile(r"\braw[-_ ]?(?:prompt|tool[-_ ]?payload|input|output|content)\b", re.IGNORECASE),
    ),
)
SENSITIVE_KEYS = {
    "password", "credential", "credentials", "api_key", "apikey", "secret", "token",
    "prompt", "messages", "raw_input", "raw_output", "raw_content", "tool_payload",
}


class BudgetError(ValueError):
    """Raised when the budget contract is invalid."""


def _reject_secrets(value: object, context: str) -> None:
    if isinstance(value, dict):
        for key, nested in value.items():
            normalized_key = str(key).strip().lower().replace("-", "_")
            if normalized_key in SENSITIVE_KEYS:
                raise BudgetError(
                    "{0} contains a forbidden sensitive field".format(context)
                )
            _reject_secrets(str(key), context)
            _reject_secrets(nested, context)
    elif isinstance(value, list):
        for nested in value:
            _reject_secrets(nested, context)
    elif isinstance(value, str):
        for category, pattern in SECRET_PATTERNS:
            if pattern.search(value):
                raise BudgetError(
                    "{0} contains forbidden secret material ({1})".format(context, category)
                )


def _relative(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def _contained_path(root: Path, raw_path: str) -> Path:
    relative = Path(raw_path)
    if relative.is_absolute() or ".." in relative.parts:
        raise BudgetError("budget scope escapes root: {0}".format(raw_path))
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise BudgetError("budget path contains a symlink: {0}".format(raw_path))
    candidate = current.resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise BudgetError("budget scope escapes root: {0}".format(raw_path)) from exc
    return candidate


def _matches(path: Path, root: Path, patterns: Sequence[str]) -> bool:
    relative = _relative(root, path)
    return any(
        fnmatch.fnmatch(relative, pattern) or fnmatch.fnmatch(path.name, pattern)
        for pattern in patterns
    )


def _excluded(path: Path, root: Path, prefixes: Sequence[str]) -> bool:
    relative = _relative(root, path)
    return any(relative == prefix or relative.startswith(prefix.rstrip("/") + "/") for prefix in prefixes)


def _iter_files(
    root: Path,
    scope_paths: Sequence[str],
    include_patterns: Sequence[str],
    exclude_prefixes: Sequence[str],
) -> Iterable[Path]:
    seen = set()
    for raw_scope in scope_paths:
        scope = _contained_path(root, raw_scope)
        if not scope.exists():
            raise BudgetError("budget scope does not exist: {0}".format(raw_scope))
        candidates = [scope] if scope.is_file() else scope.rglob("*")
        for candidate in candidates:
            if not candidate.is_file() or candidate.is_symlink():
                continue
            if candidate in seen or _excluded(candidate, root, exclude_prefixes):
                continue
            if _matches(candidate, root, include_patterns):
                seen.add(candidate)
                yield candidate


def _line_count(path: Path) -> int:
    with path.open("r", encoding="utf-8", errors="replace") as stream:
        return sum(1 for _ in stream)


def _import_fan_out(path: Path) -> int:
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (OSError, SyntaxError, UnicodeError) as exc:
        raise BudgetError("cannot parse Python import graph: {0}: {1}".format(path, exc)) from exc
    imports = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imports.update(alias.name.split(".", 1)[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                imports.add("." * node.level + (node.module or "<package>"))
            elif node.module:
                imports.add(node.module.split(".", 1)[0])
    return len(imports)


def _validate_budget(raw: Mapping[str, object], index: int) -> Dict[str, object]:
    context = "maintainability budget #{0}".format(index + 1)
    required = {
        "id",
        "metric",
        "scope_paths",
        "include_patterns",
        "baseline",
        "warning_limit",
        "hard_limit",
        "owner",
        "next_action",
    }
    missing = sorted(required - set(raw))
    if missing:
        raise BudgetError("{0} missing fields: {1}".format(context, ", ".join(missing)))

    budget_id = raw["id"]
    metric = raw["metric"]
    scope_paths = raw["scope_paths"]
    include_patterns = raw["include_patterns"]
    exclude_prefixes = raw.get("exclude_prefixes", [])
    owner = raw["owner"]
    next_action = raw["next_action"]
    if not isinstance(budget_id, str) or not budget_id.strip():
        raise BudgetError("{0} has invalid id".format(context))
    if metric not in ALLOWED_METRICS:
        raise BudgetError("{0} has unsupported metric: {1}".format(context, metric))
    for field, value in (
        ("scope_paths", scope_paths),
        ("include_patterns", include_patterns),
        ("exclude_prefixes", exclude_prefixes),
    ):
        if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
            raise BudgetError("{0} has invalid {1}".format(context, field))
    if not scope_paths or not include_patterns:
        raise BudgetError("{0} requires non-empty scope_paths and include_patterns".format(context))
    for field in ("baseline", "warning_limit", "hard_limit"):
        if not isinstance(raw[field], int) or raw[field] < 0:
            raise BudgetError("{0} has invalid {1}".format(context, field))
    if not raw["baseline"] <= raw["warning_limit"] < raw["hard_limit"]:
        raise BudgetError("{0} requires baseline <= warning_limit < hard_limit".format(context))
    if not isinstance(owner, str) or not owner.strip():
        raise BudgetError("{0} has invalid owner".format(context))
    if not isinstance(next_action, str) or not next_action.strip():
        raise BudgetError("{0} has invalid next_action".format(context))
    return dict(raw)


def _identifier(value: object, field: str) -> str:
    if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
        raise BudgetError("{0} must be a stable identifier".format(field))
    return value


def _sha256(value: object, field: str) -> str:
    if not isinstance(value, str) or not HEX64.fullmatch(value):
        raise BudgetError("{0} must be a SHA-256 digest".format(field))
    return value


def _timestamp(value: object, field: str) -> datetime:
    if not isinstance(value, str) or len(value) > 40:
        raise BudgetError("{0} must be an RFC3339 timestamp".format(field))
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise BudgetError("{0} must be an RFC3339 timestamp".format(field)) from exc
    if parsed.tzinfo is None:
        raise BudgetError("{0} must include a timezone".format(field))
    return parsed.astimezone(UTC)


def _validate_window(value: object, field: str) -> Dict[str, str]:
    required = {"started_at", "ended_at", "revision_start", "revision_end"}
    if not isinstance(value, dict) or set(value) != required:
        raise BudgetError("{0} fields are invalid".format(field))
    started_at = _timestamp(value.get("started_at"), field + ".started_at")
    ended_at = _timestamp(value.get("ended_at"), field + ".ended_at")
    if started_at >= ended_at:
        raise BudgetError("{0} must satisfy started_at < ended_at".format(field))
    return {
        "started_at": started_at.isoformat().replace("+00:00", "Z"),
        "ended_at": ended_at.isoformat().replace("+00:00", "Z"),
        "revision_start": _identifier(value.get("revision_start"), field + ".revision_start"),
        "revision_end": _identifier(value.get("revision_end"), field + ".revision_end"),
    }


def _validate_population(value: object, field: str) -> Dict[str, object]:
    required = {"count", "digest", "coverage"}
    if not isinstance(value, dict) or set(value) != required:
        raise BudgetError("{0} fields are invalid".format(field))
    count = value.get("count")
    if isinstance(count, bool) or not isinstance(count, int) or count < 1:
        raise BudgetError("{0}.count must be a positive integer".format(field))
    digest = _sha256(value.get("digest"), field + ".digest")
    if value.get("coverage") != "complete":
        raise BudgetError("{0}.coverage must be complete".format(field))
    return {"count": count, "digest": digest, "coverage": "complete"}


def _validate_evidence_metric(raw: Mapping[str, object], index: int) -> Dict[str, object]:
    context = "maintainability evidence metric #{0}".format(index + 1)
    required = {
        "id", "metric", "risk", "enforcement", "enforcement_rationale",
        "source", "expected_repository_id", "expected_population", "max_age_days",
        "owner", "next_action",
    }
    optional = {"unavailable_reason", "baseline", "warning_limit", "hard_limit"}
    if set(raw) - required - optional or required - set(raw):
        raise BudgetError("{0} fields are invalid".format(context))
    metric = raw.get("metric")
    if metric not in EVIDENCE_METRICS:
        raise BudgetError("{0} has unsupported metric".format(context))
    _identifier(raw.get("id"), context + ".id")
    _identifier(raw.get("owner"), context + ".owner")
    _identifier(raw.get("expected_repository_id"), context + ".expected_repository_id")
    max_age_days = raw.get("max_age_days")
    if isinstance(max_age_days, bool) or not isinstance(max_age_days, int) or max_age_days < 1:
        raise BudgetError("{0}.max_age_days must be a positive integer".format(context))
    if raw.get("risk") not in {"low", "medium", "high"}:
        raise BudgetError("{0} has invalid risk".format(context))
    enforcement = raw.get("enforcement")
    if enforcement not in {"report-only", "budget"}:
        raise BudgetError("{0} has invalid enforcement".format(context))
    for field in ("enforcement_rationale", "next_action"):
        if not isinstance(raw.get(field), str) or not str(raw[field]).strip():
            raise BudgetError("{0} has invalid {1}".format(context, field))
    source = raw.get("source")
    if source is None:
        if raw.get("expected_population") is not None:
            raise BudgetError("{0} unavailable source cannot claim a reviewed population".format(context))
        if not isinstance(raw.get("unavailable_reason"), str) or not str(
            raw["unavailable_reason"]
        ).strip():
            raise BudgetError("{0} unavailable source requires a reason".format(context))
    else:
        source_fields = {
            "path", "sha256", "schema", "repository_id", "source_kind", "window"
        }
        if not isinstance(source, dict) or set(source) != source_fields:
            raise BudgetError("{0}.source fields are invalid".format(context))
        raw_path = source.get("path")
        if not isinstance(raw_path, str) or not raw_path or Path(raw_path).is_absolute():
            raise BudgetError("{0}.source.path must be relative".format(context))
        _sha256(source.get("sha256"), context + ".source.sha256")
        if source.get("schema") != EVIDENCE_SCHEMA:
            raise BudgetError("{0}.source has unsupported schema".format(context))
        _identifier(source.get("repository_id"), context + ".source.repository_id")
        if source.get("repository_id") != raw.get("expected_repository_id"):
            raise BudgetError("{0}.source repository does not match expected_repository_id".format(context))
        if source.get("source_kind") != EVIDENCE_METRICS[metric]:
            raise BudgetError("{0}.source kind does not match metric".format(context))
        _validate_window(source.get("window"), context + ".source.window")
        _validate_population(raw.get("expected_population"), context + ".expected_population")
    limit_fields = ("baseline", "warning_limit", "hard_limit")
    if enforcement == "budget":
        if source is None:
            raise BudgetError("{0} budget enforcement requires an evidence source".format(context))
        if any(field not in raw for field in limit_fields):
            raise BudgetError("{0} budget enforcement requires limits".format(context))
        for field in limit_fields:
            if not isinstance(raw[field], int) or raw[field] < 0:
                raise BudgetError("{0} has invalid {1}".format(context, field))
        if not raw["baseline"] <= raw["warning_limit"] < raw["hard_limit"]:
            raise BudgetError("{0} requires baseline <= warning_limit < hard_limit".format(context))
    elif any(field in raw for field in limit_fields):
        raise BudgetError("{0} report-only metric must not declare budget limits".format(context))
    return dict(raw)


def _load_contract(
    config_path: Path,
) -> Tuple[Dict[str, object], List[Dict[str, object]], List[Dict[str, object]]]:
    try:
        raw = json.loads(config_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BudgetError("cannot load maintainability contract: {0}".format(exc)) from exc
    _reject_secrets(raw, "maintainability contract")
    if raw.get("schema_version") != 2:
        raise BudgetError("maintainability contract requires backlog schema_version=2")
    contract = raw.get("maintainability_budgets")
    if not isinstance(contract, dict):
        raise BudgetError("backlog missing maintainability_budgets")
    if contract.get("schema") != "llm-agent-maintainability-budgets/v2":
        raise BudgetError("unsupported maintainability budget schema")
    budgets = contract.get("budgets")
    if not isinstance(budgets, list) or not budgets:
        raise BudgetError("maintainability_budgets.budgets must be a non-empty list")
    validated = [_validate_budget(item, index) for index, item in enumerate(budgets)]
    ids = [item["id"] for item in validated]
    if len(ids) != len(set(ids)):
        raise BudgetError("maintainability budget IDs must be unique")
    evidence_metrics = contract.get("evidence_metrics")
    if not isinstance(evidence_metrics, list) or len(evidence_metrics) != len(EVIDENCE_METRICS):
        raise BudgetError("maintainability_budgets.evidence_metrics must define every evidence metric")
    validated_evidence = [
        _validate_evidence_metric(item, index) for index, item in enumerate(evidence_metrics)
    ]
    evidence_names = [item["metric"] for item in validated_evidence]
    if set(evidence_names) != set(EVIDENCE_METRICS) or len(evidence_names) != len(
        set(evidence_names)
    ):
        raise BudgetError("evidence metric names must be unique and complete")
    all_ids = ids + [item["id"] for item in validated_evidence]
    if len(all_ids) != len(set(all_ids)):
        raise BudgetError("maintainability metric IDs must be unique")
    return contract, validated, validated_evidence


def _measure(root: Path, budget: Mapping[str, object]) -> Dict[str, object]:
    files = sorted(
        _iter_files(
            root,
            budget["scope_paths"],
            budget["include_patterns"],
            budget.get("exclude_prefixes", []),
        ),
        key=lambda item: _relative(root, item),
    )
    metric = budget["metric"]
    if metric == "file_count":
        observed = len(files)
        hotspots = [{"path": _relative(root, path), "value": 1} for path in files[:5]]
    elif metric == "max_lines":
        measured = sorted(
            ((_line_count(path), _relative(root, path)) for path in files),
            key=lambda item: (-item[0], item[1]),
        )
        observed = measured[0][0] if measured else 0
        hotspots = [{"path": path, "value": value} for value, path in measured[:5]]
    elif metric == "max_import_fan_out":
        measured = sorted(
            ((_import_fan_out(path), _relative(root, path)) for path in files),
            key=lambda item: (-item[0], item[1]),
        )
        observed = measured[0][0] if measured else 0
        hotspots = [{"path": path, "value": value} for value, path in measured[:5]]
    else:
        groups: Dict[str, List[str]] = {}
        for path in files:
            content = path.read_bytes()
            if len(content) < 64:
                continue
            digest = hashlib.sha256(content).hexdigest()
            groups.setdefault(digest, []).append(_relative(root, path))
        duplicates = sorted(
            (paths for paths in groups.values() if len(paths) > 1),
            key=lambda paths: (-len(paths), paths[0]),
        )
        observed = len(duplicates)
        hotspots = [
            {"path": paths[0], "value": len(paths), "duplicates": paths[1:5]}
            for paths in duplicates[:5]
        ]
        if not hotspots:
            hotspots = [{"path": "<none>", "value": 0, "duplicates": []}]

    if observed > budget["hard_limit"]:
        status = "fail"
    elif observed > budget["warning_limit"]:
        status = "needs-review"
    else:
        status = "pass"
    return {
        "id": budget["id"],
        "metric": metric,
        "status": status,
        "observed": observed,
        "baseline": budget["baseline"],
        "drift": observed - budget["baseline"],
        "warning_limit": budget["warning_limit"],
        "hard_limit": budget["hard_limit"],
        "files_scanned": len(files),
        "owner": budget["owner"],
        "next_action": budget["next_action"],
        "hotspots": hotspots,
    }


def _record_identifier(value: object, field: str) -> str:
    return _identifier(value, field)


def _record_path(value: object, field: str) -> str:
    if not isinstance(value, str) or not value or Path(value).is_absolute() or ".." in Path(value).parts:
        raise BudgetError("{0} must be a safe relative path".format(field))
    return Path(value).as_posix()


def _non_negative_integer(value: object, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise BudgetError("{0} must be a non-negative integer".format(field))
    return value


def _population_digest(identifiers: Sequence[str]) -> str:
    raw = json.dumps(
        sorted(identifiers), ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _basis_points(part: int, whole: int) -> int:
    value = Decimal(part) * Decimal(10000) / Decimal(whole)
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def _verify_repository_window(
    root: Path,
    repository_id: str,
    expected_repository_id: str,
    window: Mapping[str, str],
) -> None:
    if repository_id != expected_repository_id:
        raise BudgetError("CLI repository identity does not match evidence contract")
    revision_start = window["revision_start"]
    revision_end = window["revision_end"]
    for revision in (revision_start, revision_end):
        result = subprocess.run(
            ["git", "-C", str(root), "cat-file", "-e", revision + "^{commit}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode != 0:
            raise BudgetError("evidence revision is not a commit in the current repository")
    ancestry = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", revision_start, revision_end],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if ancestry.returncode != 0:
        raise BudgetError("evidence revisions do not form an ancestor window")


def _load_evidence(
    root: Path,
    definition: Mapping[str, object],
    now: datetime,
    repository_id: str,
) -> Optional[Dict[str, object]]:
    source = definition.get("source")
    if source is None:
        return None
    if not isinstance(source, dict):  # validated by _load_contract
        raise BudgetError("evidence source must be an object")
    path = _contained_path(root, str(source["path"]))
    if path.is_symlink() or not path.is_file():
        raise BudgetError("evidence source is missing or unsafe: {0}".format(source["path"]))
    actual_sha256 = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual_sha256 != source["sha256"]:
        raise BudgetError("evidence source digest mismatch: {0}".format(source["path"]))
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise BudgetError("evidence source is invalid JSON: {0}".format(source["path"])) from exc
    _reject_secrets(value, "maintainability evidence")
    required = {
        "schema", "metric", "repository_id", "source_kind", "window", "population",
        "generated_at", "records"
    }
    if not isinstance(value, dict) or set(value) != required:
        raise BudgetError("evidence source fields are invalid: {0}".format(source["path"]))
    for field in ("schema", "repository_id", "source_kind"):
        if value.get(field) != source.get(field):
            raise BudgetError("evidence source identity mismatch for {0}".format(field))
    if value.get("metric") != definition.get("metric"):
        raise BudgetError("evidence source metric mismatch")
    expected_window = _validate_window(source.get("window"), "evidence contract window")
    actual_window = _validate_window(value.get("window"), "evidence source window")
    if actual_window != expected_window:
        raise BudgetError("evidence source window mismatch")
    ended_at = _timestamp(actual_window["ended_at"], "evidence source window.ended_at")
    generated_at = _timestamp(value.get("generated_at"), "evidence source.generated_at")
    if ended_at > now or generated_at > now:
        raise BudgetError("evidence source contains a future timestamp")
    if generated_at < ended_at:
        raise BudgetError("evidence source cannot be generated before its window ends")
    max_age_seconds = int(definition["max_age_days"]) * 86400
    if (now - ended_at).total_seconds() > max_age_seconds:
        raise BudgetError("evidence window exceeds max_age_days")
    if (now - generated_at).total_seconds() > max_age_seconds:
        raise BudgetError("evidence source exceeds max_age_days")
    expected_population = _validate_population(
        definition.get("expected_population"), "evidence contract expected_population"
    )
    actual_population = _validate_population(
        value.get("population"), "evidence source population"
    )
    if actual_population != expected_population:
        raise BudgetError("evidence source population mismatch")
    _verify_repository_window(
        root,
        repository_id,
        str(definition["expected_repository_id"]),
        actual_window,
    )
    records = value.get("records")
    if not isinstance(records, list) or not records:
        raise BudgetError("evidence source records must not be empty")
    value["window"] = actual_window
    value["generated_at"] = generated_at.isoformat().replace("+00:00", "Z")
    value["population"] = actual_population
    value["path"] = str(source["path"])
    value["sha256"] = actual_sha256
    return value


def _verify_population_records(
    identifiers: Sequence[str], population: Mapping[str, object]
) -> None:
    if len(identifiers) != population["count"]:
        raise BudgetError("evidence records do not cover the reviewed population count")
    if _population_digest(identifiers) != population["digest"]:
        raise BudgetError("evidence records do not cover the reviewed population digest")


def _measure_evidence_metric(
    root: Path,
    definition: Mapping[str, object],
    now: datetime,
    repository_id: str,
) -> Dict[str, object]:
    evidence = _load_evidence(
        root, definition, now, repository_id
    )
    base: Dict[str, object] = {
        "id": definition["id"],
        "metric": definition["metric"],
        "risk": definition["risk"],
        "enforcement": definition["enforcement"],
        "enforcement_rationale": definition["enforcement_rationale"],
        "expected_repository_id": definition["expected_repository_id"],
        "expected_population": definition["expected_population"],
        "max_age_days": definition["max_age_days"],
        "owner": definition["owner"],
        "next_action": definition["next_action"],
    }
    if evidence is None:
        base.update({
            "status": "not-available",
            "observed": None,
            "unit": None,
            "hotspots": [],
            "source": None,
            "unavailable_reason": definition["unavailable_reason"],
        })
        return base

    records = evidence["records"]
    metric = definition["metric"]
    hotspots: List[Dict[str, object]]
    if metric == "churn":
        measured = []
        paths = set()
        for index, record in enumerate(records):
            if not isinstance(record, dict) or set(record) != {"path", "additions", "deletions"}:
                raise BudgetError("churn record #{0} fields are invalid".format(index + 1))
            path = _record_path(record.get("path"), "churn record path")
            if path in paths:
                raise BudgetError("churn evidence paths must be unique")
            paths.add(path)
            value = _non_negative_integer(record.get("additions"), "churn additions") + _non_negative_integer(
                record.get("deletions"), "churn deletions"
            )
            measured.append((value, path))
        measured.sort(key=lambda item: (-item[0], item[1]))
        _verify_population_records(sorted(paths), evidence["population"])
        observed = measured[0][0]
        hotspots = [{"path": path, "value": value} for value, path in measured[:5]]
        unit = "changed-lines-per-file-window"
    elif metric == "owner_concentration":
        counts: Dict[str, int] = {}
        scopes = set()
        for index, record in enumerate(records):
            if not isinstance(record, dict) or set(record) != {"scope_id", "owner_id"}:
                raise BudgetError("owner record #{0} fields are invalid".format(index + 1))
            scope_id = _record_identifier(record.get("scope_id"), "owner scope_id")
            owner_id = _record_identifier(record.get("owner_id"), "owner owner_id")
            if scope_id in scopes:
                raise BudgetError("ownership evidence scopes must be unique")
            scopes.add(scope_id)
            counts[owner_id] = counts.get(owner_id, 0) + 1
        measured = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
        _verify_population_records(sorted(scopes), evidence["population"])
        observed = _basis_points(measured[0][1], len(records))
        hotspots = [
            {"owner_id": owner_id, "owned_scopes": count}
            for owner_id, count in measured[:5]
        ]
        unit = "basis-points-of-reviewed-scopes"
    else:
        measured = []
        assets = set()
        inactive = 0
        for index, record in enumerate(records):
            if not isinstance(record, dict) or set(record) != {"asset_id", "invocations"}:
                raise BudgetError("inactive asset record #{0} fields are invalid".format(index + 1))
            asset_id = _record_identifier(record.get("asset_id"), "inactive asset_id")
            if asset_id in assets:
                raise BudgetError("invocation evidence assets must be unique")
            assets.add(asset_id)
            invocations = _non_negative_integer(record.get("invocations"), "asset invocations")
            if invocations == 0:
                inactive += 1
            measured.append((invocations, asset_id))
        _verify_population_records(sorted(assets), evidence["population"])
        observed = _basis_points(inactive, len(records))
        measured.sort(key=lambda item: (item[0], item[1]))
        hotspots = [
            {"asset_id": asset_id, "invocations": invocations}
            for invocations, asset_id in measured[:5]
        ]
        unit = "inactive-asset-basis-points"

    status = "measured"
    if definition["enforcement"] == "budget":
        if observed > definition["hard_limit"]:
            status = "fail"
        elif observed > definition["warning_limit"]:
            status = "needs-review"
        else:
            status = "pass"
        base.update({
            "baseline": definition["baseline"],
            "warning_limit": definition["warning_limit"],
            "hard_limit": definition["hard_limit"],
        })
    base.update({
        "status": status,
        "observed": observed,
        "unit": unit,
        "hotspots": hotspots,
        "source": {
            "path": evidence["path"],
            "sha256": evidence["sha256"],
            "schema": evidence["schema"],
            "repository_id": evidence["repository_id"],
            "source_kind": evidence["source_kind"],
            "window": evidence["window"],
            "generated_at": evidence["generated_at"],
            "population": evidence["population"],
            "max_age_days": definition["max_age_days"],
        },
        "unavailable_reason": None,
    })
    return base


def evaluate(
    root: Path,
    config_path: Path,
    strict: bool,
    repository_id: str,
    *,
    as_of: Optional[datetime] = None,
) -> Dict[str, object]:
    started = time.monotonic()
    root = root.resolve()
    repository_id = _identifier(repository_id, "repository_id")
    contract, budgets, evidence_definitions = _load_contract(config_path)
    results = [_measure(root, budget) for budget in budgets]
    now = as_of or datetime.now(UTC)
    if now.tzinfo is None:
        raise BudgetError("as_of must include a timezone")
    now = now.astimezone(UTC)
    evidence_results = [
        _measure_evidence_metric(
            root, definition, now, repository_id
        )
        for definition in evidence_definitions
    ]
    failures = [
        item["id"] for item in results + evidence_results if item["status"] == "fail"
    ]
    warnings = [
        item["id"] for item in results + evidence_results if item["status"] == "needs-review"
    ]
    if failures or (strict and warnings):
        status = "fail"
    elif warnings:
        status = "needs-review"
    else:
        status = "pass"
    report = {
        "schema": "llm-agent-maintainability-budget-report/v2",
        "status": status,
        "strict": strict,
        "baseline_date": contract.get("baseline_date"),
        "root": str(root),
        "budget_count": len(results),
        "evidence_metric_count": len(evidence_results),
        "failures": failures,
        "warnings": warnings,
        "budgets": results,
        "elapsed_ms": round((time.monotonic() - started) * 1000.0, 3),
        "semantic_axes": {
            "coupling": {"status": "measured", "method": "max-import-fan-out"},
            "exact_duplication": {"status": "measured", "method": "content-sha256"},
            **{str(item["metric"]): item for item in evidence_results},
        },
    }
    _reject_secrets(report, "maintainability report")
    return report


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Check repository maintainability growth budgets.")
    parser.add_argument("--root", default=".", help="Workspace root.")
    parser.add_argument(
        "--repository-id", required=True, help="Managed identity for the workspace root."
    )
    parser.add_argument(
        "--as-of", help="RFC3339 evaluation time for deterministic freshness replay."
    )
    parser.add_argument(
        "--config",
        help="Budget contract; defaults to manifests/comprehensive_optimization_backlog.json.",
    )
    parser.add_argument("--strict", action="store_true", help="Treat warning-limit drift as failure.")
    parser.add_argument("--summary-json", action="store_true", help="Emit compact JSON.")
    return parser


def main(argv: Sequence[str] = ()) -> int:
    args = _parser().parse_args(list(argv) if argv else None)
    root = Path(args.root).resolve()
    config_path = Path(args.config).resolve() if args.config else root / "manifests/comprehensive_optimization_backlog.json"
    try:
        as_of = _timestamp(args.as_of, "as_of") if args.as_of else None
        report = evaluate(
            root, config_path, args.strict, args.repository_id, as_of=as_of
        )
    except BudgetError as exc:
        print("[FAIL] {0}".format(exc), file=sys.stderr)
        return 2

    if args.summary_json:
        print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
    else:
        for item in report["budgets"]:
            print(
                "[{0}] {1}: observed={2} baseline={3} warning={4} hard={5}".format(
                    item["status"].upper(),
                    item["id"],
                    item["observed"],
                    item["baseline"],
                    item["warning_limit"],
                    item["hard_limit"],
                )
            )
        print(
            "[SUMMARY] status={0} budgets={1} warnings={2} failures={3}".format(
                report["status"],
                report["budget_count"],
                len(report["warnings"]),
                len(report["failures"]),
            )
        )
    return 1 if report["status"] == "fail" else 0


if __name__ == "__main__":
    raise SystemExit(main())
