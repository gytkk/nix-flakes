#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def expect(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def require_keys(obj: dict[str, Any], keys: list[str], path: str, errors: list[str]) -> None:
    for key in keys:
        expect(key in obj, f"{path}: missing key {key!r}", errors)


def check_source_list(path: str, sources: Any, errors: list[str]) -> None:
    expect(isinstance(sources, list) and len(sources) > 0, f"{path}: sources must be a non-empty list", errors)
    if not isinstance(sources, list):
        return

    for idx, source in enumerate(sources):
        item_path = f"{path}.sources[{idx}]"
        expect(isinstance(source, dict), f"{item_path}: source must be an object", errors)
        if not isinstance(source, dict):
            continue
        require_keys(source, ["kind", "ref"], item_path, errors)
        expect(any(key in source for key in ("url", "path")), f"{item_path}: source must include either 'url' or 'path'", errors)
        expect(isinstance(source.get("kind"), str), f"{item_path}.kind must be a string", errors)
        expect(isinstance(source.get("ref"), str), f"{item_path}.ref must be a string", errors)
        if "url" in source:
            expect(isinstance(source["url"], str) and source["url"], f"{item_path}.url must be a non-empty string", errors)
        if "path" in source:
            expect(isinstance(source["path"], str) and source["path"], f"{item_path}.path must be a non-empty string", errors)


def check_section_names(path: str, sections: list[dict[str, Any]], errors: list[str]) -> None:
    seen: set[str] = set()
    for idx, section in enumerate(sections):
        item_path = f"{path}[{idx}]"
        expect(isinstance(section, dict), f"{item_path}: section must be an object", errors)
        if not isinstance(section, dict):
            continue
        expect(isinstance(section.get("name"), str) and section["name"], f"{item_path}.name must be a non-empty string", errors)
        name = section.get("name")
        if isinstance(name, str):
            expect(name not in seen, f"{path}: duplicate section name {name!r}", errors)
            seen.add(name)


def check_nvim_sections(path: str, sections: Any, errors: list[str]) -> None:
    expect(isinstance(sections, list) and len(sections) > 0, f"{path}: sections must be a non-empty list", errors)
    if not isinstance(sections, list):
        return
    check_section_names(path, sections, errors)
    for idx, section in enumerate(sections):
        if not isinstance(section, dict):
            continue
        groups = section.get("groups")
        item_path = f"{path}[{idx}]"
        expect(isinstance(groups, list) and len(groups) > 0, f"{item_path}.groups must be a non-empty list", errors)
        if not isinstance(groups, list):
            continue
        seen_groups: set[str] = set()
        for gidx, group in enumerate(groups):
            group_path = f"{item_path}.groups[{gidx}]"
            expect(isinstance(group, dict), f"{group_path}: group spec must be an object", errors)
            if not isinstance(group, dict):
                continue
            require_keys(group, ["group", "attrs"], group_path, errors)
            expect(isinstance(group.get("group"), str) and group["group"], f"{group_path}.group must be a non-empty string", errors)
            expect(isinstance(group.get("attrs"), dict), f"{group_path}.attrs must be an object", errors)
            name = group.get("group")
            if isinstance(name, str):
                expect(name not in seen_groups, f"{item_path}: duplicate group name {name!r}", errors)
                seen_groups.add(name)


def check_zed_style_sections(path: str, sections: Any, errors: list[str]) -> set[str]:
    keys: set[str] = set()
    expect(isinstance(sections, list) and len(sections) > 0, f"{path}: style_sections must be a non-empty list", errors)
    if not isinstance(sections, list):
        return keys
    check_section_names(path, sections, errors)
    for idx, section in enumerate(sections):
        if not isinstance(section, dict):
            continue
        entries = section.get("entries")
        item_path = f"{path}[{idx}]"
        expect(isinstance(entries, list) and len(entries) > 0, f"{item_path}.entries must be a non-empty list", errors)
        if not isinstance(entries, list):
            continue
        for eidx, entry in enumerate(entries):
            entry_path = f"{item_path}.entries[{eidx}]"
            expect(isinstance(entry, dict), f"{entry_path}: entry must be an object", errors)
            if not isinstance(entry, dict):
                continue
            require_keys(entry, ["key", "value"], entry_path, errors)
            expect(isinstance(entry.get("key"), str) and entry["key"], f"{entry_path}.key must be a non-empty string", errors)
            key = entry.get("key")
            if isinstance(key, str):
                expect(key not in keys, f"{path}: duplicate style key {key!r}", errors)
                keys.add(key)
    return keys


def check_zed_syntax_sections(path: str, sections: Any, errors: list[str]) -> set[str]:
    keys: set[str] = set()
    expect(isinstance(sections, list) and len(sections) > 0, f"{path}: syntax_sections must be a non-empty list", errors)
    if not isinstance(sections, list):
        return keys
    check_section_names(path, sections, errors)
    for idx, section in enumerate(sections):
        if not isinstance(section, dict):
            continue
        entries = section.get("entries")
        item_path = f"{path}[{idx}]"
        expect(isinstance(entries, list) and len(entries) > 0, f"{item_path}.entries must be a non-empty list", errors)
        if not isinstance(entries, list):
            continue
        for eidx, entry in enumerate(entries):
            entry_path = f"{item_path}.entries[{eidx}]"
            expect(isinstance(entry, dict), f"{entry_path}: entry must be an object", errors)
            if not isinstance(entry, dict):
                continue
            require_keys(entry, ["key", "value"], entry_path, errors)
            expect(isinstance(entry.get("key"), str) and entry["key"], f"{entry_path}.key must be a non-empty string", errors)
            expect(isinstance(entry.get("value"), dict), f"{entry_path}.value must be an object", errors)
            key = entry.get("key")
            if isinstance(key, str):
                expect(key not in keys, f"{path}: duplicate syntax key {key!r}", errors)
                keys.add(key)
    return keys


def check_common(path: Path, doc: dict[str, Any], errors: list[str]) -> None:
    path_str = str(path)
    require_keys(doc, ["name", "version", "description", "sources"], path_str, errors)
    expect(isinstance(doc.get("name"), str) and doc["name"], f"{path_str}.name must be a non-empty string", errors)
    expect(isinstance(doc.get("version"), (str, int)), f"{path_str}.version must be a string or integer", errors)
    expect(isinstance(doc.get("description"), str) and doc["description"], f"{path_str}.description must be a non-empty string", errors)
    check_source_list(path_str, doc.get("sources"), errors)


def check_nvim(path: Path, doc: dict[str, Any], errors: list[str]) -> None:
    check_common(path, doc, errors)
    path_str = str(path)
    contract = doc.get("highlight_schema")
    expect(isinstance(contract, dict), f"{path_str}.highlight_schema must be an object", errors)
    if isinstance(contract, dict):
        require_keys(contract, ["api", "allowed_keys", "token_prefix", "token_note"], f"{path_str}.highlight_schema", errors)
        expect(contract.get("api") == "nvim_set_hl", f"{path_str}.highlight_schema.api must be 'nvim_set_hl'", errors)
        expect(contract.get("token_prefix") == "$", f"{path_str}.highlight_schema.token_prefix must be '$'", errors)
        expect(isinstance(contract.get("allowed_keys"), list) and len(contract["allowed_keys"]) > 0, f"{path_str}.highlight_schema.allowed_keys must be a non-empty list", errors)
    check_nvim_sections(f"{path_str}.sections", doc.get("sections"), errors)


def check_zed(path: Path, doc: dict[str, Any], errors: list[str]) -> None:
    check_common(path, doc, errors)
    path_str = str(path)
    contract = doc.get("theme_family_schema")
    expect(isinstance(contract, dict), f"{path_str}.theme_family_schema must be an object", errors)
    if isinstance(contract, dict):
        require_keys(contract, ["schema_url", "token_prefix", "style_key_source", "syntax_value_schema"], f"{path_str}.theme_family_schema", errors)
        expect(contract.get("token_prefix") == "$", f"{path_str}.theme_family_schema.token_prefix must be '$'", errors)
        expect(contract.get("style_key_source") == "official-json-schema", f"{path_str}.theme_family_schema.style_key_source must be 'official-json-schema'", errors)
    style_keys = check_zed_style_sections(f"{path_str}.style_sections", doc.get("style_sections"), errors)
    syntax_keys = check_zed_syntax_sections(f"{path_str}.syntax_sections", doc.get("syntax_sections"), errors)
    players = doc.get("players")
    expect(isinstance(players, list) and len(players) > 0, f"{path_str}.players must be a non-empty list", errors)
    if isinstance(players, list):
        for idx, player in enumerate(players):
            item_path = f"{path_str}.players[{idx}]"
            expect(isinstance(player, dict), f"{item_path}: player entry must be an object", errors)
            if not isinstance(player, dict):
                continue
            require_keys(player, ["cursor", "background", "selection"], item_path, errors)
    declared_style_keys = doc.get("style_keys")
    expect(isinstance(declared_style_keys, list) and len(declared_style_keys) > 0, f"{path_str}.style_keys must be a non-empty list", errors)
    if isinstance(declared_style_keys, list):
        actual = style_keys | {"players", "syntax"}
        declared = set(declared_style_keys)
        expect(declared == actual, f"{path_str}.style_keys must exactly match style section keys plus players/syntax", errors)
    expect(len(syntax_keys) > 0, f"{path_str}: syntax_sections must declare at least one syntax key", errors)


def check_nvim_plugin_template(path: Path, doc: dict[str, Any], errors: list[str]) -> None:
    check_common(path, doc, errors)
    check_nvim_sections(f"{path}.sections", doc.get("sections"), errors)


CHECKS = {
    ROOT / "templates" / "nvim" / "official-template.json": check_nvim,
    ROOT / "templates" / "zed" / "official-template.json": check_zed,
    ROOT / "templates" / "nvim" / "plugins.json": check_nvim_plugin_template,
}


def main() -> int:
    errors: list[str] = []
    for path, checker in CHECKS.items():
        checker(path.relative_to(ROOT), load(path), errors)

    if errors:
        print("Template consistency check failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Validated {len(CHECKS)} template file(s) successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
