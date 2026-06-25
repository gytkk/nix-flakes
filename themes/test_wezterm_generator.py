#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path

from generate import load_yaml, theme_context, wezterm_theme_lua


ROOT = Path(__file__).resolve().parent


class WezTermGeneratorTest(unittest.TestCase):
    def test_exports_color_scheme_and_tab_bar_colors(self) -> None:
        theme = load_yaml(ROOT / "core" / "vira-graphene.yaml")
        ctx = theme_context(theme)

        theme_lua = wezterm_theme_lua(ctx, ROOT)

        self.assertIn("-- Auto-generated from themes/core/vira-graphene.yaml", theme_lua)
        self.assertIn("-- Template: wezterm-color-template v1", theme_lua)
        self.assertIn("return {", theme_lua)
        self.assertIn('foreground = "#D9D9D9",', theme_lua)
        self.assertIn('background = "#212121",', theme_lua)
        self.assertIn('cursor_bg = "#FFCC00",', theme_lua)
        self.assertIn('selection_fg = "#D9D9D9",', theme_lua)
        self.assertIn("ansi = {", theme_lua)
        self.assertIn('"#545454",', theme_lua)
        self.assertIn('"#f07178",', theme_lua)
        self.assertIn("brights = {", theme_lua)
        self.assertIn('"#ffffff",', theme_lua)
        self.assertIn("tab_bar = {", theme_lua)
        self.assertIn("active_tab = {", theme_lua)
        self.assertIn('bg_color = "#2b2b2b",', theme_lua)
        self.assertTrue(theme_lua.endswith("\n"))


if __name__ == "__main__":
    unittest.main()
