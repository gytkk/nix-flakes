from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

from generate import contrast_ratio, ghostty_theme_conf, load_yaml, mix, theme_context
from validate_overrides import valid_ghostty_slot_value

ROOT = Path(__file__).resolve().parent


class GhosttyGeneratorTest(unittest.TestCase):
    def test_light_secondary_text_remains_readable_when_faint(self) -> None:
        ctx = theme_context(load_yaml(ROOT / "core" / "one-half-light.yaml"))
        conf = ghostty_theme_conf(ctx, ROOT)
        settings = dict(
            line.split(" = ", 1) for line in conf.splitlines() if " = " in line
        )
        opacity = float(settings.get("faint-opacity", "0.5"))
        background = settings["background"]
        foreground = ctx["roles"]["ansi"]["brightBlack"]
        self.assertGreaterEqual(
            contrast_ratio(mix(foreground, background, 1 - opacity), background), 4.5
        )
        self.assertIn("palette = 7=#bababa", conf)
        self.assertIn("palette = 15=#ffffff", conf)

    def test_dark_themes_keep_default_faint_opacity(self) -> None:
        for path in (ROOT / "core").glob("*.yaml"):
            ctx = theme_context(load_yaml(path))
            if ctx["meta"]["variant"] == "dark":
                with self.subTest(theme=path.stem):
                    self.assertIn(
                        "faint-opacity = 0.5\n", ghostty_theme_conf(ctx, ROOT)
                    )

    def test_faint_opacity_override_has_a_bounded_numeric_contract(self) -> None:
        for value in ("0", "0.5", "0.85", "1"):
            self.assertTrue(valid_ghostty_slot_value("faint_opacity", value), value)
        for value in (
            "-0.1",
            "1.1",
            "nan",
            "inf",
            "#ffffff",
            "{palette.bg}",
            "0.5\nforeground = #ffffff",
        ):
            self.assertFalse(valid_ghostty_slot_value("faint_opacity", value), value)

    def test_generator_rejects_invalid_opacity_before_rendering(self) -> None:
        ctx = theme_context(load_yaml(ROOT / "core" / "one-half-light.yaml"))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(
                ROOT / "templates" / "ghostty", root / "templates" / "ghostty"
            )
            overrides = root / "overrides" / "ghostty"
            overrides.mkdir(parents=True)
            source = (
                ROOT / "overrides" / "ghostty" / "one-half-light.yaml"
            ).read_text()
            (overrides / "one-half-light.yaml").write_text(
                source.replace('"0.85"', '"1.5"')
            )
            with self.assertRaisesRegex(RuntimeError, "opacity from 0 to 1"):
                ghostty_theme_conf(ctx, root)


if __name__ == "__main__":
    unittest.main()
