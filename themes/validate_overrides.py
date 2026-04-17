#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from validate import ParseError, Validator, load_yaml


HEX_RE = re.compile(r"^#[0-9a-fA-F]{6}$")
PALETTE_REF_RE = re.compile(r"^\{palette\.[A-Za-z][A-Za-z0-9]*\}$")
ROLE_REF_RE = re.compile(r"^\{roles\.[A-Za-z][A-Za-z0-9]*\.[A-Za-z][A-Za-z0-9]*\}$")
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
PLAYER_RE = re.compile(r"^player_(10|[1-9])$")


ROOT = Path(__file__).resolve().parent
NVIM_TEMPLATE_PATH = ROOT / "templates" / "nvim" / "official-template.json"
ZELLIJ_TEMPLATE_PATH = ROOT / "templates" / "zellij" / "official-template.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def key_order(mapping: dict[str, Any]) -> list[str]:
    return list(mapping.keys())


def ensure_mapping(v: Validator, path: Path, node: Any, label: str) -> dict[str, Any] | None:
    if not isinstance(node, dict):
        v.error(path, f"{label} must be a mapping")
        return None
    return node


def compare_keys(v: Validator, path: Path, label: str, actual: dict[str, Any], expected_keys: list[str]) -> None:
    actual_keys = key_order(actual)
    if actual_keys != expected_keys:
        missing = [k for k in expected_keys if k not in actual]
        extra = [k for k in actual_keys if k not in expected_keys]
        if missing:
            v.error(path, f"{label} missing keys: {', '.join(missing)}")
        if extra:
            v.error(path, f"{label} extra keys: {', '.join(extra)}")
        if [k for k in actual_keys if k in expected_keys] != [k for k in expected_keys if k in actual]:
            v.error(path, f"{label} key order does not match template")


def valid_override_value(value: Any) -> bool:
    if value is None or isinstance(value, bool):
        return True
    if isinstance(value, str):
        return bool(HEX_RE.match(value) or PALETTE_REF_RE.match(value) or ROLE_REF_RE.match(value) or value)
    return False


def valid_color_value(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    return bool(HEX_RE.match(value) or PALETTE_REF_RE.match(value) or ROLE_REF_RE.match(value))


def validate_meta(v: Validator, path: Path, meta: dict[str, Any], *, app: str) -> None:
    compare_keys(v, path, "meta", meta, ["app", "theme", "variant"])
    if meta.get("app") != app:
        v.error(path, f"meta.app must be {app!r}")
    theme = meta.get("theme")
    if not isinstance(theme, str) or not ID_RE.match(theme):
        v.error(path, "meta.theme must be kebab-case")
    variant = meta.get("variant")
    if variant not in {"light", "dark"}:
        v.error(path, "meta.variant must be 'light' or 'dark'")


def validate_groups(v: Validator, path: Path, groups: dict[str, Any], allowed_attrs: set[str]) -> None:
    if not groups:
        v.error(path, "groups must not be empty")
    for group, attrs in groups.items():
        if not isinstance(group, str) or not group:
            v.error(path, "groups contains an empty group name")
            continue
        if not isinstance(attrs, dict):
            v.error(path, f"groups.{group} must be a mapping")
            continue
        if not attrs:
            v.error(path, f"groups.{group} must not be empty")
            continue
        for attr, value in attrs.items():
            if attr not in allowed_attrs:
                v.error(path, f"groups.{group}: unsupported attr key {attr!r}")
            if not valid_override_value(value):
                v.error(path, f"groups.{group}.{attr} must be a supported override scalar")


def validate_links(v: Validator, path: Path, links: dict[str, Any]) -> None:
    for group, target in links.items():
        if not isinstance(group, str) or not group:
            v.error(path, "links contains an empty group name")
            continue
        if not isinstance(target, str) or not target:
            v.error(path, f"links.{group} must be a non-empty string")


def validate_components(v: Validator, path: Path, components: dict[str, Any], allowed_components: set[str], allowed_attrs: set[str]) -> None:
    for component, attrs in components.items():
        if not isinstance(component, str) or not component:
            v.error(path, "components contains an empty component name")
            continue
        if component not in allowed_components:
            v.error(path, f"components.{component} is not a supported zellij component")
        if not isinstance(attrs, dict) or not attrs:
            v.error(path, f"components.{component} must be a non-empty mapping")
            continue
        for attr, value in attrs.items():
            if attr not in allowed_attrs:
                v.error(path, f"components.{component}: unsupported attr key {attr!r}")
            if not valid_color_value(value):
                v.error(path, f"components.{component}.{attr} must be a hex, palette ref, or role ref")


def validate_players(v: Validator, path: Path, players: dict[str, Any]) -> None:
    for player, value in players.items():
        if not isinstance(player, str) or not PLAYER_RE.match(player):
            v.error(path, f"players contains invalid player key {player!r}")
            continue
        if not valid_color_value(value):
            v.error(path, f"players.{player} must be a hex, palette ref, or role ref")


def validate_nvim_override(v: Validator, path: Path, allowed_attrs: set[str]) -> None:
    try:
        data = load_yaml(path)
    except ParseError as e:
        v.error(path, str(e))
        return

    expected_top = ["version", "meta", "groups", "links"]
    if key_order(data) != expected_top:
        v.error(path, "top-level key order does not match template")

    for key in expected_top:
        if key not in data:
            v.error(path, f"missing top-level key: {key}")
    for key in key_order(data):
        if key not in expected_top:
            v.error(path, f"unexpected top-level key: {key}")

    if data.get("version") != 1:
        v.error(path, "version must be 1")

    meta = ensure_mapping(v, path, data.get("meta"), "meta")
    groups = ensure_mapping(v, path, data.get("groups"), "groups")
    links = ensure_mapping(v, path, data.get("links"), "links")

    if meta is not None:
        validate_meta(v, path, meta, app="nvim")
    if groups is not None:
        validate_groups(v, path, groups, allowed_attrs)
    if links is not None:
        validate_links(v, path, links)


def validate_zellij_override(v: Validator, path: Path, allowed_components: set[str], allowed_attrs: set[str]) -> None:
    try:
        data = load_yaml(path)
    except ParseError as e:
        v.error(path, str(e))
        return

    expected_top = ["version", "meta", "components", "players"]
    if key_order(data) != expected_top:
        v.error(path, "top-level key order does not match template")

    for key in expected_top:
        if key not in data:
            v.error(path, f"missing top-level key: {key}")
    for key in key_order(data):
        if key not in expected_top:
            v.error(path, f"unexpected top-level key: {key}")

    if data.get("version") != 1:
        v.error(path, "version must be 1")

    meta = ensure_mapping(v, path, data.get("meta"), "meta")
    components = ensure_mapping(v, path, data.get("components"), "components")
    players = ensure_mapping(v, path, data.get("players"), "players")

    if meta is not None:
        validate_meta(v, path, meta, app="zellij")
    non_empty = 0
    if components is not None:
        if components:
            non_empty += 1
        validate_components(v, path, components, allowed_components, allowed_attrs)
    if players is not None:
        if players:
            non_empty += 1
        validate_players(v, path, players)
    if non_empty == 0:
        v.error(path, "override must define at least one component or player override")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate theme override schema files.")
    parser.add_argument(
        "paths",
        nargs="*",
        help="Override YAML files to validate. Defaults to themes/overrides/nvim/*.yaml and themes/overrides/zellij/*.yaml",
    )
    args = parser.parse_args()

    nvim_template = load_json(NVIM_TEMPLATE_PATH)
    nvim_allowed_attrs = set(nvim_template["highlight_schema"]["allowed_keys"])

    zellij_template = load_json(ZELLIJ_TEMPLATE_PATH)
    zellij_allowed_components = {section["component"] for section in zellij_template["sections"]}
    zellij_allowed_attrs = {"base", "background", "emphasis_0", "emphasis_1", "emphasis_2", "emphasis_3"}

    if args.paths:
        targets = [Path(p).resolve() for p in args.paths]
    else:
        targets = [
            *[p.resolve() for p in sorted((ROOT / "overrides" / "nvim").glob("*.yaml"))],
            *[p.resolve() for p in sorted((ROOT / "overrides" / "zellij").glob("*.yaml")) if p.name != "TEMPLATE.yaml"],
        ]
    if not targets:
        print("No override files found to validate.", file=sys.stderr)
        return 2

    v = Validator()
    for target in targets:
        if target.parent.name == "nvim":
            validate_nvim_override(v, target, nvim_allowed_attrs)
        elif target.parent.name == "zellij":
            validate_zellij_override(v, target, zellij_allowed_components, zellij_allowed_attrs)
        else:
            v.error(target, "unsupported override directory")

    if v.errors:
        print("Override validation failed:\n", file=sys.stderr)
        for err in v.errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    print(f"Validated {len(targets)} override file(s) successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
