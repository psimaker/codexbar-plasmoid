import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile


REPOSITORY = pathlib.Path(__file__).resolve().parents[1]
PLUGIN_ID = "com.github.psimaker.codexbar"
VERSION = "0.3.1"
ARTIFACT_NAME = f"{PLUGIN_ID}-{VERSION}.plasmoid"


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = pathlib.Path(self.temp_dir.name) / "repository"
        shutil.copytree(
            REPOSITORY,
            self.repo,
            ignore=shutil.ignore_patterns("dist", "__pycache__", "*.pyc"),
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def run_command(self, *command, check=True):
        return subprocess.run(
            command,
            cwd=self.repo,
            check=check,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def build(self, ref="HEAD", *options, check=True):
        return self.run_command(
            "bash",
            "scripts/build-plasmoid.sh",
            *options,
            ref,
            check=check,
        )

    @property
    def artifact(self):
        return self.repo / "dist" / ARTIFACT_NAME

    @property
    def checksum(self):
        return self.repo / "dist" / f"{ARTIFACT_NAME}.sha256"

    def test_current_metadata_and_package_root(self):
        metadata = json.loads((self.repo / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(metadata["KPackageStructure"], "Plasma/Applet")
        self.assertEqual(metadata["KPlugin"]["Id"], PLUGIN_ID)
        self.assertEqual(metadata["KPlugin"]["Version"], VERSION)
        self.assertGreaterEqual(
            tuple(map(int, metadata["X-Plasma-API-Minimum-Version"].split("."))),
            (6, 0),
        )

        self.build()
        with zipfile.ZipFile(self.artifact) as archive:
            names = archive.namelist()
        self.assertIn("metadata.json", names)
        self.assertIn("contents/ui/main.qml", names)
        self.assertIn("LICENSE", names)
        self.assertTrue(all(name == "metadata.json" or name == "LICENSE"
                            or name.startswith("contents/") for name in names))
        self.assertFalse(any(name.startswith("codexbar-plasmoid/") for name in names))

    def test_tag_package_contains_exactly_tag_files(self):
        self.build("v0.3.1")
        tracked = self.run_command(
            "git", "ls-tree", "-r", "--name-only", "v0.3.1"
        ).stdout.splitlines()
        expected = sorted(
            name
            for name in tracked
            if name in {"metadata.json", "LICENSE"} or name.startswith("contents/")
        )

        with zipfile.ZipFile(self.artifact) as archive:
            self.assertEqual(sorted(archive.namelist()), expected)
            for name in expected:
                tagged = self.run_command("git", "show", f"v0.3.1:{name}").stdout
                self.assertEqual(archive.read(name), tagged.encode())

    def test_checksum_matches_archive(self):
        self.build()
        checksum_fields = self.checksum.read_text(encoding="utf-8").strip().split()
        self.assertEqual(checksum_fields[1], ARTIFACT_NAME)
        digest = hashlib.sha256(self.artifact.read_bytes()).hexdigest()
        self.assertEqual(checksum_fields[0], digest)

    def test_invalid_ref_fails(self):
        result = self.build("refs/does/not/exist", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not resolve to a commit", result.stderr)

    def test_existing_artifact_is_not_overwritten_without_force(self):
        self.build()
        original_digest = hashlib.sha256(self.artifact.read_bytes()).hexdigest()
        result = self.build(check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("artifact already exists", result.stderr)
        self.assertEqual(original_digest, hashlib.sha256(self.artifact.read_bytes()).hexdigest())

    def test_force_replaces_existing_artifacts(self):
        self.build()
        self.artifact.write_bytes(b"not a zip file")
        self.checksum.write_text("invalid\n", encoding="utf-8")
        self.build("HEAD", "--force")
        with zipfile.ZipFile(self.artifact) as archive:
            self.assertIsNone(archive.testzip())

    def test_release_tag_must_match_metadata_version(self):
        mismatch = self.run_command(
            "python3",
            "scripts/validate-release-version.py",
            "v0.3.2",
            check=False,
        )
        self.assertNotEqual(mismatch.returncode, 0)
        self.assertIn("does not match release tag", mismatch.stderr)

        match = self.run_command(
            "python3", "scripts/validate-release-version.py", "v0.3.1"
        )
        self.assertIn("matches metadata version 0.3.1", match.stdout)

    def test_release_tag_must_be_semver(self):
        result = self.run_command(
            "python3",
            "scripts/validate-release-version.py",
            "release-0.3.1",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("v<semver>", result.stderr)


if __name__ == "__main__":
    unittest.main()
