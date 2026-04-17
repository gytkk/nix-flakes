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


ROOT = Path(__file__).resolve().parent
NVIM_TEMPLATE_PATH = ROOT / "templates" / "nvim" / "official-template.json"


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
        return bool(
            HEX_RE.match(value)
            or PALETTE_REF_RE.match(value)
            or ROLE_REF_RE.match(value)
            or value
        )
    return False


def validate_meta(v: Validator, path: Path, meta: dict[str, Any]) -> None:
    compare_keys(v, path, "meta", meta, ["app", "theme", "variant"])
    if meta.get("app") != "nvim":
        v.error(path, "meta.app must be 'nvim'")
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


def validate_override(v: Validator, path: Path, allowed_attrs: set[str]) -> None:
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
        validate_meta(v, path, meta)
    if groups is not None:
        validate_groups(v, path, groups, allowed_attrs)
    if links is not None:
        validate_links(v, path, links)


def discover_default_targets(root: Path) -> list[Path]:
    return sorted((root / "overrides" / "nvim").glob("*.yaml"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate theme override schema files.")
    parser.add_argument(
        "paths",
        nargs="*",
        help="Override YAML files to validate. Defaults to themes/overrides/nvim/*.yaml",
    )
    args = parser.parse_args()

    template = load_json(NVIM_TEMPLATE_PATH)
    allowed_attrs = set(template["highlight_schema"]["allowed_keys"])

    targets = [Path(p).resolve() for p in args.paths] if args.paths else [p.resolve() for p in discover_default_targets(ROOT)]
    if not targets:
        print("No override files found to validate.", file=sys.stderr)
        return 2

    v = Validator()
    for target in targets:
        validate_override(v, target, allowed_attrs)

    if v.errors:
        print("Override validation failed:\n", file=sys.stderr)
        for err in v.errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    print(f"Validated {len(targets)} override file(s) successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
