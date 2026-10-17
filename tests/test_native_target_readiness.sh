#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

python3 -m tools.control_plane.native_target_readiness --root . --summary-json >"$TMP"
python3 - "$TMP" <<'PY'
import json
import sys
from pathlib import Path

value=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert value["schema"]=="llm-agent-native-target-readiness/v1", value
assert value["status"]=="pass", value
assert value["software_ready"] is True, value
assert all(value["software_surfaces"].values()), value
assert value["release_authorized"] is False, value
assert value["native_verified"] == bool(value["native_verified_targets"]), value
assert set(value["targets"]) == {"claude-code", "opencode"}, value

for target,item in value["targets"].items():
    assert item["conformance_level"] in {"static","runtime"}, (target,item)
    assert isinstance(item["evidence_count"], int) and item["evidence_count"] >= 0, (target,item)
    if item["native_verified"]:
        assert item["conformance_level"]=="runtime", (target,item)
        assert item["certification"]=="conformance-certified", (target,item)
        assert item["native_runtime_smoke"]=="pass", (target,item)
        assert item["runtime_identity_pinned"] is True, (target,item)
        assert item["evidence_count"] > 0, (target,item)
        assert item["evidence_paths_valid"] is True, (target,item)
        assert item["trust_enabled"] is True, (target,item)
        assert item["bound_registry_authorities"], (target,item)
        assert item["production_loader_verified"] is True, (target,item)

if value["native_verified"]:
    assert value["terminal_status"]=="ready", value
    assert value["blockers"] == [], value
else:
    assert value["terminal_status"]=="blocked-external-evidence", value
    assert any("version-pinned-authenticated-native-campaign" in item for item in value["blockers"]), value
    assert any("signed-receipt-managed-registry-production-loader" in item for item in value["blockers"]), value

boundary=value["authority_boundary"]
assert boundary["source_layout_is_native_evidence"] is False, boundary
assert boundary["synthetic_campaign_is_native_evidence"] is False, boundary
assert boundary["managed_trust_without_receipt_is_native_evidence"] is False, boundary
assert boundary["requires_real_version_pinned_native_pass"] is True, boundary
PY

if python3 -m tools.control_plane.native_target_readiness --root . --require-native --summary-json >/dev/null; then
  python3 - "$TMP" <<'PY'
import json,sys
v=json.load(open(sys.argv[1],encoding="utf-8"))
assert v["native_verified"] is True and v["terminal_status"]=="ready", v
PY
else
  rc=$?
  test "$rc" -eq 2
  python3 - "$TMP" <<'PY'
import json,sys
v=json.load(open(sys.argv[1],encoding="utf-8"))
assert v["native_verified"] is False and v["terminal_status"]=="blocked-external-evidence", v
PY
fi

python3 -m tools.control_plane.cli native-readiness --root . --summary-json   | python3 -c 'import json,sys; v=json.load(sys.stdin); assert v["status"]=="pass", v'

# Both G21 and G22 must reuse the one bounded, strict JSON authority.
# Permissive JSON would let a second key silently override the field reviewed by
# a human, or make a non-finite observation appear numeric.
python3 - <<'PY'
import hashlib
import inspect
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.control_plane import effect_readiness, native_target_readiness

for module in (effect_readiness, native_target_readiness):
    with TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / "evidence.json"
        source.write_text('{"status":"ok","nested":{"count":1}}', encoding="utf-8")
        assert module._load_object(source, "fixture")["nested"]["count"] == 1

        invalid_documents = (
            '{"status":"pass","status":"blocked"}',    # duplicate top-level key
            '{"nested":{"pass":true,"pass":false}}', # duplicate nested key
            '{"observation":NaN}',
            '{"observation":Infinity}',
            '{"observation":1e9999}',                 # finite JSON syntax, infinity as float
            '[{"schema":"unexpected-list"}]',        # object contract
            '{"depth":' + '[' * 70 + '0' + ']' * 70 + '}', # nesting budget
        )
        for document in invalid_documents:
            source.write_text(document, encoding="utf-8")
            try:
                module._load_object(source, "fixture")
            except ValueError:
                pass
            else:
                raise AssertionError((module.__name__, "unsafe JSON accepted", document[:60]))

        source.write_text('{"status":"pass"}', encoding="utf-8")
        if module is effect_readiness:
            assert module._sha256_file(source) == hashlib.sha256(source.read_bytes()).hexdigest()
        link = root / "symlink.json"
        link.symlink_to(source)
        try:
            module._load_object(link, "fixture")
        except ValueError:
            pass
        else:
            raise AssertionError((module.__name__, "symlink accepted"))
        if module is effect_readiness:
            try:
                module._sha256_file(link)
            except ValueError:
                pass
            else:
                raise AssertionError("effect evidence digest reader accepted a symlink")

        previous_limit = module._MAX_JSON_BYTES
        try:
            module._MAX_JSON_BYTES = 8
            try:
                module._load_object(source, "fixture")
            except ValueError:
                pass
            else:
                raise AssertionError((module.__name__, "oversized input accepted"))
            if module is effect_readiness:
                try:
                    module._sha256_file(source)
                except ValueError:
                    pass
                else:
                    raise AssertionError("effect evidence digest reader accepted oversized input")
        finally:
            module._MAX_JSON_BYTES = previous_limit

validation_source = inspect.getsource(effect_readiness._validate_evidence_entry)
assert validation_source.index('campaign = _load_object(') < validation_source.index('    _schema_validate(')
assert 'read_bytes(' in inspect.getsource(effect_readiness._sha256_file)
print("[PASS] G21/G22 evidence parsing and digest inputs reject ambiguity, symlinks and resource amplification")
PY

echo '[PASS] native target readiness separates software readiness from real native evidence'
