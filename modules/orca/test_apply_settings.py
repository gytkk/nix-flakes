#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SCRIPT = ROOT / "files" / "apply-settings.sh"
FILTER = ROOT / "files" / "merge-settings.jq"


def find_gnu_coreutils() -> Path:
    configured = os.environ.get("ORCA_TEST_COREUTILS_BIN")
    candidates = ([Path(configured)] if configured else []) + sorted(
        Path("/nix/store").glob("*-coreutils-*/bin"), reverse=True
    )
    system_chmod = shutil.which("chmod")
    if system_chmod:
        candidates.append(Path(system_chmod).parent)
    for candidate in candidates:
        result = subprocess.run(
            [candidate / "chmod", "--version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )
        if result.returncode == 0 and "GNU coreutils" in result.stdout:
            return candidate
    raise RuntimeError(
        "GNU coreutils is required; set ORCA_TEST_COREUTILS_BIN to its bin directory"
    )


def custom_theme(theme_id: str, color: str) -> dict[str, object]:
    return {
        "id": theme_id,
        "name": theme_id,
        "source": "ghostty",
        "mode": "dark",
        "terminal": {"background": color},
    }


class ApplySettingsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.coreutils_bin = find_gnu_coreutils()
        jq = shutil.which("jq")
        if jq is None:
            raise RuntimeError("jq is required for Orca integration tests")
        cls.jq_bin = Path(jq).parent

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        pgrep = self.bin / "pgrep"
        pgrep.write_text('#!/bin/sh\nexit "${PGREP_STATUS:-1}"\n')
        pgrep.chmod(0o755)

        self.data = self.directory / "orca-data.json"
        self.patch = self.directory / "settings.json"
        self.managed_id = "nix-flakes:one-half-light"
        self.patch_doc = {
            "settings": {
                "theme": "light",
                "terminalThemeDark": f"custom:{self.managed_id}",
                "terminalCustomThemes": [custom_theme(self.managed_id, "#fafafa")],
            }
        }
        self.patch.write_text(json.dumps(self.patch_doc))

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_apply(
        self, target: Path | None = None, *, pgrep_status: int = 1
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["PGREP_STATUS"] = str(pgrep_status)
        env["PATH"] = os.pathsep.join(
            (
                str(self.bin),
                str(self.coreutils_bin),
                str(self.jq_bin),
                "/usr/bin",
                "/bin",
            )
        )
        return subprocess.run(
            ["/bin/bash", SCRIPT, self.patch, target or self.data, FILTER],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
            check=False,
        )

    def backup_paths(self, data: Path | None = None) -> list[Path]:
        target = data or self.data
        return sorted(target.parent.glob(f"{target.name}.nix-backup.*"))

    def test_merge_preserves_unrelated_data_replaces_theme_and_is_idempotent(self) -> None:
        unrelated_theme = custom_theme("user:solarized", "#002b36")
        old_managed = custom_theme(self.managed_id, "#000000")
        original = {
            "projects": [{"id": "project-1", "title": "Keep me"}],
            "sessions": {"session-1": {"cwd": "/tmp/work"}},
            "arbitraryRoot": [1, {"two": True}],
            "settings": {
                "unrelated": {"nested": "value"},
                "terminalCustomThemes": [old_managed, unrelated_theme, old_managed],
            },
        }
        self.data.write_text(json.dumps(original, separators=(",", ":")))

        first = self.run_apply()
        self.assertEqual(0, first.returncode, first.stderr)
        merged = json.loads(self.data.read_text())
        self.assertEqual(original["projects"], merged["projects"])
        self.assertEqual(original["sessions"], merged["sessions"])
        self.assertEqual(original["arbitraryRoot"], merged["arbitraryRoot"])
        self.assertEqual(original["settings"]["unrelated"], merged["settings"]["unrelated"])
        themes = merged["settings"]["terminalCustomThemes"]
        self.assertEqual(["user:solarized", self.managed_id], [theme["id"] for theme in themes])
        self.assertEqual("#fafafa", themes[-1]["terminal"]["background"])
        self.assertEqual(1, len(self.backup_paths()))

        second = self.run_apply()
        self.assertEqual(0, second.returncode, second.stderr)
        self.assertIn("already applied", second.stdout)
        self.assertEqual(1, len(self.backup_paths()))

    def test_rejects_malformed_data_and_custom_theme_arrays_without_mutation(self) -> None:
        invalid_documents = (
            "{not-json",
            json.dumps([]),
            json.dumps({"settings": []}),
            json.dumps({"settings": {"terminalCustomThemes": {"id": "wrong"}}}),
        )
        for source in invalid_documents:
            with self.subTest(source=source):
                self.data.write_text(source)
                before = self.data.read_bytes()
                result = self.run_apply()
                self.assertNotEqual(0, result.returncode)
                self.assertEqual(before, self.data.read_bytes())
                self.assertEqual([], self.backup_paths())

    def test_rejects_malformed_patch_without_mutating_data(self) -> None:
        original = json.dumps({"settings": {"keep": True}}).encode()
        self.data.write_bytes(original)
        for patch in (
            {"settings": []},
            {"settings": {"terminalCustomThemes": {"id": "wrong"}}},
            {"settings": {}, "extra": True},
        ):
            with self.subTest(patch=patch):
                self.patch.write_text(json.dumps(patch))
                result = self.run_apply()
                self.assertNotEqual(0, result.returncode)
                self.assertEqual(original, self.data.read_bytes())
                self.assertEqual([], self.backup_paths())

    def test_rejects_more_than_200_custom_themes_without_mutation(self) -> None:
        original = {
            "settings": {
                "terminalCustomThemes": [
                    custom_theme(f"user:theme-{index}", "#123456")
                    for index in range(200)
                ]
            }
        }
        self.data.write_text(json.dumps(original))
        before = self.data.read_bytes()

        result = self.run_apply()

        self.assertNotEqual(0, result.returncode)
        self.assertIn("at most 200 custom themes", result.stderr)
        self.assertEqual(before, self.data.read_bytes())
        self.assertEqual([], self.backup_paths())

    def test_running_or_indeterminate_process_blocks_before_backup(self) -> None:
        original = json.dumps({"settings": {"keep": True}}).encode()
        for status, message in ((0, "Quit Orca"), (2, "Cannot determine")):
            with self.subTest(status=status):
                self.data.write_bytes(original)
                result = self.run_apply(pgrep_status=status)
                self.assertNotEqual(0, result.returncode)
                self.assertIn(message, result.stderr)
                self.assertEqual(original, self.data.read_bytes())
                self.assertEqual([], self.backup_paths())

    def test_backup_is_exact_and_private_while_target_mode_is_preserved(self) -> None:
        original = b'{\n  "settings": {"keep": true},\n  "untouched": "bytes"\n}\n'
        self.data.write_bytes(original)
        self.data.chmod(0o640)

        result = self.run_apply()

        self.assertEqual(0, result.returncode, result.stderr)
        backups = self.backup_paths()
        self.assertEqual(1, len(backups))
        self.assertEqual(original, backups[0].read_bytes())
        self.assertEqual(0o600, stat.S_IMODE(backups[0].stat().st_mode))
        self.assertEqual(0o640, stat.S_IMODE(self.data.stat().st_mode))

    def test_support_directory_updates_only_active_profile(self) -> None:
        support = self.directory / "support"
        active = support / "profiles" / "local-default" / "orca-data.json"
        active.parent.mkdir(parents=True)
        index = {"activeProfileId": "local-default"}
        (support / "orca-profile-index.json").write_text(json.dumps(index))
        stale_root = support / "orca-data.json"
        stale_bytes = b'{"stale":"root sentinel"}\n'
        stale_root.write_bytes(stale_bytes)
        active.write_text(json.dumps({"settings": {"activeSentinel": True}}))

        result = self.run_apply(support)

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(stale_bytes, stale_root.read_bytes())
        merged = json.loads(active.read_text())
        self.assertTrue(merged["settings"]["activeSentinel"])
        self.assertEqual("light", merged["settings"]["theme"])
        self.assertEqual(1, len(self.backup_paths(active)))
        self.assertEqual([], self.backup_paths(stale_root))

    def test_invalid_or_traversing_profile_index_leaves_root_untouched(self) -> None:
        support = self.directory / "support"
        support.mkdir()
        stale_root = support / "orca-data.json"
        stale_bytes = b'{"stale":"root sentinel"}\n'
        index_path = support / "orca-profile-index.json"
        for index_source in (
            "{not-json",
            json.dumps({"activeProfileId": "../escape"}),
        ):
            with self.subTest(index_source=index_source):
                stale_root.write_bytes(stale_bytes)
                index_path.write_text(index_source)
                result = self.run_apply(support)
                self.assertNotEqual(0, result.returncode)
                self.assertEqual(stale_bytes, stale_root.read_bytes())
                self.assertEqual([], self.backup_paths(stale_root))


if __name__ == "__main__":
    unittest.main()
