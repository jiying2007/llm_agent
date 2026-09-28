from __future__ import annotations

import copy
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.codex_assets.reference_remote_audit import RemoteAuditError, audit


class ReferenceRemoteAuditTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="reference-remote-audit-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        subprocess.run(["git", "init", "--template=", "-q", str(self.root)], check=True)
        (self.root / "manifests").mkdir()
        (self.root / "subrepos").mkdir()
        self.pin = "a" * 40
        self.remote = "b" * 40
        self.manifest = {
            "schema": "llm-agent-reference-pins/v2",
            "policy": {
                "tracked_gitlink_forbidden": True,
                "submodule_entry_forbidden": True,
                "runtime_enablement": False,
                "pin_is_evidence_not_source": True,
                "materialization_root": "user-cache-only",
                "materialization_requires_explicit_id": True,
            },
            "pins": [{
                "id": "example", "kind": "reference-repo", "path": "example",
                "url": "https://github.com/example/project", "commit": self.pin,
            }],
        }
        self.write_manifest()
        (self.root / "subrepos/registry.csv").write_text(
            "repo,branch,enabled,status\nexample,main,yes,active\n", encoding="utf-8"
        )

    def write_manifest(self) -> None:
        (self.root / "manifests/reference_pins.json").write_text(
            json.dumps(self.manifest), encoding="utf-8"
        )

    def test_offline_does_not_inspect_remote_or_mutate_workspace(self) -> None:
        before = subprocess.check_output(["git", "-C", str(self.root), "status", "--porcelain"])
        with patch("tools.codex_assets.reference_remote_audit.run_bounded") as remote, patch.dict(
            os.environ, {"XDG_CACHE_HOME": str(self.root)}
        ):
            result = audit(self.root)
        remote.assert_not_called()
        after = subprocess.check_output(["git", "-C", str(self.root), "status", "--porcelain"])
        self.assertEqual(before, after)
        self.assertEqual(result["status"], "not-run-network-disabled")
        self.assertFalse(result["network_requested"])
        self.assertFalse(result["mutation_performed"])
        self.assertFalse(result["ancestry_checked"])
        self.assertEqual(result["repositories"][0]["remote_head"], None)

    def test_live_same_and_different_are_not_called_fast_forward(self) -> None:
        ref = b"\trefs/heads/main\n"
        with patch("tools.codex_assets.reference_remote_audit.run_bounded") as remote:
            remote.return_value = subprocess.CompletedProcess([], 0, self.pin.encode() + ref, b"")
            same = audit(self.root, allow_network=True)
            remote.return_value = subprocess.CompletedProcess([], 0, self.remote.encode() + ref, b"")
            changed = audit(self.root, allow_network=True)
        self.assertEqual(same["status"], "current")
        self.assertEqual(same["repositories"][0]["relation"], "same")
        self.assertEqual(changed["status"], "review-required")
        self.assertEqual(changed["repositories"][0]["relation"], "different")
        self.assertFalse(changed["repositories"][0]["ancestry_checked"])
        self.assertEqual(changed["counts"]["different"], 1)
        command = remote.call_args.args[0]
        self.assertIn("credential.helper=", command)
        self.assertIn("http.followRedirects=false", command)
        self.assertNotIn("-C", command)
        self.assertEqual(remote.call_args.kwargs["cwd"], Path("/"))

    def test_empty_remote_and_git_failure_are_degraded(self) -> None:
        with patch("tools.codex_assets.reference_remote_audit.run_bounded") as remote:
            remote.return_value = subprocess.CompletedProcess([], 0, b"", b"")
            empty = audit(self.root, allow_network=True)
            remote.return_value = subprocess.CompletedProcess([], 128, b"", b"authentication failed")
            failed = audit(self.root, allow_network=True)
        for result in (empty, failed):
            self.assertEqual(result["status"], "degraded")
            self.assertEqual(result["repositories"][0]["relation"], "unavailable")
            self.assertEqual(result["counts"]["unavailable"], 1)
            self.assertNotIn("authentication failed", json.dumps(result))

    def test_unapproved_host_and_missing_registry_row_fail_before_network(self) -> None:
        altered = copy.deepcopy(self.manifest)
        altered["pins"][0]["url"] = "https://not-approved.example/project"
        self.manifest = altered
        self.write_manifest()
        with patch("tools.codex_assets.reference_remote_audit.run_bounded") as remote:
            with self.assertRaises(RemoteAuditError):
                audit(self.root, allow_network=True)
        remote.assert_not_called()
        self.manifest["pins"][0]["url"] = "https://github.com/example/project"
        self.write_manifest()
        (self.root / "subrepos/registry.csv").write_text(
            "repo,branch,enabled,status\nexample,main,no,disabled\n", encoding="utf-8"
        )
        with self.assertRaises(RemoteAuditError):
            audit(self.root)

    def test_exact_pin_selection_rejects_unknown_id(self) -> None:
        with self.assertRaises(RemoteAuditError):
            audit(self.root, repo_ids=["another-repo"])

    def test_pin_drift_during_remote_call_is_rejected(self) -> None:
        def mutate_source(*_args, **_kwargs):
            self.manifest["pins"][0]["commit"] = self.remote
            self.write_manifest()
            return subprocess.CompletedProcess([], 0, self.remote.encode() + b"\trefs/heads/main\n", b"")

        with patch("tools.codex_assets.reference_remote_audit.run_bounded", side_effect=mutate_source):
            with self.assertRaisesRegex(RemoteAuditError, "changed during audit"):
                audit(self.root, allow_network=True)

    def test_symlinked_registry_parent_is_rejected(self) -> None:
        (self.root / "subrepos").rename(self.root / "actual-subrepos")
        (self.root / "subrepos").symlink_to(self.root / "actual-subrepos", target_is_directory=True)
        with self.assertRaisesRegex(RemoteAuditError, "linked"):
            audit(self.root)


if __name__ == "__main__":
    unittest.main()
