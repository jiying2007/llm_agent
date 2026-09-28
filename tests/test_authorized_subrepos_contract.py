"""Only active pull-mode repositories belong in root Git submodules."""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check-authorized-subrepos.sh"


class AuthorizedSubreposContractTests(unittest.TestCase):
    def test_fetch_reference_is_cache_only_and_legacy_gitlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(["git", "-C", str(root), "init", "-q"], check=True)
            (root / "subrepos").mkdir()
            (root / "manifests").mkdir()
            gitlinks = root / "manifests/gitlinks.json"
            declared = {
                "schema": "llm-agent-gitlinks/v2",
                "gitlinks": [{"path": "agent-dev-kit", "kind": "managed-dependency", "required": True}],
            }
            gitlinks.write_text(json.dumps(declared), encoding="utf-8")
            (root / "subrepos/registry.csv").write_text(
                "repo,group,priority,sync_mode,branch,enabled,notes,status\n"
                "agent-dev-kit,adk-core,P0,pull,main,yes,fixture,active\n"
                "OpenSpec,workflow-core,P0,fetch,main,yes,fixture,active\n",
                encoding="utf-8",
            )
            (root / ".gitmodules").write_text(
                '[submodule "agent-dev-kit"]\n\tpath = agent-dev-kit\n\turl = https://example.invalid/adk.git\n',
                encoding="utf-8",
            )
            subprocess.run(
                ["git", "-C", str(root), "update-index", "--add", "--cacheinfo",
                 "160000," + "a" * 40 + ",agent-dev-kit"], check=True,
            )
            accepted = subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)
            self.assertEqual(accepted.returncode, 0, accepted.stderr)
            (root / ".gitmodules").write_text(
                (root / ".gitmodules").read_text(encoding="utf-8")
                + '[submodule "codex"]\n\tpath = codex\n\turl = https://example.invalid/codex.git\n',
                encoding="utf-8",
            )
            rejected = subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn("unauthorized submodule", rejected.stderr)
            declared["gitlinks"].append({
                "path": "codex", "kind": "frozen-evidence-dependency", "required": True,
            })
            gitlinks.write_text(json.dumps(declared), encoding="utf-8")
            subprocess.run(
                ["git", "-C", str(root), "update-index", "--add", "--cacheinfo",
                 "160000," + "b" * 40 + ",codex"], check=True,
            )
            frozen = subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)
            self.assertEqual(frozen.returncode, 0, frozen.stderr)
            (root / ".gitmodules").write_text(
                (root / ".gitmodules").read_text(encoding="utf-8")
                + '[submodule "rogue"]\n\tpath = rogue\n\turl = https://example.invalid/rogue.git\n',
                encoding="utf-8",
            )
            rogue = subprocess.run(["bash", str(SCRIPT), str(root)], capture_output=True, text=True)
            self.assertNotEqual(rogue.returncode, 0)
            self.assertIn("rogue", rogue.stderr)


if __name__ == "__main__":
    unittest.main()
