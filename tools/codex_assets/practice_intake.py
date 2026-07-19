#!/usr/bin/env python3
"""Fail-closed, report-only intake for governed external practice metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, timedelta
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


POLICY_SCHEMA = "external-practice-source-policy/v1"
CANDIDATE_SCHEMA = "external-practice-candidate/v1"
DECISION_SCHEMA = "external-practice-decision/v1"
PLAN_SCHEMA = "external-practice-cycle-plan/v1"
EVIDENCE_SCHEMA = "external-practice-cycle-evidence/v1"
QUEUE_SCHEMA = "external-practice-review-queue/v1"
RECOMMENDATION_SCHEMA = "external-practice-recommendations/v1"

PROVIDERS = {
    "github",
    "gitlab",
    "gitee",
    "openai-official",
    "anthropic-official",
    "wechat",
    "manual",
}
NETWORK_PROVIDERS = {"github", "gitlab", "gitee"}
OFFICIAL_PROVIDERS = {"openai-official", "anthropic-official"}
ASSET_RECOMMENDATIONS = {"agent", "skill", "workflow", "script", "manifest", "runbook", "observe"}
DECISIONS = {"ADOPT", "MERGE", "ENHANCE", "OBSERVE", "REJECT"}
AUTHORITY_RANK = {"official": 0, "project": 1, "community": 2, "secondary": 3, "manual": 4}
DATE_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,159}$")
CANDIDATE_ID_RE = re.compile(r"^epc-[0-9a-f]{20}$")
RISK_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,99}$")
TOKEN_ENV_RE = re.compile(r"^[A-Z][A-Z0-9_]{2,63}$")
CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
SECRET_REF_RE = re.compile(r"(?:access[_-]?token|private-token|authorization|bearer\s)", re.IGNORECASE)
HEX64_RE = re.compile(r"^[0-9a-f]{64}$")

EXPECTED_ENDPOINTS = {
    "github": "https://api.github.com/search/repositories",
    "gitlab": "https://gitlab.com/api/v4/projects",
    "gitee": "https://gitee.com/api/v5/search/repositories",
}
EXPECTED_TOKEN_DELIVERY = {
    "github": "authorization-header",
    "gitlab": "private-token-header",
    "gitee": "access-token-query",
}
EXPECTED_PROVIDER_SHAPE = {
    "github": ("forge-search", "metadata-only", "repository", "project"),
    "gitlab": ("forge-search", "metadata-only", "repository", "project"),
    "gitee": ("forge-search", "metadata-only", "repository", "project"),
    "openai-official": ("official-manifest", "ledger-only", "official-document", "official"),
    "anthropic-official": ("official-manifest", "ledger-only", "official-document", "official"),
    "wechat": ("wechat-catalog", "ledger-only", "wechat-article", "secondary"),
    "manual": ("manual-input", "ledger-only", "manual-reference", "manual"),
}
REQUIRED_RULES = {
    "network_requires_explicit_allow",
    "metadata_only",
    "review_required",
    "must_not_clone",
    "must_not_execute_external_code",
    "must_not_register_repository",
    "must_not_modify_adk",
    "must_not_write_live_runtime",
    "must_not_persist_credentials",
    "must_not_persist_article_body",
    "must_not_auto_decide",
    "must_not_auto_publish",
}
BOUNDARIES = {
    "network_write": False,
    "external_code_executed": False,
    "repository_modified": False,
    "adk_modified": False,
    "live_runtime_modified": False,
    "credentials_persisted": False,
    "article_body_persisted": False,
    "decision_generated": False,
}


class IntakeError(RuntimeError):
    """A sanitized, fail-closed intake contract error."""


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: Any,
        code: int,
        msg: str,
        headers: Mapping[str, str],
        newurl: str,
    ) -> None:
        return None


def _canonical_json(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_value(value: Any) -> str:
    return _sha256_bytes(_canonical_json(value))


def _sha256_file(path: Path) -> str:
    _reject_symlink_chain(path)
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _parse_date(value: Any, label: str) -> str:
    if not isinstance(value, str) or not DATE_RE.fullmatch(value):
        raise IntakeError("{} must be an ISO-8601 date".format(label))
    try:
        date.fromisoformat(value)
    except ValueError as exc:
        raise IntakeError("{} must be a valid date".format(label)) from exc
    return value


def _date_or_none(value: Any, label: str) -> Optional[str]:
    if value is None or value == "":
        return None
    if not isinstance(value, str):
        raise IntakeError("{} must be a date or null".format(label))
    match = re.match(r"^([0-9]{4}-[0-9]{2}-[0-9]{2})", value)
    if not match:
        raise IntakeError("{} must start with an ISO-8601 date".format(label))
    return _parse_date(match.group(1), label)


def _future_date(as_of: str, days: int) -> str:
    return (date.fromisoformat(as_of) + timedelta(days=days)).isoformat()


def _clean_text(value: Any, label: str, maximum: int, allow_empty: bool = True) -> str:
    if value is None and allow_empty:
        return ""
    if not isinstance(value, str):
        raise IntakeError("{} must be a string".format(label))
    normalized = " ".join(value.split())
    if CONTROL_RE.search(normalized):
        raise IntakeError("{} contains control characters".format(label))
    if not allow_empty and not normalized:
        raise IntakeError("{} must not be empty".format(label))
    if len(normalized) > maximum:
        raise IntakeError("{} exceeds {} characters".format(label, maximum))
    return normalized


def _nonnegative_int(value: Any, label: str) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise IntakeError("{} must be a non-negative integer or null".format(label))
    return value


def _load_bytes(path: Path, limit: int, label: str) -> bytes:
    _reject_symlink_chain(path)
    if not path.is_file():
        raise IntakeError("{} is missing or not a regular file".format(label))
    size = path.stat().st_size
    if size > limit:
        raise IntakeError("{} exceeds the {} byte budget".format(label, limit))
    try:
        return path.read_bytes()
    except OSError as exc:
        raise IntakeError("cannot read {}".format(label)) from exc


def _load_json(path: Path, limit: int, label: str) -> Any:
    raw = _load_bytes(path, limit, label)
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise IntakeError("{} must contain valid UTF-8 JSON".format(label)) from exc


def _load_jsonl(path: Path, limit: int, label: str) -> List[Dict[str, Any]]:
    raw = _load_bytes(path, limit, label)
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise IntakeError("{} must contain UTF-8 JSONL".format(label)) from exc
    rows: List[Dict[str, Any]] = []
    for line_number, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise IntakeError("{} line {} is invalid JSON".format(label, line_number)) from exc
        if not isinstance(row, dict):
            raise IntakeError("{} line {} must be an object".format(label, line_number))
        rows.append(row)
    return rows


def _resolve_path(root: Path, value: str, label: str) -> Path:
    if not isinstance(value, str) or not value:
        raise IntakeError("{} must be a non-empty path".format(label))
    raw = Path(value)
    path = raw if raw.is_absolute() else root / raw
    return Path(os.path.abspath(os.fspath(path)))


def _relative_ref(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def _input_reference(root: Path, path: Path, digest: str) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return "external-input-sha256:{}".format(digest[:20])


def _reject_symlink_chain(path: Path) -> None:
    current = path
    while True:
        if current.is_symlink():
            raise IntakeError("path must not traverse symlinks")
        if current.parent == current:
            return
        current = current.parent


def _same_file(left: Path, right: Path) -> bool:
    if left == right:
        return True
    try:
        return left.exists() and right.exists() and os.path.samefile(str(left), str(right))
    except OSError:
        return False


def _atomic_write_many(outputs: Sequence[Tuple[Path, bytes]], inputs: Iterable[Path] = ()) -> None:
    if not outputs:
        return
    normalized_inputs = [Path(os.path.abspath(os.fspath(item))) for item in inputs]
    normalized_outputs: List[Tuple[Path, bytes]] = []
    for raw_path, payload in outputs:
        path = Path(os.path.abspath(os.fspath(raw_path)))
        _reject_symlink_chain(path)
        if not path.parent.is_dir():
            raise IntakeError("output parent directory does not exist")
        if any(_same_file(path, item) for item in normalized_inputs):
            raise IntakeError("output must not overwrite an input")
        if any(_same_file(path, prior) for prior, _ in normalized_outputs):
            raise IntakeError("output paths must be unique")
        normalized_outputs.append((path, payload))

    staged: Dict[Path, Path] = {}
    backups: Dict[Path, Optional[Path]] = {}
    committed: List[Path] = []
    preserve_backups = False
    try:
        for path, payload in normalized_outputs:
            descriptor, temporary = tempfile.mkstemp(prefix=".practice-intake-stage-", dir=str(path.parent))
            temp_path = Path(temporary)
            staged[path] = temp_path
            with os.fdopen(descriptor, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            os.chmod(str(temp_path), 0o644)

        for path, _ in normalized_outputs:
            backup: Optional[Path] = None
            if path.exists():
                descriptor, temporary = tempfile.mkstemp(prefix=".practice-intake-backup-", dir=str(path.parent))
                os.close(descriptor)
                backup = Path(temporary)
                backup.unlink()
                os.replace(str(path), str(backup))
            backups[path] = backup
            try:
                os.replace(str(staged[path]), str(path))
            except Exception:
                if backup is not None and backup.exists():
                    os.replace(str(backup), str(path))
                raise
            committed.append(path)

        for backup in backups.values():
            if backup is not None and backup.exists():
                try:
                    backup.unlink()
                except OSError:
                    pass
    except Exception as exc:
        rollback_errors: List[OSError] = []
        for path in reversed(committed):
            try:
                if path.exists():
                    path.unlink()
                backup = backups.get(path)
                if backup is not None and backup.exists():
                    os.replace(str(backup), str(path))
            except OSError as rollback_error:
                rollback_errors.append(rollback_error)
        for path, backup in backups.items():
            if path not in committed and backup is not None and backup.exists():
                try:
                    os.replace(str(backup), str(path))
                except OSError as rollback_error:
                    rollback_errors.append(rollback_error)
        if rollback_errors:
            preserve_backups = True
            raise IntakeError("atomic output rollback failed; backup files were preserved") from exc
        raise
    finally:
        for temp_path in staged.values():
            if temp_path.exists():
                try:
                    temp_path.unlink()
                except OSError:
                    pass
        if not preserve_backups:
            for backup in backups.values():
                if backup is not None and backup.exists():
                    try:
                        backup.unlink()
                    except OSError:
                        pass


def _atomic_write(path: Path, payload: bytes, inputs: Iterable[Path] = ()) -> None:
    try:
        _atomic_write_many([(path, payload)], inputs)
    except IntakeError:
        raise
    except Exception as exc:
        raise IntakeError("atomic output transaction failed") from exc


def _transactional_write(outputs: Sequence[Tuple[Path, bytes]], inputs: Iterable[Path] = ()) -> None:
    try:
        _atomic_write_many(outputs, inputs)
    except IntakeError:
        raise
    except Exception as exc:
        raise IntakeError("atomic output transaction failed") from exc


def _json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _jsonl_bytes(rows: Sequence[Mapping[str, Any]]) -> bytes:
    return b"".join(_canonical_json(row) + b"\n" for row in rows)


def _canonical_url(value: Any, allowed_hosts: Sequence[str], repository: bool = False) -> str:
    raw = _clean_text(value, "url", 2000, allow_empty=False)
    try:
        parsed = urllib.parse.urlsplit(raw)
        port = parsed.port
    except ValueError as exc:
        raise IntakeError("url is malformed") from exc
    if parsed.scheme != "https":
        raise IntakeError("url must use HTTPS")
    if parsed.username or parsed.password or port not in (None, 443):
        raise IntakeError("url must not contain credentials or a custom port")
    host = (parsed.hostname or "").lower()
    if host not in set(allowed_hosts):
        raise IntakeError("url host is not allowlisted")
    if not parsed.path.startswith("/") or parsed.path == "/":
        raise IntakeError("url path must identify a resource")
    if SECRET_REF_RE.search(parsed.query):
        raise IntakeError("url query must not contain credential fields")
    path = re.sub(r"/{2,}", "/", parsed.path)
    query = ""
    fragment = parsed.fragment
    if repository:
        path = path.rstrip("/")
        if path.endswith(".git"):
            path = path[:-4]
        query = ""
        fragment = ""
    return urllib.parse.urlunsplit(("https", host, path, query, fragment))


def _candidate_id(provider: str, canonical_url: str, revision: Optional[str], content_sha256: Optional[str]) -> str:
    stable = revision or content_sha256 or "unknown"
    digest = hashlib.sha256("{}\n{}\n{}".format(provider, canonical_url, stable).encode("utf-8")).hexdigest()
    return "epc-{}".format(digest[:20])


def _topics(value: Any, maximum: int) -> List[str]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise IntakeError("topics must be an array")
    result: List[str] = []
    for item in value:
        cleaned = _clean_text(item, "topic", 100, allow_empty=False).lower()
        if cleaned not in result:
            result.append(cleaned)
    if len(result) > maximum:
        raise IntakeError("topics exceed the configured item budget")
    return result


def _recommend(title: str, summary: str, topics: Sequence[str]) -> str:
    text = " ".join([title, summary] + list(topics)).lower()
    rules = [
        ("workflow", ("workflow", "orchestration", "harness", "工作流", "编排", "闭环")),
        ("skill", ("skill", "技能", "playbook")),
        ("agent", ("multi-agent", "subagent", "agent", "智能体", "代理")),
        ("manifest", ("policy", "governance", "schema", "config", "治理", "策略", "契约")),
        ("script", ("cli", "tool", "api", "脚本", "工具")),
        ("runbook", ("guide", "practice", "runbook", "指南", "实践")),
    ]
    for asset, keywords in rules:
        if any(keyword in text for keyword in keywords):
            return asset
    return "observe"


def _risk_flags(
    license_value: str,
    archived: Optional[bool],
    last_activity: Optional[str],
    as_of: str,
    freshness_days: int,
) -> List[str]:
    risks: List[str] = []
    if license_value.lower() in {"unknown", "noassertion", "other"}:
        risks.append("license-review-required")
    if archived is True:
        risks.append("archived-source")
    if last_activity:
        age = (date.fromisoformat(as_of) - date.fromisoformat(last_activity)).days
        if age > freshness_days:
            risks.append("stale-source")
    return risks


def _provider_policy(policy: Mapping[str, Any], provider: str) -> Mapping[str, Any]:
    providers = policy.get("providers")
    if not isinstance(providers, dict) or provider not in providers:
        raise IntakeError("provider is not governed by source policy")
    value = providers[provider]
    if not isinstance(value, dict):
        raise IntakeError("provider policy must be an object")
    return value


def _validate_policy(policy: Any, root: Optional[Path] = None) -> Mapping[str, Any]:
    if not isinstance(policy, dict):
        raise IntakeError("source policy root must be an object")
    if policy.get("schema") != POLICY_SCHEMA or policy.get("status") != "report-only":
        raise IntakeError("source policy must use the report-only v1 schema")
    rules = policy.get("rules")
    if not isinstance(rules, dict) or set(rules) != REQUIRED_RULES or not all(value is True for value in rules.values()):
        raise IntakeError("source policy rules must contain the complete non-weakening baseline")
    limits = policy.get("limits")
    if not isinstance(limits, dict):
        raise IntakeError("source policy limits are missing")
    required_limits = {
        "timeout_seconds": (1, 15),
        "response_bytes": (1, 4194304),
        "candidates_per_job": (1, 100),
        "candidates_per_cycle": (1, 500),
        "summary_characters": (1, 1000),
        "title_characters": (1, 300),
        "topics_per_candidate": (1, 50),
    }
    if set(limits) != set(required_limits):
        raise IntakeError("source policy limits must use the fixed v1 fields")
    for name, (minimum, maximum) in required_limits.items():
        value = limits.get(name)
        if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
            raise IntakeError("source policy limit {} weakens the baseline".format(name))
    providers = policy.get("providers")
    if not isinstance(providers, dict) or set(providers) != PROVIDERS:
        raise IntakeError("source policy must define exactly the v1 providers")
    for provider, endpoint in EXPECTED_ENDPOINTS.items():
        item = providers.get(provider)
        if not isinstance(item, dict) or item.get("endpoint") != endpoint:
            raise IntakeError("{} endpoint must match the v1 allowlist".format(provider))
        if item.get("token_delivery") != EXPECTED_TOKEN_DELIVERY[provider]:
            raise IntakeError("{} token delivery must match the v1 contract".format(provider))
        if not TOKEN_ENV_RE.fullmatch(str(item.get("token_env", ""))):
            raise IntakeError("{} token_env must name an environment variable".format(provider))
    for provider, item in providers.items():
        if not isinstance(item, dict):
            raise IntakeError("provider policy entries must be objects")
        expected_shape = EXPECTED_PROVIDER_SHAPE[provider]
        actual_shape = (item.get("kind"), item.get("transport"), item.get("source_type"), item.get("authority_level"))
        if actual_shape != expected_shape:
            raise IntakeError("{} provider shape weakens the v1 contract".format(provider))
        base_fields = {"kind", "transport", "source_type", "authority_level", "allowed_hosts", "freshness_days"}
        if provider in NETWORK_PROVIDERS:
            expected_fields = base_fields | {"endpoint", "path_prefix", "token_env", "token_delivery"}
            if provider == "gitee":
                expected_fields.add("empty_result_status")
        elif provider in OFFICIAL_PROVIDERS:
            expected_fields = base_fields | {"input_path"}
        elif provider == "wechat":
            expected_fields = base_fields | {"input_path", "trusted_verification_statuses"}
        else:
            expected_fields = base_fields
        if set(item) != expected_fields:
            raise IntakeError("{} provider policy field set is unsupported".format(provider))
        hosts = item.get("allowed_hosts")
        if not isinstance(hosts, list) or not hosts or not all(isinstance(host, str) and host == host.lower() for host in hosts):
            raise IntakeError("{} must define lowercase allowed_hosts".format(provider))
        if item.get("transport") not in {"metadata-only", "ledger-only"}:
            raise IntakeError("{} has an invalid transport".format(provider))
        freshness = item.get("freshness_days")
        if isinstance(freshness, bool) or not isinstance(freshness, int) or not 0 < freshness <= 365:
            raise IntakeError("{} has an invalid freshness_days".format(provider))
        input_path = item.get("input_path")
        if root is not None and isinstance(input_path, str):
            path = _resolve_path(root, input_path, "provider input_path")
            _reject_symlink_chain(path)
            if not path.is_file():
                raise IntakeError("{} provider input_path is missing".format(provider))
    for provider, endpoint in EXPECTED_ENDPOINTS.items():
        parsed = urllib.parse.urlsplit(endpoint)
        item = providers[provider]
        if item.get("path_prefix") != parsed.path:
            raise IntakeError("{} path_prefix must match its endpoint".format(provider))
    if providers["gitee"].get("empty_result_status") != "degraded-empty":
        raise IntakeError("gitee empty results must remain degraded-empty")
    wechat_statuses = providers["wechat"].get("trusted_verification_statuses")
    if (
        not isinstance(wechat_statuses, list)
        or not wechat_statuses
        or len(wechat_statuses) > 20
        or len(wechat_statuses) != len(set(wechat_statuses))
        or not all(isinstance(item, str) and RISK_RE.fullmatch(item) for item in wechat_statuses)
    ):
        raise IntakeError("wechat trusted_verification_statuses must be an explicit bounded allowlist")
    if policy.get("authority_order") != ["official", "project", "community", "secondary", "manual"]:
        raise IntakeError("source policy authority_order must not drift")
    return policy


def _load_policy(root: Path, path_value: Optional[str]) -> Tuple[Mapping[str, Any], Path]:
    path = _resolve_path(root, path_value or "manifests/external_practice_sources.json", "policy")
    policy = _load_json(path, 4194304, "source policy")
    return _validate_policy(policy, root), path


def _validate_repository(value: Any, provider: str) -> Optional[Mapping[str, Any]]:
    if value is None:
        if provider in NETWORK_PROVIDERS:
            raise IntakeError("forge candidate repository metadata is required")
        return None
    if not isinstance(value, dict):
        raise IntakeError("repository must be an object or null")
    required = {
        "full_name",
        "host",
        "default_branch",
        "stars_count",
        "forks_count",
        "watchers_count",
        "archived",
        "language",
    }
    if set(value) != required:
        raise IntakeError("repository uses an unsupported field set")
    full_name = _clean_text(value.get("full_name"), "repository.full_name", 300, allow_empty=False)
    if "/" not in full_name or any(part in {"", ".", ".."} for part in full_name.split("/")):
        raise IntakeError("repository.full_name is invalid")
    if value.get("host") not in {"github.com", "gitlab.com", "gitee.com"}:
        raise IntakeError("repository.host is invalid")
    branch = value.get("default_branch")
    if branch is not None:
        _clean_text(branch, "repository.default_branch", 200, allow_empty=False)
    for field in ("stars_count", "forks_count", "watchers_count"):
        _nonnegative_int(value.get(field), "repository.{}".format(field))
    archived = value.get("archived")
    if archived is not None and not isinstance(archived, bool):
        raise IntakeError("repository.archived must be boolean or null")
    language = value.get("language")
    if language is not None:
        _clean_text(language, "repository.language", 100, allow_empty=False)
    return value


def _validate_candidate(row: Any, policy: Mapping[str, Any]) -> Mapping[str, Any]:
    if not isinstance(row, dict):
        raise IntakeError("candidate must be an object")
    if row.get("schema_version") != CANDIDATE_SCHEMA:
        raise IntakeError("legacy or unknown candidate schema is rejected")
    if row.get("body_persisted") is not False:
        raise IntakeError("candidate body_persisted must be false")
    if row.get("review_status") != "review-required":
        raise IntakeError("candidate review_status must be review-required")
    if row.get("auto_actions") != []:
        raise IntakeError("candidate auto_actions must be empty")
    required = {
        "schema_version",
        "candidate_id",
        "source_id",
        "provider",
        "source_type",
        "authority_level",
        "title",
        "canonical_url",
        "repository",
        "revision",
        "published_at",
        "last_activity_at",
        "retrieved_at",
        "review_after",
        "expires_at",
        "license",
        "topics",
        "summary",
        "content_sha256",
        "transport",
        "body_persisted",
        "trust_status",
        "review_status",
        "risk_flags",
        "evidence_refs",
        "asset_recommendation",
        "auto_actions",
    }
    if set(row) != required:
        missing = sorted(required - set(row))
        extra = sorted(set(row) - required)
        raise IntakeError("candidate field set mismatch missing={} extra={}".format(missing, extra))
    provider = row.get("provider")
    if provider not in PROVIDERS:
        raise IntakeError("candidate provider is invalid")
    provider_policy = _provider_policy(policy, str(provider))
    if row.get("source_type") != provider_policy.get("source_type"):
        raise IntakeError("candidate source_type does not match provider policy")
    if row.get("authority_level") != provider_policy.get("authority_level"):
        raise IntakeError("candidate authority_level does not match provider policy")
    if row.get("transport") != provider_policy.get("transport"):
        raise IntakeError("candidate transport does not match provider policy")
    source_id = row.get("source_id")
    if not isinstance(source_id, str) or not ID_RE.fullmatch(source_id):
        raise IntakeError("candidate source_id is invalid")
    _clean_text(row.get("title"), "candidate.title", policy["limits"]["title_characters"], allow_empty=False)
    url = _canonical_url(
        row.get("canonical_url"),
        provider_policy["allowed_hosts"],
        repository=provider in NETWORK_PROVIDERS,
    )
    if url != row.get("canonical_url"):
        raise IntakeError("candidate canonical_url is not canonical")
    repository_value = _validate_repository(row.get("repository"), str(provider))
    revision = row.get("revision")
    if revision is not None:
        revision = _clean_text(revision, "candidate.revision", 200, allow_empty=False)
    published = _date_or_none(row.get("published_at"), "candidate.published_at")
    last_activity = _date_or_none(row.get("last_activity_at"), "candidate.last_activity_at")
    retrieved = _parse_date(row.get("retrieved_at"), "candidate.retrieved_at")
    review_after = _parse_date(row.get("review_after"), "candidate.review_after")
    expires = _date_or_none(row.get("expires_at"), "candidate.expires_at")
    if review_after < retrieved:
        raise IntakeError("candidate review_after must not precede retrieved_at")
    if published and published > retrieved:
        raise IntakeError("candidate published_at must not be in the future")
    if last_activity and last_activity > retrieved:
        raise IntakeError("candidate last_activity_at must not be in the future")
    license_value = _clean_text(row.get("license"), "candidate.license", 160, allow_empty=False)
    topics = _topics(row.get("topics"), policy["limits"]["topics_per_candidate"])
    if topics != row.get("topics"):
        raise IntakeError("candidate topics must be normalized, unique and sorted by first occurrence")
    _clean_text(row.get("summary"), "candidate.summary", policy["limits"]["summary_characters"])
    content_hash = row.get("content_sha256")
    if content_hash is not None and (not isinstance(content_hash, str) or not HEX64_RE.fullmatch(content_hash)):
        raise IntakeError("candidate content_sha256 is invalid")
    if row.get("trust_status") not in {"trusted-metadata", "unverified-metadata", "degraded"}:
        raise IntakeError("candidate trust_status is invalid")
    if provider == "manual" and row.get("trust_status") != "unverified-metadata":
        raise IntakeError("manual candidates must remain unverified")
    risks = row.get("risk_flags")
    if not isinstance(risks, list) or len(risks) > 50 or len(risks) != len(set(risks)):
        raise IntakeError("candidate risk_flags must be a unique bounded array")
    if not all(isinstance(item, str) and RISK_RE.fullmatch(item) for item in risks):
        raise IntakeError("candidate risk_flags contain an invalid code")
    required_risks = set()
    if license_value.lower() in {"unknown", "noassertion", "other"}:
        required_risks.add("license-review-required")
    if repository_value is not None and repository_value.get("archived") is True:
        required_risks.add("archived-source")
    if expires and expires < retrieved:
        required_risks.add("source-expired")
    if provider == "manual":
        required_risks.update({"manual-input", "unverified-source"})
    if provider == "wechat":
        required_risks.update({"copyright-review-required", "secondary-source"})
    if not required_risks.issubset(set(risks)):
        raise IntakeError("candidate risk_flags omit a required source risk")
    refs = row.get("evidence_refs")
    if not isinstance(refs, list) or not refs or len(refs) > 50 or len(refs) != len(set(refs)):
        raise IntakeError("candidate evidence_refs must be a non-empty unique bounded array")
    for ref in refs:
        cleaned = _clean_text(ref, "candidate.evidence_ref", 500, allow_empty=False)
        if cleaned != ref or SECRET_REF_RE.search(ref) or ref.startswith("/") or ".." in Path(ref).parts:
            raise IntakeError("candidate evidence_ref is unsafe")
    if row.get("asset_recommendation") not in ASSET_RECOMMENDATIONS:
        raise IntakeError("candidate asset_recommendation is invalid")
    expected_id = _candidate_id(str(provider), url, revision, content_hash)
    if row.get("candidate_id") != expected_id or not CANDIDATE_ID_RE.fullmatch(str(row.get("candidate_id", ""))):
        raise IntakeError("candidate_id does not match the stable identity contract")
    return row


def _validate_decision(row: Any) -> Mapping[str, Any]:
    if not isinstance(row, dict) or row.get("schema_version") != DECISION_SCHEMA:
        raise IntakeError("decision must use external-practice-decision/v1")
    required = {"schema_version", "candidate_id", "decision", "owner", "reviewed_at", "rationale", "target", "evidence_refs"}
    if set(row) != required:
        raise IntakeError("decision field set is incomplete or unsupported")
    if not CANDIDATE_ID_RE.fullmatch(str(row.get("candidate_id", ""))):
        raise IntakeError("decision candidate_id is invalid")
    if row.get("decision") not in DECISIONS:
        raise IntakeError("decision value is invalid")
    owner = _clean_text(row.get("owner"), "decision.owner", 160, allow_empty=False)
    if owner.lower() in {"automation", "collector", "external-practice-curator", "unknown", "none"}:
        raise IntakeError("decision owner must be an independent accountable owner")
    _parse_date(row.get("reviewed_at"), "decision.reviewed_at")
    rationale = _clean_text(row.get("rationale"), "decision.rationale", 2000, allow_empty=False)
    if len(rationale) < 20:
        raise IntakeError("decision rationale must contain at least 20 characters")
    _clean_text(row.get("target"), "decision.target", 300, allow_empty=False)
    refs = row.get("evidence_refs")
    if not isinstance(refs, list) or not refs or len(refs) > 50 or len(refs) != len(set(refs)):
        raise IntakeError("decision evidence_refs must be a non-empty unique array")
    for ref in refs:
        cleaned = _clean_text(ref, "decision.evidence_ref", 500, allow_empty=False)
        if cleaned != ref or SECRET_REF_RE.search(ref) or ref.startswith("/") or ".." in Path(ref).parts:
            raise IntakeError("decision evidence_ref is unsafe")
    return row


def _validate_plan(plan: Any) -> Mapping[str, Any]:
    if not isinstance(plan, dict) or plan.get("schema") != PLAN_SCHEMA or plan.get("mode") != "report-only":
        raise IntakeError("cycle plan must use the report-only v1 schema")
    allowed_root = {"schema", "mode", "as_of", "allow_degraded", "jobs"}
    if set(plan) - allowed_root or not {"schema", "mode", "allow_degraded", "jobs"}.issubset(plan):
        raise IntakeError("cycle plan field set is unsupported")
    if "as_of" in plan:
        _parse_date(plan["as_of"], "cycle plan as_of")
    if not isinstance(plan.get("allow_degraded"), bool):
        raise IntakeError("cycle plan allow_degraded must be boolean")
    jobs = plan.get("jobs")
    if not isinstance(jobs, list) or not 1 <= len(jobs) <= 50:
        raise IntakeError("cycle plan jobs must be a non-empty bounded array")
    ids = set()
    base_job = {"id", "provider", "enabled", "max_results"}
    for job in jobs:
        if not isinstance(job, dict):
            raise IntakeError("cycle jobs must be objects")
        if not base_job.issubset(job):
            raise IntakeError("cycle job required fields are missing")
        job_id = job.get("id")
        if not isinstance(job_id, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,79}", job_id) or job_id in ids:
            raise IntakeError("cycle job id is invalid or duplicated")
        ids.add(job_id)
        provider = job.get("provider")
        if provider not in PROVIDERS:
            raise IntakeError("cycle job provider is invalid")
        if provider in NETWORK_PROVIDERS:
            allowed_job = base_job | {"query", "fixture"}
        elif provider in OFFICIAL_PROVIDERS or provider == "wechat":
            allowed_job = base_job | {"input"}
        else:
            allowed_job = base_job | {"input", "urls"}
        if set(job) - allowed_job:
            raise IntakeError("cycle job contains fields that its provider does not consume")
        if not isinstance(job.get("enabled"), bool):
            raise IntakeError("cycle job enabled must be boolean")
        maximum = job.get("max_results")
        if isinstance(maximum, bool) or not isinstance(maximum, int) or not 1 <= maximum <= 100:
            raise IntakeError("cycle job max_results must be in 1..100")
        if provider in NETWORK_PROVIDERS:
            _clean_text(job.get("query"), "cycle job query", 500, allow_empty=False)
        elif provider in OFFICIAL_PROVIDERS or provider == "wechat":
            _clean_text(job.get("input"), "cycle job input", 500, allow_empty=False)
        elif provider == "manual" and not job.get("input") and not job.get("urls"):
            raise IntakeError("manual cycle job requires input or urls")
        for path_field in ("input", "fixture"):
            value = job.get(path_field)
            if value is not None:
                cleaned = _clean_text(value, "cycle job {}".format(path_field), 500, allow_empty=False)
                if Path(cleaned).is_absolute() or ".." in Path(cleaned).parts:
                    raise IntakeError("cycle plan paths must be repository-relative")
        if "urls" in job:
            urls = job.get("urls")
            if not isinstance(urls, list) or len(urls) > 100 or not all(isinstance(item, str) for item in urls):
                raise IntakeError("cycle job urls must be a bounded string array")
    if not any(job["enabled"] for job in jobs):
        raise IntakeError("cycle plan must enable at least one job")
    return plan


def _safe_rate_limit(headers: Mapping[str, Any]) -> Dict[str, str]:
    result: Dict[str, str] = {}
    names = {
        "x-ratelimit-limit": "limit",
        "x-ratelimit-remaining": "remaining",
        "x-ratelimit-reset": "reset",
        "ratelimit-limit": "limit",
        "ratelimit-remaining": "remaining",
        "ratelimit-reset": "reset",
    }
    for header, target in names.items():
        value = headers.get(header)
        if value is None:
            value = headers.get(header.title())
        if value is not None and re.fullmatch(r"[0-9]{1,20}", str(value)):
            result[target] = str(value)
    return result


def _network_payload(
    provider: str,
    query: str,
    maximum: int,
    provider_policy: Mapping[str, Any],
    limits: Mapping[str, int],
) -> Tuple[Any, Mapping[str, str], Mapping[str, str]]:
    endpoint = str(provider_policy["endpoint"])
    params: Dict[str, Any]
    if provider == "github":
        params = {"q": query, "sort": "updated", "order": "desc", "per_page": maximum}
    elif provider == "gitlab":
        params = {"search": query, "order_by": "last_activity_at", "sort": "desc", "simple": "true", "per_page": maximum}
    else:
        params = {"q": query, "sort": "last_push_at", "order": "desc", "per_page": maximum}
    headers = {"Accept": "application/json", "User-Agent": "llm-agent-practice-intake/1"}
    token = os.environ.get(str(provider_policy["token_env"]), "")
    if token:
        if CONTROL_RE.search(token) or len(token) > 4096:
            raise IntakeError("configured provider credential is malformed")
        if provider == "github":
            headers["Authorization"] = "Bearer {}".format(token)
        elif provider == "gitlab":
            headers["PRIVATE-TOKEN"] = token
        else:
            params["access_token"] = token
    url = "{}?{}".format(endpoint, urllib.parse.urlencode(params))
    request = urllib.request.Request(url, headers=headers, method="GET")
    opener = urllib.request.build_opener(_NoRedirect())
    try:
        with opener.open(request, timeout=limits["timeout_seconds"]) as response:
            declared = response.headers.get("Content-Length")
            if declared and declared.isdigit() and int(declared) > limits["response_bytes"]:
                raise IntakeError("provider response exceeds the byte budget")
            raw = response.read(limits["response_bytes"] + 1)
            if len(raw) > limits["response_bytes"]:
                raise IntakeError("provider response exceeds the byte budget")
            response_headers = dict(response.headers.items())
    except urllib.error.HTTPError as exc:
        raise IntakeError("provider request failed with HTTP {}".format(exc.code)) from None
    except urllib.error.URLError:
        raise IntakeError("provider request failed at the transport layer") from None
    except TimeoutError:
        raise IntakeError("provider request timed out") from None
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise IntakeError("provider response is not valid UTF-8 JSON") from exc
    parsed = urllib.parse.urlsplit(endpoint)
    request_ref = {
        "host": str(parsed.hostname),
        "path": parsed.path,
        "query_sha256": _sha256_bytes(query.encode("utf-8"))[:16],
    }
    return payload, _safe_rate_limit(response_headers), request_ref


def _repository_candidate(
    provider: str,
    item: Mapping[str, Any],
    as_of: str,
    policy: Mapping[str, Any],
    evidence_ref: str,
) -> Mapping[str, Any]:
    provider_policy = _provider_policy(policy, provider)
    if provider == "github":
        full_name = _clean_text(item.get("full_name"), "github full_name", 300, allow_empty=False)
        raw_url = item.get("html_url") or "https://github.com/{}".format(full_name)
        description = item.get("description") or ""
        topics = item.get("topics") or []
        stars = item.get("stargazers_count")
        forks = item.get("forks_count")
        watchers = item.get("watchers_count", stars)
        activity = item.get("pushed_at") or item.get("updated_at")
        license_data = item.get("license")
        if isinstance(license_data, dict):
            license_value = license_data.get("spdx_id") or license_data.get("key") or license_data.get("name") or "unknown"
        else:
            license_value = "unknown"
        archived = item.get("archived")
        branch = item.get("default_branch")
        language = item.get("language")
        host = "github.com"
    elif provider == "gitlab":
        full_name = _clean_text(item.get("path_with_namespace"), "gitlab path_with_namespace", 300, allow_empty=False)
        raw_url = item.get("web_url") or "https://gitlab.com/{}".format(full_name)
        description = item.get("description") or ""
        topics = item.get("topics") or []
        stars = item.get("star_count")
        forks = item.get("forks_count")
        watchers = None
        activity = item.get("last_activity_at")
        license_value = "unknown"
        archived = item.get("archived")
        branch = item.get("default_branch")
        language = None
        host = "gitlab.com"
    else:
        full_name = _clean_text(item.get("full_name") or item.get("path"), "gitee full_name", 300, allow_empty=False)
        raw_url = item.get("html_url") or "https://gitee.com/{}".format(full_name)
        description = item.get("description") or ""
        topics = item.get("topics") or []
        stars = item.get("stars_count")
        forks = item.get("forks_count")
        watchers = item.get("watches_count")
        activity = item.get("last_push_at") or item.get("updated_at")
        license_data = item.get("license")
        if isinstance(license_data, dict):
            license_value = license_data.get("spdx_id") or license_data.get("name") or "unknown"
        elif isinstance(license_data, str) and license_data.strip():
            license_value = license_data
        else:
            license_value = "unknown"
        archived = item.get("archived")
        if archived is None and item.get("status") == "closed":
            archived = True
        branch = item.get("default_branch")
        language = item.get("language")
        host = "gitee.com"
    if "/" not in full_name or any(part in {"", ".", ".."} for part in full_name.split("/")):
        raise IntakeError("forge repository identity is invalid")
    title = full_name
    summary = _clean_text(description, "repository description", policy["limits"]["summary_characters"])
    normalized_topics = _topics(topics, policy["limits"]["topics_per_candidate"])
    canonical = _canonical_url(raw_url, provider_policy["allowed_hosts"], repository=True)
    activity_date = _date_or_none(activity, "repository last activity")
    archived_value: Optional[bool]
    if archived is None:
        archived_value = None
    elif isinstance(archived, bool):
        archived_value = archived
    else:
        raise IntakeError("repository archived field must be boolean or null")
    license_clean = _clean_text(license_value, "repository license", 160, allow_empty=False)
    repository = {
        "full_name": full_name,
        "host": host,
        "default_branch": None if branch is None else _clean_text(branch, "repository default branch", 200, allow_empty=False),
        "stars_count": _nonnegative_int(stars, "repository stars"),
        "forks_count": _nonnegative_int(forks, "repository forks"),
        "watchers_count": _nonnegative_int(watchers, "repository watchers"),
        "archived": archived_value,
        "language": None if language is None else _clean_text(language, "repository language", 100, allow_empty=False),
    }
    content_hash = _sha256_value({
        "provider": provider,
        "url": canonical,
        "description": summary,
        "topics": normalized_topics,
        "repository": repository,
        "last_activity_at": activity_date,
        "license": license_clean,
    })
    risks = _risk_flags(license_clean, archived_value, activity_date, as_of, int(provider_policy["freshness_days"]))
    candidate = {
        "schema_version": CANDIDATE_SCHEMA,
        "candidate_id": _candidate_id(provider, canonical, activity_date, content_hash),
        "source_id": "{}-search".format(provider),
        "provider": provider,
        "source_type": provider_policy["source_type"],
        "authority_level": provider_policy["authority_level"],
        "title": _clean_text(title, "candidate title", policy["limits"]["title_characters"], allow_empty=False),
        "canonical_url": canonical,
        "repository": repository,
        "revision": activity_date,
        "published_at": None,
        "last_activity_at": activity_date,
        "retrieved_at": as_of,
        "review_after": as_of,
        "expires_at": _future_date(as_of, int(provider_policy["freshness_days"])),
        "license": license_clean,
        "topics": normalized_topics,
        "summary": summary,
        "content_sha256": content_hash,
        "transport": provider_policy["transport"],
        "body_persisted": False,
        "trust_status": "trusted-metadata",
        "review_status": "review-required",
        "risk_flags": sorted(set(risks)),
        "evidence_refs": [evidence_ref],
        "asset_recommendation": _recommend(title, summary, normalized_topics),
        "auto_actions": [],
    }
    return _validate_candidate(candidate, policy)


def _forge_candidates(
    provider: str,
    payload: Any,
    maximum: int,
    as_of: str,
    policy: Mapping[str, Any],
    evidence_ref: str,
) -> Tuple[List[Mapping[str, Any]], str]:
    if provider == "github":
        if not isinstance(payload, dict) or not isinstance(payload.get("items"), list):
            raise IntakeError("GitHub response must contain an items array")
        items = payload["items"]
    else:
        if not isinstance(payload, list):
            raise IntakeError("{} response must be an array".format(provider))
        items = payload
    if len(items) > policy["limits"]["candidates_per_job"]:
        items = items[: policy["limits"]["candidates_per_job"]]
    result: List[Mapping[str, Any]] = []
    for item in items[:maximum]:
        if not isinstance(item, dict):
            raise IntakeError("{} response items must be objects".format(provider))
        result.append(_repository_candidate(provider, item, as_of, policy, evidence_ref))
    if provider == "gitee" and not result:
        return result, "degraded-empty"
    return result, "complete"


def _official_candidates(
    provider: str,
    path: Path,
    maximum: int,
    as_of: str,
    policy: Mapping[str, Any],
    evidence_ref: str,
) -> List[Mapping[str, Any]]:
    provider_policy = _provider_policy(policy, provider)
    manifest = _load_json(path, policy["limits"]["response_bytes"], "official source manifest")
    if not isinstance(manifest, dict) or not isinstance(manifest.get("sources"), list):
        raise IntakeError("official source manifest must contain a sources array")
    result: List[Mapping[str, Any]] = []
    for source in manifest["sources"]:
        if not isinstance(source, dict):
            raise IntakeError("official source records must be objects")
        raw_url = source.get("url")
        if not isinstance(raw_url, str):
            raise IntakeError("official source url is missing")
        host = (urllib.parse.urlsplit(raw_url).hostname or "").lower()
        if host not in provider_policy["allowed_hosts"]:
            continue
        canonical = _canonical_url(raw_url, provider_policy["allowed_hosts"])
        source_id_raw = _clean_text(source.get("id"), "official source id", 120, allow_empty=False)
        source_id = "{}:{}".format(provider, source_id_raw)
        if not ID_RE.fullmatch(source_id):
            raise IntakeError("official source id is invalid")
        title = _clean_text(source.get("title"), "official title", policy["limits"]["title_characters"], allow_empty=False)
        summary = _clean_text(source.get("decision") or "", "official decision summary", policy["limits"]["summary_characters"])
        retrieved_source = _parse_date(source.get("retrieved_at"), "official retrieved_at")
        expires = _date_or_none(source.get("expires_at"), "official expires_at")
        content_hash = _sha256_value(source)
        risks = ["license-review-required", "platform-specific"]
        if expires and expires < as_of:
            risks.append("source-expired")
        if source.get("review_status") == "rejected":
            risks.append("source-rejected")
        candidate = {
            "schema_version": CANDIDATE_SCHEMA,
            "candidate_id": _candidate_id(provider, canonical, retrieved_source, content_hash),
            "source_id": source_id,
            "provider": provider,
            "source_type": provider_policy["source_type"],
            "authority_level": provider_policy["authority_level"],
            "title": title,
            "canonical_url": canonical,
            "repository": None,
            "revision": retrieved_source,
            "published_at": None,
            "last_activity_at": retrieved_source,
            "retrieved_at": as_of,
            "review_after": as_of,
            "expires_at": expires,
            "license": "unknown",
            "topics": _topics([source.get("adoption_scope", "official")], policy["limits"]["topics_per_candidate"]),
            "summary": summary,
            "content_sha256": content_hash,
            "transport": provider_policy["transport"],
            "body_persisted": False,
            "trust_status": "trusted-metadata",
            "review_status": "review-required",
            "risk_flags": sorted(set(risks)),
            "evidence_refs": [evidence_ref],
            "asset_recommendation": _recommend(title, summary, [str(source.get("adoption_scope", "official"))]),
            "auto_actions": [],
        }
        result.append(_validate_candidate(candidate, policy))
        if len(result) >= maximum:
            break
    return result


def _wechat_candidates(
    path: Path,
    maximum: int,
    as_of: str,
    policy: Mapping[str, Any],
    evidence_ref: str,
) -> List[Mapping[str, Any]]:
    provider = "wechat"
    provider_policy = _provider_policy(policy, provider)
    records = _load_jsonl(path, policy["limits"]["response_bytes"], "WeChat metadata catalog")
    result: List[Mapping[str, Any]] = []
    for record in records[:maximum]:
        if record.get("body_persisted") is not False:
            raise IntakeError("WeChat catalog body_persisted must be false")
        canonical = _canonical_url(record.get("source_url"), provider_policy["allowed_hosts"])
        source_id = _clean_text(record.get("record_id"), "WeChat record_id", 160, allow_empty=False)
        if not ID_RE.fullmatch(source_id):
            raise IntakeError("WeChat record_id is invalid")
        title = _clean_text(record.get("title"), "WeChat title", policy["limits"]["title_characters"], allow_empty=False)
        summary = _clean_text(record.get("why_selected") or "", "WeChat why_selected", policy["limits"]["summary_characters"])
        published = _parse_date(record.get("wechat_pub_date"), "WeChat publication date")
        content_hash = record.get("content_sha256")
        if not isinstance(content_hash, str) or not HEX64_RE.fullmatch(content_hash):
            content_hash = _sha256_value(record)
        topics = _topics(record.get("themes") or [], policy["limits"]["topics_per_candidate"])
        risks = ["copyright-review-required", "secondary-source"]
        verification_status = record.get("verification_status")
        trusted_statuses = set(provider_policy["trusted_verification_statuses"])
        trusted = isinstance(verification_status, str) and verification_status in trusted_statuses
        if not trusted:
            risks.append("verification-review-required")
        if record.get("locator_kind") not in {"stable-wechat-short-url", "official-company-site", "official-company-mirror"}:
            risks.append("untrusted-locator")
        candidate = {
            "schema_version": CANDIDATE_SCHEMA,
            "candidate_id": _candidate_id(provider, canonical, content_hash, content_hash),
            "source_id": source_id,
            "provider": provider,
            "source_type": provider_policy["source_type"],
            "authority_level": provider_policy["authority_level"],
            "title": title,
            "canonical_url": canonical,
            "repository": None,
            "revision": content_hash,
            "published_at": published,
            "last_activity_at": published,
            "retrieved_at": as_of,
            "review_after": as_of,
            "expires_at": _future_date(as_of, int(provider_policy["freshness_days"])),
            "license": "copyright-restricted",
            "topics": topics,
            "summary": summary,
            "content_sha256": content_hash,
            "transport": provider_policy["transport"],
            "body_persisted": False,
            "trust_status": "trusted-metadata" if trusted else "unverified-metadata",
            "review_status": "review-required",
            "risk_flags": sorted(set(risks)),
            "evidence_refs": [evidence_ref],
            "asset_recommendation": _recommend(title, summary, topics),
            "auto_actions": [],
        }
        result.append(_validate_candidate(candidate, policy))
    return result


def _manual_repository(url: str) -> Optional[Mapping[str, Any]]:
    parsed = urllib.parse.urlsplit(url)
    host = parsed.hostname
    if host not in {"github.com", "gitlab.com", "gitee.com"}:
        return None
    full_name = parsed.path.strip("/")
    if full_name.endswith(".git"):
        full_name = full_name[:-4]
    if "/" not in full_name:
        return None
    return {
        "full_name": full_name,
        "host": host,
        "default_branch": None,
        "stars_count": None,
        "forks_count": None,
        "watchers_count": None,
        "archived": None,
        "language": None,
    }


def _manual_candidates(
    path: Optional[Path],
    urls: Sequence[str],
    maximum: int,
    as_of: str,
    policy: Mapping[str, Any],
    input_ref: Optional[str],
) -> List[Mapping[str, Any]]:
    provider = "manual"
    provider_policy = _provider_policy(policy, provider)
    records: List[Dict[str, Any]] = []
    if path is not None:
        records.extend(_load_jsonl(path, policy["limits"]["response_bytes"], "manual input ledger"))
    records.extend({"url": item} for item in urls)
    if not records:
        raise IntakeError("manual collection requires --input or --url")
    result: List[Mapping[str, Any]] = []
    for record in records[:maximum]:
        raw_url = record.get("url") or record.get("source_url")
        canonical = _canonical_url(raw_url, provider_policy["allowed_hosts"], repository=(urllib.parse.urlsplit(str(raw_url)).hostname in {"github.com", "gitlab.com", "gitee.com"}))
        content_hash = _sha256_value(record)
        raw_source_id = record.get("source_id") or "manual-{}".format(content_hash[:16])
        source_id = _clean_text(raw_source_id, "manual source_id", 160, allow_empty=False)
        if not ID_RE.fullmatch(source_id):
            raise IntakeError("manual source_id is invalid")
        title = _clean_text(record.get("title") or urllib.parse.urlsplit(canonical).path.strip("/"), "manual title", policy["limits"]["title_characters"], allow_empty=False)
        summary = _clean_text(record.get("summary") or "Manual metadata reference; independent review is required.", "manual summary", policy["limits"]["summary_characters"])
        topics = _topics(record.get("topics") or [], policy["limits"]["topics_per_candidate"])
        revision_value = record.get("revision")
        revision = content_hash if revision_value in (None, "") else _clean_text(revision_value, "manual revision", 200, allow_empty=False)
        license_value = _clean_text(record.get("license") or "unknown", "manual license", 160, allow_empty=False)
        repository = _manual_repository(canonical)
        risks = ["manual-input", "unverified-source"]
        if license_value.lower() in {"unknown", "noassertion", "other"}:
            risks.append("license-review-required")
        evidence_ref = input_ref if path is not None else "manual-cli-url-sha256:{}".format(_sha256_bytes(canonical.encode("utf-8"))[:16])
        candidate = {
            "schema_version": CANDIDATE_SCHEMA,
            "candidate_id": _candidate_id(provider, canonical, revision, content_hash),
            "source_id": source_id,
            "provider": provider,
            "source_type": provider_policy["source_type"],
            "authority_level": provider_policy["authority_level"],
            "title": title,
            "canonical_url": canonical,
            "repository": repository,
            "revision": revision,
            "published_at": _date_or_none(record.get("published_at"), "manual published_at"),
            "last_activity_at": _date_or_none(record.get("last_activity_at"), "manual last_activity_at"),
            "retrieved_at": as_of,
            "review_after": as_of,
            "expires_at": _future_date(as_of, int(provider_policy["freshness_days"])),
            "license": license_value,
            "topics": topics,
            "summary": summary,
            "content_sha256": content_hash,
            "transport": provider_policy["transport"],
            "body_persisted": False,
            "trust_status": "unverified-metadata",
            "review_status": "review-required",
            "risk_flags": sorted(set(risks)),
            "evidence_refs": [evidence_ref],
            "asset_recommendation": _recommend(title, summary, topics),
            "auto_actions": [],
        }
        result.append(_validate_candidate(candidate, policy))
    return result


def _deduplicate(candidates: Sequence[Mapping[str, Any]], policy: Mapping[str, Any]) -> Tuple[List[Mapping[str, Any]], int]:
    selected: Dict[str, Dict[str, Any]] = {}
    sightings = 0
    for candidate in sorted(candidates, key=lambda item: (str(item["canonical_url"]), str(item["provider"]), str(item["candidate_id"]))):
        key = str(candidate["canonical_url"])
        if key not in selected:
            selected[key] = dict(candidate)
            continue
        sightings += 1
        current = selected[key]
        current_rank = AUTHORITY_RANK[str(current["authority_level"])]
        candidate_rank = AUTHORITY_RANK[str(candidate["authority_level"])]
        winner = current
        loser = candidate
        if (candidate_rank, len(candidate["risk_flags"]), str(candidate["provider"])) < (
            current_rank,
            len(current["risk_flags"]),
            str(current["provider"]),
        ):
            winner = dict(candidate)
            loser = current
        winner["evidence_refs"] = sorted(set(list(winner["evidence_refs"]) + list(loser["evidence_refs"])))
        winner["risk_flags"] = sorted(set(list(winner["risk_flags"]) + list(loser["risk_flags"])))
        winner["topics"] = list(dict.fromkeys(list(winner["topics"]) + list(loser["topics"])))[: policy["limits"]["topics_per_candidate"]]
        selected[key] = winner
    result = [selected[key] for key in sorted(selected)]
    for row in result:
        _validate_candidate(row, policy)
    return result, sightings


def _job_record(
    job_id: str,
    provider: str,
    mode: str,
    status: str,
    candidate_count: int,
    duration_ms: int,
    input_ref: Optional[str] = None,
    input_sha256: Optional[str] = None,
    request_ref: Optional[Mapping[str, str]] = None,
    rate_limit: Optional[Mapping[str, str]] = None,
    error_code: Optional[str] = None,
) -> Dict[str, Any]:
    return {
        "id": job_id,
        "provider": provider,
        "transport": "metadata-only" if provider in NETWORK_PROVIDERS else "ledger-only",
        "mode": mode,
        "request": request_ref,
        "input_ref": input_ref,
        "input_sha256": input_sha256,
        "status": status,
        "candidate_count": candidate_count,
        "deduplicated_count": 0,
        "rate_limit": dict(rate_limit or {}),
        "duration_ms": duration_ms,
        "error_code": error_code,
    }


def _collect_job(
    root: Path,
    policy: Mapping[str, Any],
    job: Mapping[str, Any],
    as_of: str,
    allow_network: bool,
) -> Tuple[List[Mapping[str, Any]], Dict[str, Any]]:
    started = time.monotonic()
    provider = str(job["provider"])
    job_id = str(job["id"])
    maximum = min(int(job["max_results"]), int(policy["limits"]["candidates_per_job"]))
    fixture_value = job.get("fixture")
    input_value = job.get("input")
    request_ref: Optional[Mapping[str, str]] = None
    rate_limit: Mapping[str, str] = {}
    input_ref: Optional[str] = None
    input_hash: Optional[str] = None
    if provider in NETWORK_PROVIDERS:
        query = _clean_text(job.get("query"), "provider query", 500, allow_empty=False)
        if fixture_value:
            fixture = _resolve_path(root, str(fixture_value), "provider fixture")
            payload = _load_json(fixture, policy["limits"]["response_bytes"], "provider fixture")
            input_hash = _sha256_file(fixture)
            input_ref = _input_reference(root, fixture, input_hash)
            mode = "fixture"
            evidence_ref = input_ref
        else:
            if not allow_network:
                elapsed = int((time.monotonic() - started) * 1000)
                return [], _job_record(job_id, provider, "not-run", "not-run-network-disabled", 0, elapsed)
            payload, rate_limit, request_ref = _network_payload(
                provider,
                query,
                maximum,
                _provider_policy(policy, provider),
                policy["limits"],
            )
            mode = "live"
            evidence_ref = "https://{}{}#query-sha256={}".format(
                request_ref["host"], request_ref["path"], request_ref["query_sha256"]
            )
        candidates, status = _forge_candidates(provider, payload, maximum, as_of, policy, evidence_ref)
    elif provider in OFFICIAL_PROVIDERS:
        path = _resolve_path(root, str(input_value), "official input")
        input_hash = _sha256_file(path)
        input_ref = _input_reference(root, path, input_hash)
        mode = "local"
        status = "complete"
        candidates = _official_candidates(provider, path, maximum, as_of, policy, input_ref)
    elif provider == "wechat":
        path = _resolve_path(root, str(input_value), "WeChat input")
        input_hash = _sha256_file(path)
        input_ref = _input_reference(root, path, input_hash)
        mode = "local"
        status = "complete"
        candidates = _wechat_candidates(path, maximum, as_of, policy, input_ref)
    else:
        path = _resolve_path(root, str(input_value), "manual input") if input_value else None
        input_hash = _sha256_file(path) if path is not None else None
        input_ref = _input_reference(root, path, input_hash) if path is not None and input_hash is not None else None
        mode = "manual"
        status = "complete"
        candidates = _manual_candidates(path, list(job.get("urls") or []), maximum, as_of, policy, input_ref)
    elapsed = int((time.monotonic() - started) * 1000)
    record = _job_record(
        job_id,
        provider,
        mode,
        status,
        len(candidates),
        elapsed,
        input_ref=input_ref,
        input_sha256=input_hash,
        request_ref=request_ref,
        rate_limit=rate_limit,
    )
    return candidates, record


def _evidence(as_of: str, status: str, candidates: Sequence[Mapping[str, Any]], deduplicated: int, jobs: Sequence[Mapping[str, Any]]) -> Dict[str, Any]:
    ledger_bytes = _jsonl_bytes(candidates)
    return {
        "schema": EVIDENCE_SCHEMA,
        "mode": "report-only",
        "as_of": as_of,
        "status": status,
        "candidate_count": len(candidates),
        "deduplicated_count": deduplicated,
        "ledger_sha256": _sha256_bytes(ledger_bytes),
        "jobs": list(jobs),
        "boundaries": dict(BOUNDARIES),
        "auto_actions": [],
    }


def _validate_job_evidence(job: Any) -> None:
    if not isinstance(job, dict):
        raise IntakeError("evidence jobs must be objects")
    required = {
        "id",
        "provider",
        "transport",
        "mode",
        "request",
        "input_ref",
        "input_sha256",
        "status",
        "candidate_count",
        "deduplicated_count",
        "rate_limit",
        "duration_ms",
        "error_code",
    }
    if set(job) != required:
        raise IntakeError("evidence job field set is unsupported")
    provider = job.get("provider")
    if provider not in PROVIDERS:
        raise IntakeError("evidence job provider is invalid")
    job_id = job.get("id")
    if not isinstance(job_id, str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,79}", job_id):
        raise IntakeError("evidence job id is invalid")
    expected_transport = "metadata-only" if provider in NETWORK_PROVIDERS else "ledger-only"
    if job.get("transport") != expected_transport:
        raise IntakeError("evidence job transport does not match its provider")
    mode = job.get("mode")
    if mode not in {"fixture", "live", "local", "manual", "not-run"}:
        raise IntakeError("evidence job mode is invalid")
    if mode in {"fixture", "live"} and provider not in NETWORK_PROVIDERS:
        raise IntakeError("evidence network mode does not match its provider")
    if mode == "local" and provider not in OFFICIAL_PROVIDERS | {"wechat"}:
        raise IntakeError("evidence local mode does not match its provider")
    if mode == "manual" and provider != "manual":
        raise IntakeError("evidence manual mode does not match its provider")
    if mode == "not-run" and provider not in NETWORK_PROVIDERS:
        raise IntakeError("only network providers may be not-run")
    status = job.get("status")
    if status not in {"complete", "degraded-empty", "not-run-network-disabled", "failed"}:
        raise IntakeError("evidence job status is invalid")
    if status == "complete" and mode == "not-run":
        raise IntakeError("a not-run job cannot be complete")
    if status == "degraded-empty" and (provider != "gitee" or mode not in {"fixture", "live"}):
        raise IntakeError("degraded-empty is reserved for Gitee search")
    if status == "not-run-network-disabled" and mode != "not-run":
        raise IntakeError("network-disabled evidence must use not-run mode")
    if status == "failed" and mode != "not-run":
        raise IntakeError("failed evidence must use not-run mode")
    for field in ("candidate_count", "deduplicated_count", "duration_ms"):
        value = job.get(field)
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            raise IntakeError("evidence job {} must be a non-negative integer".format(field))
    if job["deduplicated_count"] > job["candidate_count"]:
        raise IntakeError("evidence job deduplicated_count exceeds candidate_count")
    if status in {"degraded-empty", "not-run-network-disabled", "failed"} and job["candidate_count"] != 0:
        raise IntakeError("non-complete evidence jobs must not claim candidates")
    request = job.get("request")
    if mode == "live":
        if not isinstance(request, dict) or set(request) != {"host", "path", "query_sha256"}:
            raise IntakeError("evidence request must contain only sanitized fields")
        endpoint = urllib.parse.urlsplit(EXPECTED_ENDPOINTS[str(provider)])
        if request.get("host") != endpoint.hostname or request.get("path") != endpoint.path:
            raise IntakeError("evidence request does not match the provider endpoint")
        if not re.fullmatch(r"[0-9a-f]{16}", str(request.get("query_sha256", ""))):
            raise IntakeError("evidence request query hash is invalid")
        if SECRET_REF_RE.search(json.dumps(request, sort_keys=True)):
            raise IntakeError("evidence request contains a credential field")
    elif request is not None:
        raise IntakeError("only live evidence may contain a request reference")
    input_ref = job.get("input_ref")
    input_hash = job.get("input_sha256")
    if input_hash is not None and (not isinstance(input_hash, str) or not HEX64_RE.fullmatch(input_hash)):
        raise IntakeError("evidence input_sha256 is invalid")
    if input_ref is not None:
        cleaned = _clean_text(input_ref, "evidence input_ref", 500, allow_empty=False)
        if cleaned != input_ref or SECRET_REF_RE.search(input_ref) or input_ref.startswith("/") or ".." in Path(input_ref).parts:
            raise IntakeError("evidence input_ref is unsafe")
    if mode in {"fixture", "local"} and (input_ref is None or input_hash is None):
        raise IntakeError("fixture/local evidence requires an input reference and hash")
    if mode in {"live", "not-run"} and (input_ref is not None or input_hash is not None):
        raise IntakeError("live/not-run evidence must not claim a local input")
    if mode == "manual" and ((input_ref is None) != (input_hash is None)):
        raise IntakeError("manual evidence input reference and hash must appear together")
    rate_limit = job.get("rate_limit")
    if not isinstance(rate_limit, dict) or set(rate_limit) - {"limit", "remaining", "reset"}:
        raise IntakeError("evidence rate_limit must be an object")
    if not all(isinstance(item, str) and re.fullmatch(r"[0-9]{1,20}", item) for item in rate_limit.values()):
        raise IntakeError("evidence rate_limit contains an invalid value")
    if mode != "live" and rate_limit:
        raise IntakeError("only live evidence may contain rate-limit metadata")
    error_code = job.get("error_code")
    if status == "failed":
        if error_code != "intake-job-failed":
            raise IntakeError("failed evidence must use the sanitized stable error code")
    elif error_code is not None:
        raise IntakeError("non-failed evidence must not contain an error code")


def _validate_evidence(value: Any) -> Mapping[str, Any]:
    if not isinstance(value, dict) or value.get("schema") != EVIDENCE_SCHEMA or value.get("mode") != "report-only":
        raise IntakeError("cycle evidence must use the report-only v1 schema")
    required = {
        "schema",
        "mode",
        "as_of",
        "status",
        "candidate_count",
        "deduplicated_count",
        "ledger_sha256",
        "jobs",
        "boundaries",
        "auto_actions",
    }
    if set(value) != required:
        raise IntakeError("cycle evidence field set is unsupported")
    _parse_date(value.get("as_of"), "evidence as_of")
    if value.get("status") not in {"complete", "degraded", "failed"}:
        raise IntakeError("cycle evidence status is invalid")
    for field, maximum in (("candidate_count", 500), ("deduplicated_count", 500)):
        number = value.get(field)
        if isinstance(number, bool) or not isinstance(number, int) or not 0 <= number <= maximum:
            raise IntakeError("cycle evidence {} is invalid".format(field))
    if not isinstance(value.get("ledger_sha256"), str) or not HEX64_RE.fullmatch(value["ledger_sha256"]):
        raise IntakeError("cycle evidence ledger_sha256 is invalid")
    jobs = value.get("jobs")
    if not isinstance(jobs, list) or not jobs or len(jobs) > 50:
        raise IntakeError("cycle evidence jobs are invalid")
    for job in jobs:
        _validate_job_evidence(job)
    if len({job["id"] for job in jobs}) != len(jobs):
        raise IntakeError("cycle evidence job ids must be unique")
    expected_count = sum(job["candidate_count"] for job in jobs) - value["deduplicated_count"]
    if expected_count != value["candidate_count"]:
        raise IntakeError("cycle evidence candidate totals are inconsistent")
    if any(job["status"] == "failed" for job in jobs):
        expected_status = "failed"
    elif any(job["status"] in {"degraded-empty", "not-run-network-disabled"} for job in jobs):
        expected_status = "degraded"
    else:
        expected_status = "complete"
    if value["status"] != expected_status:
        raise IntakeError("cycle evidence status is inconsistent with its jobs")
    if value.get("boundaries") != BOUNDARIES or value.get("auto_actions") != []:
        raise IntakeError("cycle evidence weakens report-only boundaries")
    return value


def _queue(as_of: str, candidates: Sequence[Mapping[str, Any]], jobs: Sequence[Mapping[str, Any]]) -> Dict[str, Any]:
    items: List[Mapping[str, Any]] = []
    for candidate in candidates:
        items.append({
            "type": "candidate-review",
            "candidate_id": candidate["candidate_id"],
            "provider": candidate["provider"],
            "status": "pending-owner-review",
            "title": candidate["title"],
            "canonical_url": candidate["canonical_url"],
            "asset_recommendation": candidate["asset_recommendation"],
            "risk_flags": candidate["risk_flags"],
            "evidence_refs": candidate["evidence_refs"],
        })
    degraded = False
    for job in jobs:
        if job.get("status") in {"degraded-empty", "not-run-network-disabled", "failed"}:
            degraded = True
            items.append({
                "type": "provider-health",
                "candidate_id": None,
                "provider": job["provider"],
                "status": job["status"],
                "title": str(job["id"]),
                "canonical_url": None,
                "asset_recommendation": "observe",
                "risk_flags": ["provider-degraded"],
                "evidence_refs": ["cycle-evidence:{}".format(job["id"])],
            })
    return {
        "schema": QUEUE_SCHEMA,
        "mode": "report-only",
        "as_of": as_of,
        "status": "degraded" if degraded else "review-required",
        "candidate_count": len(candidates),
        "items": items,
        "auto_actions": [],
    }


def _validate_queue(value: Any, policy: Mapping[str, Any]) -> Mapping[str, Any]:
    if not isinstance(value, dict) or value.get("schema") != QUEUE_SCHEMA or value.get("mode") != "report-only":
        raise IntakeError("review queue must use the report-only v1 schema")
    required = {"schema", "mode", "as_of", "status", "candidate_count", "items", "auto_actions"}
    if set(value) != required or value.get("auto_actions") != []:
        raise IntakeError("review queue field set or boundary is invalid")
    _parse_date(value.get("as_of"), "queue as_of")
    if value.get("status") not in {"review-required", "degraded"}:
        raise IntakeError("review queue status is invalid")
    count = value.get("candidate_count")
    if isinstance(count, bool) or not isinstance(count, int) or not 0 <= count <= 500:
        raise IntakeError("review queue candidate_count is invalid")
    items = value.get("items")
    if not isinstance(items, list) or len(items) > 550:
        raise IntakeError("review queue items are invalid")
    item_fields = {
        "type",
        "candidate_id",
        "provider",
        "status",
        "title",
        "canonical_url",
        "asset_recommendation",
        "risk_flags",
        "evidence_refs",
    }
    candidate_ids = set()
    health_items = 0
    for item in items:
        if not isinstance(item, dict) or set(item) != item_fields or item.get("type") not in {"candidate-review", "provider-health"}:
            raise IntakeError("review queue item is invalid")
        provider = item.get("provider")
        if provider not in PROVIDERS or item.get("asset_recommendation") not in ASSET_RECOMMENDATIONS:
            raise IntakeError("review queue item provider or recommendation is invalid")
        _clean_text(item.get("title"), "review queue title", 300, allow_empty=False)
        risks = item.get("risk_flags")
        refs = item.get("evidence_refs")
        if not isinstance(risks, list) or len(risks) > 50 or len(risks) != len(set(risks)):
            raise IntakeError("review queue risk flags are invalid")
        if not all(isinstance(risk, str) and RISK_RE.fullmatch(risk) for risk in risks):
            raise IntakeError("review queue risk flags contain an invalid code")
        if not isinstance(refs, list) or not refs or len(refs) > 50 or len(refs) != len(set(refs)):
            raise IntakeError("review queue evidence refs are invalid")
        for ref in refs:
            if (
                not isinstance(ref, str)
                or _clean_text(ref, "review queue evidence ref", 500, allow_empty=False) != ref
                or SECRET_REF_RE.search(ref)
                or ref.startswith("/")
                or ".." in Path(ref).parts
            ):
                raise IntakeError("review queue evidence refs are unsafe")
        if item["type"] == "candidate-review":
            candidate_id = str(item.get("candidate_id", ""))
            if not CANDIDATE_ID_RE.fullmatch(candidate_id) or candidate_id in candidate_ids:
                raise IntakeError("review queue candidate item id is invalid or duplicated")
            candidate_ids.add(candidate_id)
            if item.get("status") != "pending-owner-review":
                raise IntakeError("review queue candidate status is invalid")
            provider_policy = _provider_policy(policy, str(provider))
            canonical = _canonical_url(
                item.get("canonical_url"),
                provider_policy["allowed_hosts"],
                repository=provider in NETWORK_PROVIDERS,
            )
            if canonical != item.get("canonical_url"):
                raise IntakeError("review queue candidate URL is not canonical")
        else:
            health_items += 1
            if (
                item.get("candidate_id") is not None
                or item.get("canonical_url") is not None
                or item.get("status") not in {"degraded-empty", "not-run-network-disabled", "failed"}
                or item.get("asset_recommendation") != "observe"
                or item.get("risk_flags") != ["provider-degraded"]
            ):
                raise IntakeError("review queue provider-health item is invalid")
    if len(candidate_ids) != count:
        raise IntakeError("review queue candidate_count is inconsistent with its items")
    expected_status = "degraded" if health_items else "review-required"
    if value["status"] != expected_status:
        raise IntakeError("review queue status is inconsistent with provider health")
    return value


def _queue_markdown(queue: Mapping[str, Any]) -> str:
    lines = [
        "# External Practice Review Queue",
        "",
        "> mode: report-only",
        "> status: {}".format(queue["status"]),
        "> as_of: {}".format(queue["as_of"]),
        "",
        "| type | provider | status | candidate | recommendation |",
        "|---|---|---|---|---|",
    ]
    for item in queue["items"]:
        lines.append(
            "| {} | {} | {} | {} | {} |".format(
                item["type"],
                item["provider"],
                item["status"],
                item.get("candidate_id") or "-",
                item["asset_recommendation"],
            )
        )
    lines.extend(["", "No item is approved, implemented, published, or promoted by this queue.", ""])
    return "\n".join(lines)


def _cycle_markdown(evidence: Mapping[str, Any], queue: Mapping[str, Any]) -> str:
    lines = [
        "# External Practice Intake Cycle",
        "",
        "> mode: report-only",
        "> status: {}".format(evidence["status"]),
        "> as_of: {}".format(evidence["as_of"]),
        "> candidates: {}".format(evidence["candidate_count"]),
        "> deduplicated: {}".format(evidence["deduplicated_count"]),
        "",
        "| job | provider | mode | status | candidates |",
        "|---|---|---|---|---:|",
    ]
    for job in evidence["jobs"]:
        lines.append("| {} | {} | {} | {} | {} |".format(job["id"], job["provider"], job["mode"], job["status"], job["candidate_count"]))
    lines.extend([
        "",
        "## Boundaries",
        "",
        "- queue_status: `{}`".format(queue["status"]),
        "- external code executed: `false`",
        "- repository/ADK/live runtime modified: `false`",
        "- decision or publication generated: `false`",
        "",
    ])
    return "\n".join(lines)


def _as_of(value: Optional[str]) -> str:
    return _parse_date(value or date.today().isoformat(), "as_of")


def _collect_args_to_job(args: argparse.Namespace) -> Mapping[str, Any]:
    if isinstance(args.max_results, bool) or not isinstance(args.max_results, int) or not 1 <= args.max_results <= 100:
        raise IntakeError("--max-results must be in 1..100")
    if args.provider in NETWORK_PROVIDERS:
        _clean_text(args.query, "provider query", 500, allow_empty=False)
        if args.input or args.url:
            raise IntakeError("forge collection does not consume --input or --url")
        if args.fixture and args.allow_network:
            raise IntakeError("fixture collection and --allow-network are mutually exclusive")
    elif args.provider in OFFICIAL_PROVIDERS or args.provider == "wechat":
        _clean_text(args.input, "provider input", 500, allow_empty=False)
        if args.query or args.fixture or args.url or args.allow_network:
            raise IntakeError("local governed providers only consume --input")
    elif args.provider == "manual" and not args.input and not args.url:
        raise IntakeError("manual collection requires --input or --url")
    elif args.provider == "manual" and (args.query or args.fixture or args.allow_network):
        raise IntakeError("manual collection does not consume query, fixture, or network flags")
    job: Dict[str, Any] = {
        "id": "{}-collect".format(args.provider),
        "provider": args.provider,
        "enabled": True,
        "max_results": args.max_results,
    }
    if args.query:
        job["query"] = args.query
    if args.input:
        job["input"] = args.input
    if args.fixture:
        job["fixture"] = args.fixture
    if args.url:
        job["urls"] = list(args.url)
    return job


def _cmd_collect(args: argparse.Namespace, root: Path, policy: Mapping[str, Any], policy_path: Path) -> int:
    as_of = _as_of(args.as_of)
    job = _collect_args_to_job(args)
    candidates, job_record = _collect_job(root, policy, job, as_of, args.allow_network)
    candidates, deduplicated = _deduplicate(candidates, policy)
    job_record["deduplicated_count"] = deduplicated
    status = "degraded" if job_record["status"] != "complete" else "complete"
    evidence = _evidence(as_of, status, candidates, deduplicated, [job_record])
    _validate_evidence(evidence)
    out = _resolve_path(root, args.out, "candidate output")
    evidence_out = _resolve_path(root, args.evidence_out, "evidence output")
    inputs = [policy_path]
    for field in (args.input, args.fixture):
        if field:
            inputs.append(_resolve_path(root, field, "collection input"))
    _transactional_write(
        [(out, _jsonl_bytes(candidates)), (evidence_out, _json_bytes(evidence))],
        inputs,
    )
    label = "PASS" if job_record["status"] == "complete" else "DEGRADED"
    print("[{}] provider={} status={} candidates={} ledger={}".format(label, args.provider, job_record["status"], len(candidates), out))
    return 0 if job_record["status"] == "complete" else 2


def _cmd_check(args: argparse.Namespace, root: Path, policy: Mapping[str, Any]) -> int:
    path = _resolve_path(root, args.input, "check input")
    limit = policy["limits"]["response_bytes"]
    if args.kind == "policy":
        _validate_policy(_load_json(path, limit, "source policy"), root)
        count = 1
    elif args.kind == "candidate":
        rows = _load_jsonl(path, limit, "candidate ledger")
        for row in rows:
            _validate_candidate(row, policy)
        if len({row["candidate_id"] for row in rows}) != len(rows):
            raise IntakeError("candidate ledger contains duplicate candidate_id values")
        count = len(rows)
    elif args.kind == "decision":
        rows = _load_jsonl(path, limit, "decision ledger")
        if not rows:
            raise IntakeError("decision ledger must not be empty")
        for row in rows:
            _validate_decision(row)
        if len({row["candidate_id"] for row in rows}) != len(rows):
            raise IntakeError("decision ledger contains duplicate candidate decisions")
        count = len(rows)
    elif args.kind == "plan":
        _validate_plan(_load_json(path, limit, "cycle plan"))
        count = 1
    elif args.kind == "evidence":
        _validate_evidence(_load_json(path, limit, "cycle evidence"))
        count = 1
    else:
        _validate_queue(_load_json(path, limit, "review queue"), policy)
        count = 1
    print("[PASS] kind={} records={} input={}".format(args.kind, count, path))
    return 0


def _cmd_queue(args: argparse.Namespace, root: Path, policy: Mapping[str, Any]) -> int:
    ledger = _resolve_path(root, args.ledger, "candidate ledger")
    candidates = _load_jsonl(ledger, policy["limits"]["response_bytes"], "candidate ledger")
    for row in candidates:
        _validate_candidate(row, policy)
    evidence_path = _resolve_path(root, args.evidence, "cycle evidence")
    evidence = _validate_evidence(_load_json(evidence_path, policy["limits"]["response_bytes"], "cycle evidence"))
    ledger_sha256 = _sha256_bytes(_jsonl_bytes(candidates))
    if evidence["ledger_sha256"] != ledger_sha256 or evidence["candidate_count"] != len(candidates):
        raise IntakeError("cycle evidence does not bind the supplied candidate ledger")
    if args.as_of and _as_of(args.as_of) != evidence["as_of"]:
        raise IntakeError("queue as_of must match its cycle evidence")
    queue = _queue(str(evidence["as_of"]), candidates, list(evidence["jobs"]))
    _validate_queue(queue, policy)
    out_json = _resolve_path(root, args.out_json, "queue JSON output")
    out_md = _resolve_path(root, args.out_md, "queue Markdown output")
    inputs = [ledger, evidence_path]
    _transactional_write(
        [(out_json, _json_bytes(queue)), (out_md, _queue_markdown(queue).encode("utf-8"))],
        inputs,
    )
    print("[PASS] queue status={} items={} output={}".format(queue["status"], len(queue["items"]), out_json))
    return 0


def _cmd_cycle(args: argparse.Namespace, root: Path, policy: Mapping[str, Any], policy_path: Path) -> int:
    plan_path = _resolve_path(root, args.plan, "cycle plan")
    plan = _validate_plan(_load_json(plan_path, policy["limits"]["response_bytes"], "cycle plan"))
    as_of = _as_of(args.as_of or plan.get("as_of"))
    all_candidates: List[Mapping[str, Any]] = []
    jobs: List[Mapping[str, Any]] = []
    failed = False
    for job in plan["jobs"]:
        if not job["enabled"]:
            continue
        try:
            candidates, record = _collect_job(root, policy, job, as_of, args.allow_network)
            all_candidates.extend(candidates)
            jobs.append(record)
        except IntakeError:
            failed = True
            jobs.append(
                _job_record(
                    str(job["id"]),
                    str(job["provider"]),
                    "not-run",
                    "failed",
                    0,
                    0,
                    error_code="intake-job-failed",
                )
            )
    if len(all_candidates) > policy["limits"]["candidates_per_cycle"]:
        raise IntakeError("cycle candidate count exceeds the configured budget")
    candidates, deduplicated = _deduplicate(all_candidates, policy)
    degraded = any(job["status"] in {"degraded-empty", "not-run-network-disabled"} for job in jobs)
    if failed:
        status = "failed"
    elif degraded:
        status = "degraded"
    else:
        status = "complete"
    evidence = _evidence(as_of, status, candidates, deduplicated, jobs)
    queue = _queue(as_of, candidates, jobs)
    _validate_evidence(evidence)
    _validate_queue(queue, policy)
    out_ledger = _resolve_path(root, args.out_ledger, "cycle ledger output")
    out_queue = _resolve_path(root, args.out_queue, "cycle queue output")
    out_evidence = _resolve_path(root, args.out_evidence, "cycle evidence output")
    out_md = _resolve_path(root, args.out_md, "cycle Markdown output")
    inputs = [policy_path, plan_path]
    for job in plan["jobs"]:
        for field in ("input", "fixture"):
            if job.get(field):
                inputs.append(_resolve_path(root, str(job[field]), "cycle input"))
    _transactional_write(
        [
            (out_ledger, _jsonl_bytes(candidates)),
            (out_queue, _json_bytes(queue)),
            (out_evidence, _json_bytes(evidence)),
            (out_md, _cycle_markdown(evidence, queue).encode("utf-8")),
        ],
        inputs,
    )
    print("[PASS] cycle status={} candidates={} deduplicated={} evidence={}".format(status, len(candidates), deduplicated, out_evidence))
    if failed or (degraded and not plan["allow_degraded"]):
        return 2
    return 0


def _cmd_recommend(args: argparse.Namespace, root: Path, policy: Mapping[str, Any]) -> int:
    ledger = _resolve_path(root, args.ledger, "candidate ledger")
    candidates = _load_jsonl(ledger, policy["limits"]["response_bytes"], "candidate ledger")
    recommendations = []
    for candidate in candidates:
        _validate_candidate(candidate, policy)
        recommendations.append({
            "candidate_id": candidate["candidate_id"],
            "provider": candidate["provider"],
            "recommendation": candidate["asset_recommendation"],
            "status": "review-required",
            "reason": "heuristic shape only; owner decision and ADK change artifact remain mandatory",
        })
    output = {
        "schema": RECOMMENDATION_SCHEMA,
        "mode": "report-only",
        "candidate_count": len(recommendations),
        "recommendations": recommendations,
        "auto_actions": [],
    }
    lines = [
        "# External Practice Asset Recommendations",
        "",
        "> report-only; recommendations are not adoption decisions",
        "",
        "| candidate | provider | recommendation | status |",
        "|---|---|---|---|",
    ]
    for item in recommendations:
        lines.append("| {} | {} | {} | {} |".format(item["candidate_id"], item["provider"], item["recommendation"], item["status"]))
    lines.append("")
    out_json = _resolve_path(root, args.out_json, "recommendation JSON output")
    out_md = _resolve_path(root, args.out_md, "recommendation Markdown output")
    _transactional_write(
        [(out_json, _json_bytes(output)), (out_md, "\n".join(lines).encode("utf-8"))],
        [ledger],
    )
    print("[PASS] recommendations={} output={}".format(len(recommendations), out_json))
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Unified report-only external practice intake")
    parser.add_argument("--root", required=True, help="llm_agent repository root")
    parser.add_argument("--policy", help="source policy JSON; defaults to manifests/external_practice_sources.json")
    subparsers = parser.add_subparsers(dest="command", required=True)

    collect = subparsers.add_parser("collect", help="collect one provider into a v1 candidate ledger")
    collect.add_argument("--provider", required=True, choices=sorted(PROVIDERS))
    collect.add_argument("--query")
    collect.add_argument("--input")
    collect.add_argument("--fixture")
    collect.add_argument("--url", action="append", default=[])
    collect.add_argument("--max-results", type=int, default=100)
    collect.add_argument("--as-of")
    collect.add_argument("--allow-network", action="store_true")
    collect.add_argument("--out", required=True)
    collect.add_argument("--evidence-out", required=True)

    check = subparsers.add_parser("check", help="validate a governed v1 contract")
    check.add_argument("--kind", required=True, choices=["policy", "candidate", "decision", "plan", "evidence", "queue"])
    check.add_argument("--input", required=True)

    queue = subparsers.add_parser("queue", help="generate an owner review queue")
    queue.add_argument("--ledger", required=True)
    queue.add_argument("--evidence", required=True)
    queue.add_argument("--as-of")
    queue.add_argument("--out-json", required=True)
    queue.add_argument("--out-md", required=True)

    cycle = subparsers.add_parser("cycle", help="run an explicit report-only multi-provider plan")
    cycle.add_argument("--plan", required=True)
    cycle.add_argument("--as-of")
    cycle.add_argument("--allow-network", action="store_true")
    cycle.add_argument("--out-ledger", required=True)
    cycle.add_argument("--out-queue", required=True)
    cycle.add_argument("--out-evidence", required=True)
    cycle.add_argument("--out-md", required=True)

    recommend = subparsers.add_parser("recommend", help="render non-binding asset-shape recommendations")
    recommend.add_argument("--ledger", required=True)
    recommend.add_argument("--out-json", required=True)
    recommend.add_argument("--out-md", required=True)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    if not root.is_dir():
        print("[FAIL] repository root is missing", file=sys.stderr)
        return 2
    try:
        policy, policy_path = _load_policy(root, args.policy)
        if args.command == "collect":
            return _cmd_collect(args, root, policy, policy_path)
        if args.command == "check":
            return _cmd_check(args, root, policy)
        if args.command == "queue":
            return _cmd_queue(args, root, policy)
        if args.command == "cycle":
            return _cmd_cycle(args, root, policy, policy_path)
        return _cmd_recommend(args, root, policy)
    except IntakeError as exc:
        message = str(exc)
        if SECRET_REF_RE.search(message):
            message = "sensitive field rejected"
        print("[FAIL] {}".format(message), file=sys.stderr)
        return 2
    except OSError:
        print("[FAIL] local filesystem operation failed", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
