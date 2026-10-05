from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

PREREG_CERTIFICATE_IDENTITY = (
    "https://github.com/jiying2007/llm_agent/"
    ".github/workflows/effect-preregister.yml@refs/heads/main"
)
PREREG_CERTIFICATE_OIDC_ISSUER = "https://token.actions.githubusercontent.com"


def verify_effect_preregistration(
    adk: Path,
    campaign_path: Path,
    package_path: Path,
    bundle_path: Path,
    bundle_sha256: str,
    authority_registry_path: Path,
    receipts_path: Path,
    bundle_root: Path,
) -> dict[str, Any]:
    """Verify a signed content-addressed effect package predates all managed observations."""
    root = Path(__file__).resolve().parents[2]
    code = r'''
import hashlib,json,sys
from datetime import datetime,timezone
from pathlib import Path
from agent_dev_kit.model import canonical_json_bytes
from agent_dev_kit.sigstore_blob import verify_sigstore_blob
from agent_dev_kit.strict_json import read as read_json
from tools.control_plane.effect_preregistration_package import validate_package

def obj(path,label):
    value=read_json(Path(path))
    if not isinstance(value,dict):
        raise SystemExit(label+"-not-object")
    return value

def stamp(value,label):
    try:
        parsed=datetime.fromisoformat(str(value).replace("Z","+00:00"))
    except ValueError:
        raise SystemExit(label+"-invalid")
    if parsed.tzinfo is None:
        raise SystemExit(label+"-timezone-missing")
    return parsed.astimezone(timezone.utc)

def tlog_time(path,label):
    value=obj(path,label)
    material=value.get("verificationMaterial")
    entries=material.get("tlogEntries") if isinstance(material,dict) else None
    if not isinstance(entries,list) or len(entries)!=1 or not isinstance(entries[0],dict):
        raise SystemExit(label+"-requires-one-tlog-entry")
    raw=entries[0].get("integratedTime")
    if not isinstance(raw,str) or not raw.isdigit():
        raise SystemExit(label+"-integrated-time-invalid")
    return datetime.fromtimestamp(int(raw),tz=timezone.utc)

adk=Path(sys.argv[1]).resolve()
campaign_path=Path(sys.argv[2]).resolve()
package_path=Path(sys.argv[3]).resolve()
prereg_bundle=Path(sys.argv[4]).resolve()
expected_prereg_bundle_sha=sys.argv[5]
registry_path=Path(sys.argv[6]).resolve()
receipts_path=Path(sys.argv[7]).resolve()
bundle_root=Path(sys.argv[8]).resolve()
cert_identity=sys.argv[9]
cert_issuer=sys.argv[10]

canonical_package,package_summary=validate_package(adk,package_path)
package=obj(package_path,"preregistration-package")
campaign=obj(campaign_path,"campaign")
plan=campaign.get("plan")
if not isinstance(plan,dict):
    raise SystemExit("campaign-plan-invalid")
campaign_observed_times=[]
trials=campaign.get("trials")
if not isinstance(trials,list) or not trials:
    raise SystemExit("campaign-trials-invalid")
for trial in trials:
    if not isinstance(trial,dict):
        raise SystemExit("campaign-trial-invalid")
    for side in ("baseline","candidate"):
        bindings=trial.get(side)
        if not isinstance(bindings,list) or not bindings:
            raise SystemExit("campaign-bindings-invalid")
        for binding in bindings:
            run=binding.get("run") if isinstance(binding,dict) else None
            if not isinstance(run,dict):
                raise SystemExit("campaign-run-invalid")
            campaign_observed_times.append(stamp(run.get("observed_at"),"campaign-run-observed-at"))
if canonical_json_bytes(plan)!=canonical_json_bytes(package.get("plan")):
    raise SystemExit("preregistration-package-plan-differs-from-campaign-plan")
if hashlib.sha256(prereg_bundle.read_bytes()).hexdigest()!=expected_prereg_bundle_sha:
    raise SystemExit("preregistration-bundle-digest-mismatch")

registry=obj(registry_path,"registry")
authorities=registry.get("authorities")
if not isinstance(authorities,dict):
    raise SystemExit("registry-authorities-invalid")
receipt_set=obj(receipts_path,"receipt-set")
receipts=receipt_set.get("receipts")
if not isinstance(receipts,list) or not receipts:
    raise SystemExit("receipt-population-invalid")

verifier_configs=set()
observed_times=[]
signature_times=[]
for receipt in receipts:
    if not isinstance(receipt,dict):
        raise SystemExit("receipt-invalid")
    observed_times.append(stamp(receipt.get("observed_at"),"receipt-observed-at"))
    attestation=receipt.get("authority_attestation")
    authority_id=attestation.get("authority_id") if isinstance(attestation,dict) else None
    authority=authorities.get(authority_id) if isinstance(authority_id,str) else None
    if not isinstance(authority,dict) or authority.get("enabled") is not True:
        raise SystemExit("receipt-authority-not-enabled")
    binary=authority.get("cosign_binary")
    binary_sha=authority.get("cosign_binary_sha256")
    if not isinstance(binary,str) or not isinstance(binary_sha,str):
        raise SystemExit("receipt-authority-verifier-pin-invalid")
    verifier_configs.add((binary,binary_sha))
    records=authority.get("receipts")
    record=records.get(receipt.get("receipt_id")) if isinstance(records,dict) else None
    if not isinstance(record,dict):
        raise SystemExit("receipt-registry-binding-missing")
    relative=record.get("bundle_path")
    if not isinstance(relative,str):
        raise SystemExit("receipt-bundle-path-invalid")
    signed_bundle=(bundle_root/relative).resolve()
    if not signed_bundle.is_relative_to(bundle_root):
        raise SystemExit("receipt-bundle-path-escapes-root")
    signature_times.append(tlog_time(signed_bundle,"receipt-signature-bundle"))

if len(verifier_configs)!=1:
    raise SystemExit("preregistration-requires-one-verifier-binary-pin")
cosign_binary,cosign_sha=next(iter(verifier_configs))
if not verify_sigstore_blob(
    canonical_package,
    bundle=prereg_bundle,
    expected_bundle_sha256=expected_prereg_bundle_sha,
    cosign_binary=cosign_binary,
    expected_cosign_sha256=cosign_sha,
    certificate_identity=cert_identity,
    certificate_oidc_issuer=cert_issuer,
    error_prefix="effect_preregistration",
):
    raise SystemExit("preregistration-signature-invalid")

registered=tlog_time(prereg_bundle,"preregistration-bundle")
if any(registered>=value for value in campaign_observed_times):
    raise SystemExit("preregistration-must-precede-all-campaign-runs")
if any(registered>=value for value in observed_times):
    raise SystemExit("preregistration-must-precede-all-observed-at-times")
if any(registered>=value for value in signature_times):
    raise SystemExit("preregistration-must-precede-all-receipt-signatures")

print(json.dumps({
    "status":"pass",
    "package_sha256":package_summary["package_sha256"],
    "plan_sha256":package_summary["plan_sha256"],
    "baseline_bundle_sha256":package_summary["bundle_sha256"]["baseline"],
    "candidate_bundle_sha256":package_summary["bundle_sha256"]["candidate"],
    "candidate_assets":package_summary["bundle_assets"]["candidate"],
    "bundle_sha256":expected_prereg_bundle_sha,
    "registered_at":registered.isoformat().replace("+00:00","Z"),
    "campaign_run_count":len(campaign_observed_times),
    "verified_receipt_count":len(receipts),
    "certificate_identity":cert_identity,
    "certificate_oidc_issuer":cert_issuer,
},sort_keys=True))
'''
    env = {
        "PYTHONPATH": os.pathsep.join([str(root), str(adk / "src")]),
        "PATH": os.environ.get("PATH", os.defpath),
        "LANG": "C.UTF-8",
        "LC_ALL": "C.UTF-8",
    }
    done = subprocess.run(
        [
            sys.executable,
            "-c",
            code,
            str(adk),
            str(campaign_path),
            str(package_path),
            str(bundle_path),
            bundle_sha256,
            str(authority_registry_path),
            str(receipts_path),
            str(bundle_root),
            PREREG_CERTIFICATE_IDENTITY,
            PREREG_CERTIFICATE_OIDC_ISSUER,
        ],
        cwd=root,
        env=env,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
        timeout=90,
    )
    if done.returncode:
        reason = (done.stderr or done.stdout).strip()[-1200:]
        raise ValueError(f"effect preregistration verification failed: {reason}")
    value = json.loads(done.stdout)
    if not isinstance(value, dict) or value.get("status") != "pass":
        raise ValueError("effect preregistration verification is invalid")
    return value
