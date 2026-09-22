#!/usr/bin/env python3
from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path

from check_templates import check_orca
from generate import (
    ORCA_TERMINAL_KEYS,
    ghostty_theme_conf,
    load_yaml,
    orca_theme_doc,
    theme_context,
    validate_orca_theme_doc,
)


ROOT = Path(__file__).resolve().parent

GHOSTTY_TO_ORCA = {
    "background": "background",
    "foreground": "foreground",
    "cursor-color": "cursor",
    "cursor-text": "cursorAccent",
    "selection-background": "selectionBackground",
    "selection-foreground": "selectionForeground",
}
ANSI_KEYS = (
    "black",
    "red",
    "green",
    "yellow",
    "blue",
    "magenta",
    "cyan",
    "white",
    "brightBlack",
    "brightRed",
    "brightGreen",
    "brightYellow",
    "brightBlue",
    "brightMagenta",
    "brightCyan",
    "brightWhite",
)


def parse_ghostty_terminal(conf: str) -> dict[str, str]:
    values: dict[str, str] = {}
    palette: dict[int, str] = {}
    for line in conf.splitlines():
        if not line or line.startswith("#"):
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key == "palette":
            index, color = value.split("=", 1)
            palette[int(index)] = color
        elif key in GHOSTTY_TO_ORCA:
            values[GHOSTTY_TO_ORCA[key]] = value

    if set(palette) != set(range(16)):
        raise AssertionError(f"Ghostty palette indices were {sorted(palette)}")
    values.update({key: palette[index] for index, key in enumerate(ANSI_KEYS)})
    return {key: color.lower() for key, color in values.items()}


class OrcaGeneratorTest(unittest.TestCase):
    def test_all_themes_match_independently_parsed_ghostty_colors(self) -> None:
        for path in sorted((ROOT / "core").glob("*.yaml")):
            with self.subTest(theme=path.stem):
                ctx = theme_context(load_yaml(path))
                orca = orca_theme_doc(ctx, ROOT)
                ghostty = parse_ghostty_terminal(ghostty_theme_conf(ctx, ROOT))

                self.assertEqual(ORCA_TERMINAL_KEYS, set(orca["terminal"]))
                self.assertEqual(22, len(orca["terminal"]))
                self.assertEqual(ghostty, orca["terminal"])

    def test_one_half_light_keeps_ghostty_override_colors(self) -> None:
        ctx = theme_context(load_yaml(ROOT / "core" / "one-half-light.yaml"))
        terminal = orca_theme_doc(ctx, ROOT)["terminal"]

        self.assertEqual("#fafafa", terminal["background"])
        self.assertEqual("#a5b4e5", terminal["cursor"])
        self.assertEqual("#383a42", terminal["cursorAccent"])
        self.assertEqual("#0997b3", terminal["cyan"])
        self.assertEqual("#bababa", terminal["white"])
        self.assertEqual("#d8b36e", terminal["brightYellow"])

    def test_metadata_uses_canonical_variant_and_stable_namespaced_id(self) -> None:
        for path in sorted((ROOT / "core").glob("*.yaml")):
            with self.subTest(theme=path.stem):
                theme = load_yaml(path)
                ctx = theme_context(theme)
                first = orca_theme_doc(ctx, ROOT)
                second = orca_theme_doc(ctx, ROOT)

                self.assertEqual(theme["meta"]["variant"], first["mode"])
                self.assertIn(first["mode"], {"light", "dark"})
                self.assertEqual(f"nix-flakes:{theme['meta']['id']}", first["id"])
                self.assertEqual(first["id"], second["id"])

    def test_document_validation_rejects_invalid_terminal_contract(self) -> None:
        ctx = theme_context(load_yaml(ROOT / "core" / "one-half-light.yaml"))
        valid = orca_theme_doc(ctx, ROOT)

        missing = copy.deepcopy(valid)
        del missing["terminal"]["foreground"]
        unknown = copy.deepcopy(valid)
        unknown["terminal"]["bold"] = "#112233"
        malformed = copy.deepcopy(valid)
        malformed["terminal"]["red"] = "#12345g"

        for case, doc in (
            ("missing", missing),
            ("unknown", unknown),
            ("malformed", malformed),
        ):
            with self.subTest(case=case):
                with self.assertRaises(RuntimeError):
                    validate_orca_theme_doc(doc)

    def test_template_check_rejects_duplicate_and_missing_colors(self) -> None:
        template_path = ROOT / "templates" / "orca" / "official-template.json"
        valid = json.loads(template_path.read_text())

        duplicate = copy.deepcopy(valid)
        duplicate["sections"][0]["entries"].append(
            copy.deepcopy(duplicate["sections"][0]["entries"][0])
        )
        missing = copy.deepcopy(valid)
        missing["sections"][1]["entries"].pop()

        for case, doc, expected_error in (
            ("duplicate", duplicate, "duplicate terminal color key"),
            ("missing", missing, "terminal keys must match the managed Orca palette"),
        ):
            with self.subTest(case=case):
                errors: list[str] = []
                check_orca(template_path, doc, errors)
                self.assertTrue(
                    any(expected_error in error for error in errors),
                    f"expected {expected_error!r} in {errors!r}",
                )


if __name__ == "__main__":
    unittest.main()
