from __future__ import annotations

import copy
import re
import unittest
from pathlib import Path

import tomllib
from generate import contrast_ratio, herdr_theme_toml, load_yaml, theme_context

ROOT = Path(__file__).resolve().parent
CUSTOM_COLOR_KEYS = {
    "accent",
    "panel_bg",
    "sidebar_bg",
    "active_row_bg",
    "selection_bg",
    "surface0",
    "surface1",
    "surface_dim",
    "overlay0",
    "overlay1",
    "text",
    "subtext0",
    "mauve",
    "green",
    "yellow",
    "red",
    "blue",
    "teal",
    "peach",
}


class HerdrGeneratorTest(unittest.TestCase):
    def context(self, theme_id: str) -> dict:
        return theme_context(load_yaml(ROOT / "core" / f"{theme_id}.yaml"))

    def colors(self, ctx: dict) -> dict:
        return tomllib.loads(herdr_theme_toml(ctx, ROOT))["theme"]["custom"]

    def test_all_themes_render_supported_inline_colors_and_current_exports(
        self,
    ) -> None:
        for theme_path in sorted((ROOT / "core").glob("*.yaml")):
            with self.subTest(theme=theme_path.stem):
                ctx = theme_context(load_yaml(theme_path))
                rendered = herdr_theme_toml(ctx, ROOT)
                doc = tomllib.loads(rendered)
                self.assertEqual({"theme"}, set(doc))
                self.assertEqual({"name", "auto_switch", "custom"}, set(doc["theme"]))
                self.assertEqual("terminal", doc["theme"]["name"])
                self.assertIs(False, doc["theme"]["auto_switch"])
                colors = doc["theme"]["custom"]
                self.assertEqual(CUSTOM_COLOR_KEYS, set(colors))
                for key, color in colors.items():
                    self.assertIsInstance(color, str, key)
                    self.assertRegex(color, re.compile(r"^#[0-9a-fA-F]{6}$"), key)
                export = ROOT / "exports" / "herdr" / f"{ctx['meta']['id']}.toml"
                self.assertEqual(rendered, export.read_text())

    def test_muted_text_remains_readable_on_light_and_dark_row_backgrounds(
        self,
    ) -> None:
        for theme_id in ("one-half-light", "vira-graphene"):
            with self.subTest(theme=theme_id):
                ctx = self.context(theme_id)
                colors = self.colors(ctx)
                for key in ("overlay0", "subtext0"):
                    for background in (
                        ctx["roles"]["ui"]["bg"],
                        colors["panel_bg"],
                        colors["active_row_bg"],
                    ):
                        self.assertGreaterEqual(
                            contrast_ratio(colors[key], background), 4.5
                        )

    def test_surface_changes_propagate_from_canonical_roles(self) -> None:
        ctx = self.context("one-half-light")
        original = self.colors(ctx)
        self.assertEqual(ctx["roles"]["ui"]["panelBg"], original["panel_bg"])
        self.assertEqual(ctx["roles"]["ui"]["bgAlt"], original["active_row_bg"])
        self.assertEqual(ctx["roles"]["ui"]["sidebarBg"], original["sidebar_bg"])

        changed = copy.deepcopy(ctx)
        changed["roles"]["ui"].update(panelBg="#eeeeee", bgAlt="#dddddd", fg="#202020")
        colors = self.colors(changed)
        self.assertEqual("#eeeeee", colors["panel_bg"])
        self.assertEqual("#dddddd", colors["active_row_bg"])
        self.assertEqual("#dddddd", colors["surface1"])
        self.assertEqual("#202020", colors["text"])
        self.assertEqual("#202020", colors["overlay1"])
        self.assertNotEqual(original["panel_bg"], colors["panel_bg"])

    def test_selected_tabs_and_accent_text_have_readable_contrast(self) -> None:
        for theme_path in sorted((ROOT / "core").glob("*.yaml")):
            with self.subTest(theme=theme_path.stem):
                ctx = theme_context(load_yaml(theme_path))
                colors = self.colors(ctx)
                # Herdr renders selected tab labels with panel_bg on accent.
                self.assertGreaterEqual(
                    contrast_ratio(colors["panel_bg"], colors["accent"]), 4.5
                )
                original = ctx["roles"]["ui"]["borderActive"]
                if contrast_ratio(original, colors["panel_bg"]) >= 4.5:
                    self.assertEqual(original.lower(), colors["accent"].lower())


if __name__ == "__main__":
    unittest.main()
