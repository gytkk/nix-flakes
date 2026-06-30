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
REPO_ROOT = ROOT.parent.parent
MERGE_FILTER = ROOT / "files" / "merge-orca-data.jq"
MODULE_FILE = ROOT / "default.nix"


class OrcaMergeTest(unittest.TestCase):
    def nix_eval_json(self, attr: str) -> JsonValue:
        result = subprocess.run(
            [
                "nix",
                "eval",
                attr,
                "--json",
            ],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(0, result.returncode, result.stderr)
        return json.loads(result.stdout)

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

    def test_module_exposes_only_settings_and_ui_orca_values(self) -> None:
        module = MODULE_FILE.read_text(encoding="utf-8")

        self.assertIn("settings = lib.mkOption", module)
        self.assertIn("ui = lib.mkOption", module)
        self.assertIn("settings = cfg.settings;", module)
        self.assertIn("ui = cfg.ui;", module)

        removed_fragments = [
            "orcaGhostty",
            "ghostty-import",
            "xdg.configFile",
            "extraSettings",
            "uiSettings",
            "fontFallbackFamilies",
        ]
        for fragment in removed_fragments:
            self.assertNotIn(fragment, module)

    def test_default_settings_include_vira_graphene_terminal_theme(self) -> None:
        settings = self.nix_eval_json(
            ".#homeConfigurations.devsisters-macbook.config.modules.orca.settings"
        )
        self.assertIsInstance(settings, dict)

        self.assertEqual("custom:ghostty:vira-graphene", settings["terminalThemeDark"])
        self.assertEqual("custom:ghostty:vira-graphene", settings["terminalThemeLight"])
        self.assertEqual(False, settings["terminalUseSeparateLightTheme"])
        self.assertEqual("#474747", settings["terminalDividerColorDark"])
        self.assertEqual("#474747", settings["terminalDividerColorLight"])

        color_overrides = settings["terminalColorOverrides"]
        self.assertEqual("#212121", color_overrides["background"])
        self.assertEqual("#D9D9D9", color_overrides["foreground"])
        self.assertEqual("#f07178", color_overrides["red"])
        self.assertEqual("#ffffff", color_overrides["brightWhite"])

        custom_themes = settings["terminalCustomThemes"]
        self.assertEqual(1, len(custom_themes))
        theme = custom_themes[0]
        self.assertEqual("ghostty:vira-graphene", theme["id"])
        self.assertEqual("Vira Graphene", theme["name"])
        self.assertEqual("ghostty", theme["source"])
        self.assertEqual("dark", theme["mode"])
        self.assertEqual(color_overrides, theme["terminal"])


if __name__ == "__main__":
    unittest.main()
