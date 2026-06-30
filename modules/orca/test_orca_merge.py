#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


type JsonValue = None | bool | int | float | str | list[JsonValue] | dict[str, JsonValue]
type JsonObject = dict[str, JsonValue]


ROOT = Path(__file__).resolve().parent
MERGE_FILTER = ROOT / "files" / "merge-orca-data.jq"


class OrcaMergeTest(unittest.TestCase):
    def merge_orca_data(self, data: JsonObject, patch: JsonObject) -> JsonObject:
        self.assertTrue(MERGE_FILTER.exists(), f"missing jq filter: {MERGE_FILTER}")

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            data_path = tmp_path / "orca-data.json"
            patch_path = tmp_path / "patch.json"
            data_path.write_text(json.dumps(data), encoding="utf-8")
            patch_path.write_text(json.dumps(patch), encoding="utf-8")

            result = subprocess.run(
                [
                    "jq",
                    "--slurpfile",
                    "patch",
                    str(patch_path),
                    "-f",
                    str(MERGE_FILTER),
                    str(data_path),
                ],
                check=False,
                capture_output=True,
                text=True,
            )

        self.assertEqual(0, result.returncode, result.stderr)
        return json.loads(result.stdout)

    def test_merge_updates_only_settings_and_ui(self) -> None:
        data = {
            "schemaVersion": 1,
            "projects": {"keep": True},
            "workspaceSession": {"active": "session-1"},
            "settings": {
                "keepExisting": "yes",
                "terminalFontSize": 12,
                "terminalCustomThemes": [
                    {"id": "user:theme", "name": "User Theme"},
                    {"id": "ghostty:vira-graphene", "name": "Old Managed Theme"},
                ],
            },
            "ui": {
                "sidebarWidth": 320,
                "rightSidebarOpen": False,
            },
        }
        patch = {
            "settings": {
                "terminalFontSize": 14,
                "terminalCustomThemes": [
                    {"id": "ghostty:vira-graphene", "name": "Vira Graphene"},
                    {"id": "ghostty:second", "name": "Second Theme"},
                ],
            },
            "ui": {
                "rightSidebarOpen": True,
            },
            "projects": {"must": "not merge"},
        }

        merged = self.merge_orca_data(data, patch)

        self.assertEqual({"keep": True}, merged["projects"])
        self.assertEqual({"active": "session-1"}, merged["workspaceSession"])
        self.assertEqual("yes", merged["settings"]["keepExisting"])
        self.assertEqual(14, merged["settings"]["terminalFontSize"])
        self.assertEqual(320, merged["ui"]["sidebarWidth"])
        self.assertEqual(True, merged["ui"]["rightSidebarOpen"])

        themes = merged["settings"]["terminalCustomThemes"]
        self.assertEqual(
            [
                {"id": "user:theme", "name": "User Theme"},
                {"id": "ghostty:vira-graphene", "name": "Vira Graphene"},
                {"id": "ghostty:second", "name": "Second Theme"},
            ],
            themes,
        )

    def test_merge_creates_missing_settings_and_ui_objects(self) -> None:
        data = {
            "schemaVersion": 1,
            "repos": {"keep": True},
        }
        patch = {
            "settings": {"terminalFontSize": 14},
            "ui": {"statusBarVisible": True},
        }

        merged = self.merge_orca_data(data, patch)

        self.assertEqual({"keep": True}, merged["repos"])
        self.assertEqual({"terminalFontSize": 14}, merged["settings"])
        self.assertEqual({"statusBarVisible": True}, merged["ui"])


if __name__ == "__main__":
    unittest.main()
