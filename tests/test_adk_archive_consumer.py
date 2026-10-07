"""Consumer-facing hostile archive checks against the selected ADK source."""
import gzip
import hashlib
import io
import tempfile
import tarfile
import unittest
from pathlib import Path
from unittest import mock

from agent_dev_kit.distribution import archive_io
from agent_dev_kit.distribution.release_contract import validate_release_artifact
from agent_dev_kit.release import rehearse_release
from agent_dev_kit.model import ManifestError


class ADKArchiveConsumerTests(unittest.TestCase):
    def test_header_chain_fails_with_contract_error(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "agent-dev-kit-0.0.0.tar.gz"
            header = tarfile.TarInfo("hidden")
            header.type = tarfile.XHDTYPE
            path.write_bytes(gzip.compress(header.tobuf(format=tarfile.USTAR_FORMAT) * 1200))
            with self.assertRaises(archive_io.ArchiveInputError):
                validate_release_artifact(path)

    def test_member_budget_rejects_small_compressed_inventory(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "agent-dev-kit-0.0.0.tar.gz"
            with tarfile.open(path, "w:gz") as archive:
                for index in range(32):
                    archive.addfile(tarfile.TarInfo(str(index)), io.BytesIO())
            with mock.patch.object(archive_io, "MAX_MEMBERS", 8):
                with self.assertRaisesRegex(ValueError, "member budget"):
                    validate_release_artifact(path)

    def test_rehearsal_rejects_link_before_install_or_workspace(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "agent-dev-kit-0.0.0.tar.gz"
            with tarfile.open(path, "w:gz") as archive:
                archive.addfile(tarfile.TarInfo("empty"), io.BytesIO())
            path.with_name(path.name + ".sha256").write_text(
                hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name + "\n")
            link = root / "link.tar.gz"
            link.symlink_to(path)
            with mock.patch("agent_dev_kit.release.create_plan", side_effect=AssertionError("install")), \
                 mock.patch("agent_dev_kit.release.tempfile.mkdtemp", side_effect=AssertionError("workspace")):
                with self.assertRaisesRegex(ManifestError, "bounded regular"):
                    rehearse_release(link, path)


if __name__ == "__main__":
    unittest.main()
