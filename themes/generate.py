#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

from validate import ParseError, Validator, load_yaml, validate_theme


REF_RE = re.compile(r"^\{palette\.([A-Za-z][A-Za-z0-9]*)\}$")
ROLE_REF_RE = re.compile(r"^\{roles\.([A-Za-z][A-Za-z0-9]*)\.([A-Za-z][A-Za-z0-9]*)\}$")


def alpha(hex_color: str, suffix: str) -> str:
    return f"{hex_color}{suffix}"


def hex_to_rgb(hex_color: str) -> tuple[int, int, int]:
    value = hex_color.removeprefix("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return "#%02x%02x%02x" % rgb


def mix(hex_a: str, hex_b: str, ratio_b: float) -> str:
    ratio_a = 1.0 - ratio_b
    a = hex_to_rgb(hex_a)
    b = hex_to_rgb(hex_b)
    mixed = tuple(round(a[i] * ratio_a + b[i] * ratio_b) for i in range(3))
    return rgb_to_hex(mixed)


def soft_background(accent: str, bg: str, *, light: bool, strength: float = 0.82) -> str:
    ratio_bg = strength if light else min(0.88, strength + 0.04)
    return mix(accent, bg, ratio_bg)


def raised_surface(bg_alt: str, border: str, *, light: bool) -> str:
    return mix(bg_alt, border, 0.22 if light else 0.14)


def sharpen(accent: str, bg: str, *, light: bool) -> str:
    return mix(accent, bg, 0.58 if light else 0.28)


def dim_terminal(color: str, bg: str, *, light: bool) -> str:
    return mix(color, bg, 0.34 if light else 0.42)


def load_and_validate_theme(theme_path: Path, template: dict[str, Any]) -> dict[str, Any]:
    validator = Validator()
    validate_theme(validator, theme_path, template)
    if validator.errors:
        raise RuntimeError("\n".join(validator.errors))
    return load_yaml(theme_path)


def resolve_palette(theme: dict[str, Any]) -> dict[str, str]:
    palette = theme["palette"]
    resolved: dict[str, str] = {}
    resolving: set[str] = set()

    def resolve(name: str) -> str:
        if name in resolved:
            return resolved[name]
        if name in resolving:
            raise RuntimeError(f"cyclic palette reference: {name}")
        if name not in palette:
            raise RuntimeError(f"missing palette key: {name}")
        resolving.add(name)
        value = palette[name]
        if not isinstance(value, str):
            raise RuntimeError(f"palette.{name} must be a string")
        match = REF_RE.match(value)
        if match:
            final = resolve(match.group(1))
        else:
            final = value
        resolving.remove(name)
        resolved[name] = final
        return final

    for key in palette:
        resolve(key)
    return resolved


def resolve_value(value: str, resolved_palette: dict[str, str]) -> str:
    match = REF_RE.match(value)
    if match:
        return resolved_palette[match.group(1)]
    return value


def resolve_roles(theme: dict[str, Any], resolved_palette: dict[str, str]) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for group, values in theme["roles"].items():
        out[group] = {key: resolve_value(val, resolved_palette) for key, val in values.items()}
    return out


def theme_context(theme: dict[str, Any]) -> dict[str, Any]:
    palette = resolve_palette(theme)
    roles = resolve_roles(theme, palette)
    return {
        "meta": theme["meta"],
        "palette": palette,
        "roles": roles,
    }


def resolve_context_value(value: Any, ctx: dict[str, Any]) -> Any:
    if isinstance(value, str):
        palette_match = REF_RE.match(value)
        if palette_match:
            return ctx["palette"][palette_match.group(1)]

        role_match = ROLE_REF_RE.match(value)
        if role_match:
            group, key = role_match.groups()
            return ctx["roles"][group][key]

        if value == "true":
            return True
        if value == "false":
            return False
        if value == "null":
            return None
        return value

    if isinstance(value, dict):
        return {key: resolve_context_value(item, ctx) for key, item in value.items()}
    if isinstance(value, list):
        return [resolve_context_value(item, ctx) for item in value]
    return value


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def load_zed_schema(root: Path) -> dict[str, Any]:
    return load_json(root / "templates" / "zed" / "schema-v0.2.0.json")


def load_zed_template(root: Path) -> dict[str, Any]:
    return load_json(root / "templates" / "zed" / "official-template.json")


def _schema_check_type(expected: Any, value: Any) -> bool:
    if isinstance(expected, list):
        return any(_schema_check_type(item, value) for item in expected)
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return (isinstance(value, int) or isinstance(value, float)) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "null":
        return value is None
    return True


def _resolve_schema_ref(ref: str, schema: dict[str, Any]) -> dict[str, Any]:
    if not ref.startswith("#/definitions/"):
        raise RuntimeError(f"unsupported schema ref: {ref}")
    name = ref.removeprefix("#/definitions/")
    return schema["definitions"][name]


def _validate_against_schema(node: dict[str, Any], value: Any, schema: dict[str, Any], path: str, errors: list[str]) -> None:
    if "$ref" in node:
        _validate_against_schema(_resolve_schema_ref(node["$ref"], schema), value, schema, path, errors)
        return

    if "anyOf" in node:
        branch_errors: list[list[str]] = []
        for option in node["anyOf"]:
            local_errors: list[str] = []
            _validate_against_schema(option, value, schema, path, local_errors)
            if not local_errors:
                break
            branch_errors.append(local_errors)
        else:
            errors.append(f"{path}: value did not match any allowed schema branch")
        return

    if "enum" in node and value not in node["enum"]:
        errors.append(f"{path}: expected one of {node['enum']!r}, got {value!r}")
        return

    expected_type = node.get("type")
    if expected_type is not None and not _schema_check_type(expected_type, value):
        errors.append(f"{path}: expected type {expected_type!r}, got {type(value).__name__}")
        return

    if isinstance(value, dict):
        required = node.get("required", [])
        for key in required:
            if key not in value:
                errors.append(f"{path}: missing required key {key!r}")

        properties = node.get("properties", {})
        additional = node.get("additionalProperties", None)
        for key, item in value.items():
            child_path = f"{path}.{key}" if path else key
            if key in properties:
                _validate_against_schema(properties[key], item, schema, child_path, errors)
            elif isinstance(additional, dict):
                _validate_against_schema(additional, item, schema, child_path, errors)

    if isinstance(value, list) and "items" in node:
        for idx, item in enumerate(value):
            _validate_against_schema(node["items"], item, schema, f"{path}[{idx}]", errors)


def validate_zed_theme_doc(doc: dict[str, Any], root: Path) -> None:
    schema = load_zed_schema(root)
    template = load_zed_template(root)
    errors: list[str] = []
    _validate_against_schema(schema, doc, schema, "theme", errors)

    allowed_style_keys = set(template["style_keys"])
    for idx, theme in enumerate(doc.get("themes", [])):
        style = theme.get("style", {})
        unknown = sorted(key for key in style.keys() if key not in allowed_style_keys and key not in {"players", "syntax"})
        if unknown:
            errors.append(f"theme.themes[{idx}].style: unknown style keys: {', '.join(unknown)}")

    if errors:
        raise RuntimeError("Zed theme schema validation failed:\n" + "\n".join(errors))


def render_template_value(value: Any, slots: dict[str, Any]) -> Any:
    if isinstance(value, str) and value.startswith("$"):
        name = value[1:]
        if name not in slots:
            raise RuntimeError(f"missing template slot: {name}")
        return slots[name]
    if isinstance(value, dict):
        return {key: render_template_value(item, slots) for key, item in value.items()}
    if isinstance(value, list):
        return [render_template_value(item, slots) for item in value]
    return value


def build_zed_slots(ctx: dict[str, Any]) -> dict[str, Any]:
    meta = ctx["meta"]
    p = ctx["palette"]
    r = ctx["roles"]
    is_light = meta["variant"] == "light"

    players = [p["blue"], p["orange"], p["yellow"], p["cyan"], p["green"], p["red"], p["blueBright"], p["magentaBright"]]
    slots: dict[str, Any] = {
        "border": alpha(r["ui"]["border"], "ff"),
        "border_variant": alpha(p["whitespace"], "ff"),
        "border_focused": alpha(r["ui"]["borderActive"], "ff"),
        "border_selected": alpha(r["ui"]["selection"], "ff"),
        "border_transparent": "#00000000",
        "border_disabled": alpha(r["ui"]["border"], "ff"),
        "elevated_surface_background": alpha(r["ui"]["bgElevated"], "ff"),
        "surface_background": alpha(r["ui"]["panelBg"], "ff"),
        "background": alpha(r["ui"]["bgAlt"], "ff"),
        "element_background": alpha(r["ui"]["bgElevated"], "ff"),
        "element_hover": alpha(r["ui"]["currentLine"], "ff"),
        "element_active": alpha(r["ui"]["selection"], "ff"),
        "element_selected": alpha(r["ui"]["selection"], "ff"),
        "element_disabled": alpha(r["ui"]["bgElevated"], "ff"),
        "drop_target_background": alpha(r["ui"]["selection"], "80"),
        "ghost_element_background": "#00000000",
        "ghost_element_hover": alpha(r["ui"]["currentLine"], "ff"),
        "ghost_element_active": alpha(r["ui"]["selection"], "ff"),
        "ghost_element_selected": alpha(r["ui"]["selection"], "ff"),
        "ghost_element_disabled": alpha(r["ui"]["bgElevated"], "ff"),
        "text": alpha(r["ui"]["fg"], "ff"),
        "text_muted": alpha(r["ui"]["fgMuted"], "ff"),
        "text_placeholder": alpha(p["lineNumber"], "ff"),
        "text_disabled": alpha(p["lineNumber"], "ff"),
        "text_accent": alpha(r["syntax"]["function"], "ff"),
        "icon": alpha(r["ui"]["fg"], "ff"),
        "icon_muted": alpha(r["ui"]["fgMuted"], "ff"),
        "icon_disabled": alpha(p["lineNumber"], "ff"),
        "icon_placeholder": alpha(r["ui"]["fgMuted"], "ff"),
        "icon_accent": alpha(r["syntax"]["function"], "ff"),
        "link_text_hover": alpha(r["syntax"]["link"], "ff"),
        "status_bar_background": alpha(r["ui"]["statuslineBg"], "ff"),
        "title_bar_background": alpha(r["ui"]["panelBg"], "ff"),
        "title_bar_inactive_background": alpha(r["ui"]["panelBg"], "ff"),
        "toolbar_background": alpha(r["ui"]["bg"], "ff"),
        "tab_bar_background": alpha(r["ui"]["bgAlt"], "ff"),
        "tab_inactive_background": alpha(r["ui"]["bgAlt"], "ff"),
        "tab_active_background": alpha(r["ui"]["bg"], "ff"),
        "search_match_background": alpha(r["ui"]["search"], "80"),
        "panel_background": alpha(r["ui"]["panelBg"], "ff"),
        "panel_focused_border": alpha(r["ui"]["borderActive"], "ff"),
        "panel_indent_guide": alpha(r["ui"]["border"], "66"),
        "panel_indent_guide_active": alpha(r["ui"]["borderActive"], "99"),
        "panel_indent_guide_hover": alpha(r["ui"]["fgMuted"], "80"),
        "pane_focused_border": alpha(r["ui"]["borderActive"], "ff"),
        "pane_group_border": alpha(r["ui"]["border"], "ff"),
        "scrollbar_thumb_background": alpha(r["ui"]["fgMuted"], "40"),
        "scrollbar_thumb_hover_background": alpha(r["ui"]["fgMuted"], "60"),
        "scrollbar_thumb_border": alpha(r["ui"]["border"], "ff"),
        "scrollbar_track_background": "#00000000",
        "scrollbar_track_border": alpha(r["ui"]["border"], "ff"),
        "editor_foreground": alpha(r["ui"]["fg"], "ff"),
        "editor_background": alpha(r["ui"]["bg"], "ff"),
        "editor_gutter_background": alpha(r["ui"]["bg"], "ff"),
        "editor_subheader_background": alpha(r["ui"]["bgElevated"], "ff"),
        "editor_active_line_background": alpha(r["ui"]["currentLine"], "bf"),
        "editor_highlighted_line_background": alpha(r["ui"]["currentLine"], "ff"),
        "editor_line_number": alpha(p["lineNumber"], "ff"),
        "editor_active_line_number": alpha(r["ui"]["currentLineNumber"], "ff"),
        "editor_invisible": alpha(p["whitespace"], "ff"),
        "editor_wrap_guide": alpha(r["ui"]["border"], "ff"),
        "editor_active_wrap_guide": alpha(p["whitespace"], "ff"),
        "editor_indent_guide": alpha(r["ui"]["border"], "66"),
        "editor_indent_guide_active": alpha(r["ui"]["borderActive"], "99"),
        "editor_document_highlight_bracket_background": alpha(r["ui"]["selection"], "33"),
        "editor_document_highlight_read_background": alpha(r["ui"]["selection"], "40"),
        "editor_document_highlight_write_background": alpha(r["ui"]["selection"], "60"),
        "terminal_background": alpha(r["ui"]["bg"], "ff"),
        "terminal_foreground": alpha(r["ui"]["fg"], "ff"),
        "terminal_bright_foreground": alpha(p["fgBright"], "ff"),
        "terminal_dim_foreground": alpha(p["fgMuted"], "ff"),
        "terminal_ansi_background": alpha(r["ui"]["bg"], "ff"),
        "terminal_ansi_black": alpha(r["ansi"]["black"], "ff"),
        "terminal_ansi_bright_black": alpha(r["ansi"]["brightBlack"], "ff"),
        "terminal_ansi_dim_black": alpha(dim_terminal(r["ansi"]["black"], r["ui"]["bg"], light=is_light), "ff"),
        "terminal_ansi_red": alpha(r["ansi"]["red"], "ff"),
        "terminal_ansi_bright_red": alpha(r["ansi"]["brightRed"], "ff"),
        "terminal_ansi_dim_red": alpha(dim_terminal(r["ansi"]["red"], r["ui"]["bg"], light=is_light), "ff"),
        "terminal_ansi_green": alpha(r["ansi"]["green"], "ff"),
        "terminal_ansi_bright_green": alpha(r["ansi"]["brightGreen"], "ff"),
        "terminal_ansi_dim_green": alpha(dim_terminal(r["ansi"]["green"], r["ui"]["bg"], light=is_light), "ff"),
        "terminal_ansi_yellow": alpha(r["ansi"]["yellow"], "ff"),
        "terminal_ansi_bright_yellow": alpha(r["ansi"]["brightYellow"], "ff"),
        "terminal_ansi_dim_yellow": alpha(dim_terminal(r["ansi"]["yellow"], r["ui"]["bg"], light=is_light), "ff"),
        "terminal_ansi_blue": alpha(r["ansi"]["blue"], "ff"),
        "terminal_ansi_bright_blue": alpha(r["ansi"]["brightBlue"], "ff"),
        "terminal_ansi_dim_blue": alpha(dim_terminal(r["ansi"]["blue"], r["ui"]["bg"], light=is_light), "ff"),
        "terminal_ansi_magenta": alpha(r["ansi"]["magenta"], "ff"),
        "terminal_ansi_bright_magenta": alpha(r["ansi"]["brightMagenta"], "ff"),
        "terminal_ansi_dim_magenta": alpha(dim_terminal(r["ansi"]["magenta"], r["ui"]["bg"], light=is_light), "ff"),
        "terminal_ansi_cyan": alpha(r["ansi"]["cyan"], "ff"),
        "terminal_ansi_bright_cyan": alpha(r["ansi"]["brightCyan"], "ff"),
        "terminal_ansi_dim_cyan": alpha(dim_terminal(r["ansi"]["cyan"], r["ui"]["bg"], light=is_light), "ff"),
        "terminal_ansi_white": alpha(r["ansi"]["white"], "ff"),
        "terminal_ansi_bright_white": alpha(r["ansi"]["brightWhite"], "ff"),
        "terminal_ansi_dim_white": alpha(dim_terminal(r["ansi"]["white"], r["ui"]["bg"], light=is_light), "ff"),
        "conflict": alpha(r["vcs"]["conflict"], "ff"),
        "conflict_background": alpha(r["vcs"]["conflict"], "1a"),
        "conflict_border": alpha(p["yellowBright"], "ff"),
        "created": alpha(r["diagnostics"]["ok"], "ff"),
        "created_background": alpha(r["diagnostics"]["ok"], "1a"),
        "created_border": alpha(p["greenBright"], "ff"),
        "deleted": alpha(r["diagnostics"]["error"], "ff"),
        "deleted_background": alpha(r["diagnostics"]["error"], "1a"),
        "deleted_border": alpha(p["pink"], "ff"),
        "error": alpha(r["diagnostics"]["error"], "ff"),
        "error_background": alpha(r["diagnostics"]["error"], "1a"),
        "error_border": alpha(p["pink"], "ff"),
        "hidden": alpha(p["lineNumber"], "ff"),
        "hidden_background": alpha(r["ui"]["bgAlt"], "ff"),
        "hidden_border": alpha(r["ui"]["border"], "ff"),
        "hint": alpha(r["diagnostics"]["hint"], "ff"),
        "hint_background": alpha(r["diagnostics"]["hint"], "1a"),
        "hint_border": alpha(p["cyanBright"], "ff"),
        "ignored": alpha(p["lineNumber"], "ff"),
        "ignored_background": alpha(r["ui"]["bgAlt"], "ff"),
        "ignored_border": alpha(r["ui"]["border"], "ff"),
        "info": alpha(r["diagnostics"]["info"], "ff"),
        "info_background": alpha(r["diagnostics"]["info"], "1a"),
        "info_border": alpha(p["blueBright"], "ff"),
        "modified": alpha(r["vcs"]["modified"], "ff"),
        "modified_background": alpha(r["vcs"]["modified"], "1a"),
        "modified_border": alpha(p["yellowBright"], "ff"),
        "predictive": alpha(p["lineNumber"], "ff"),
        "predictive_background": alpha(r["ui"]["bgAlt"], "ff"),
        "predictive_border": alpha(r["ui"]["border"], "ff"),
        "renamed": alpha(r["vcs"]["renamed"], "ff"),
        "renamed_background": alpha(r["vcs"]["renamed"], "1a"),
        "renamed_border": alpha(p["blueBright"], "ff"),
        "success": alpha(r["diagnostics"]["ok"], "ff"),
        "success_background": alpha(r["diagnostics"]["ok"], "1a"),
        "success_border": alpha(p["greenBright"], "ff"),
        "unreachable": alpha(p["lineNumber"], "ff"),
        "unreachable_background": alpha(r["ui"]["bgAlt"], "ff"),
        "unreachable_border": alpha(r["ui"]["border"], "ff"),
        "warning": alpha(r["diagnostics"]["warning"], "ff"),
        "warning_background": alpha(r["diagnostics"]["warning"], "1a"),
        "warning_border": alpha(p["yellowBright"], "ff"),
        "syntax_attribute": alpha(r["syntax"]["attribute"], "ff"),
        "syntax_boolean": alpha(r["syntax"]["constant"], "ff"),
        "syntax_comment": alpha(r["syntax"]["comment"], "ff"),
        "syntax_constant": alpha(r["syntax"]["constant"], "ff"),
        "syntax_constructor": alpha(r["syntax"]["function"], "ff"),
        "syntax_embedded": alpha(r["syntax"]["text"], "ff"),
        "syntax_enum": alpha(r["syntax"]["type"], "ff"),
        "syntax_function": alpha(r["syntax"]["function"], "ff"),
        "syntax_hint": alpha(r["diagnostics"]["hint"], "ff"),
        "syntax_keyword": alpha(r["syntax"]["keyword"], "ff"),
        "syntax_label": alpha(r["syntax"]["tag"], "ff"),
        "syntax_link_text": alpha(r["syntax"]["link"], "ff"),
        "syntax_link_uri": alpha(r["syntax"]["link"], "ff"),
        "syntax_namespace": alpha(r["syntax"]["namespace"], "ff"),
        "syntax_number": alpha(r["syntax"]["number"], "ff"),
        "syntax_operator": alpha(r["syntax"]["operator"], "ff"),
        "syntax_property": alpha(r["syntax"]["property"], "ff"),
        "syntax_punctuation": alpha(r["syntax"]["punctuation"], "ff"),
        "syntax_punctuation_bracket": alpha(r["syntax"]["punctuation"], "ff"),
        "syntax_punctuation_delimiter": alpha(r["syntax"]["punctuation"], "ff"),
        "syntax_punctuation_special": alpha(r["syntax"]["stringEscape"], "ff"),
        "syntax_string": alpha(r["syntax"]["string"], "ff"),
        "syntax_string_escape": alpha(r["syntax"]["stringEscape"], "ff"),
        "syntax_string_regex": alpha(r["syntax"]["stringEscape"], "ff"),
        "syntax_string_special": alpha(r["syntax"]["stringEscape"], "ff"),
        "syntax_string_special_symbol": alpha(r["syntax"]["constant"], "ff"),
        "syntax_tag": alpha(r["syntax"]["tag"], "ff"),
        "syntax_text_literal": alpha(r["syntax"]["string"], "ff"),
        "syntax_title": alpha(r["syntax"]["tag"], "ff"),
        "syntax_type": alpha(r["syntax"]["type"], "ff"),
        "syntax_variable": alpha(r["syntax"]["variable"], "ff"),
        "syntax_variable_special": alpha(r["syntax"]["property"], "ff"),
        "syntax_variant": alpha(r["syntax"]["function"], "ff"),
    }
    for idx, color in enumerate(players, start=1):
        slots[f"player_{idx}"] = alpha(color, "ff")
        slots[f"player_{idx}_selection"] = alpha(color, "3d")
    return slots


def zed_theme_doc(ctx: dict[str, Any], root: Path) -> dict[str, Any]:
    meta = ctx["meta"]
    appearance = meta["variant"]
    template = load_zed_template(root)
    slots = build_zed_slots(ctx)

    style: dict[str, Any] = {}
    for section in template["style_sections"]:
        for entry in section["entries"]:
            style[entry["key"]] = render_template_value(entry["value"], slots)

    syntax: dict[str, Any] = {}
    for section in template["syntax_sections"]:
        for entry in section["entries"]:
            syntax[entry["key"]] = render_template_value(entry["value"], slots)

    players = [render_template_value(player, slots) for player in template["players"]]

    doc = {
        "$schema": template["theme_family_schema"]["schema_url"],
        "name": meta["name"],
        "author": meta["author"],
        "themes": [
            {
                "name": meta["name"],
                "appearance": appearance,
                "style": {**style, "players": players, "syntax": syntax},
            }
        ],
    }
    validate_zed_theme_doc(doc, root)
    return doc


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def load_nvim_template(root: Path) -> dict[str, Any]:
    template_path = root / "templates" / "nvim" / "official-template.json"
    return load_json(template_path)


def load_nvim_plugin_template(root: Path) -> dict[str, Any]:
    template_path = root / "templates" / "nvim" / "plugins.json"
    return load_json(template_path)


def load_nvim_override(root: Path, theme_id: str) -> dict[str, Any] | None:
    path = root / "overrides" / "nvim" / f"{theme_id}.yaml"
    if not path.exists():
        return None
    return load_yaml(path)


def apply_nvim_override_sections(
    sections: list[dict[str, Any]],
    override: dict[str, Any] | None,
    ctx: dict[str, Any],
    *,
    append_extra: bool = True,
) -> list[dict[str, Any]]:
    if not override:
        return sections

    group_overrides = override.get("groups", {})
    links = override.get("links", {})

    if not isinstance(group_overrides, dict):
        raise RuntimeError("nvim override groups must be a mapping")
    if not isinstance(links, dict):
        raise RuntimeError("nvim override links must be a mapping")

    out: list[dict[str, Any]] = []
    seen_groups: set[str] = set()

    for section in sections:
        new_section = {**section, "groups": []}
        for spec in section["groups"]:
            group = spec["group"]
            attrs = dict(spec["attrs"])

            if group in group_overrides:
                patch = group_overrides[group]
                if not isinstance(patch, dict):
                    raise RuntimeError(f"nvim override for group {group!r} must be a mapping")
                attrs.update(resolve_context_value(patch, ctx))

            if group in links:
                attrs = {"link": resolve_context_value(links[group], ctx)}

            new_section["groups"].append({"group": group, "attrs": attrs})
            seen_groups.add(group)
        out.append(new_section)

    extra_groups: list[dict[str, Any]] = []
    for group, patch in group_overrides.items():
        if group in seen_groups:
            continue
        if not isinstance(patch, dict):
            raise RuntimeError(f"nvim override for group {group!r} must be a mapping")
        extra_groups.append({"group": group, "attrs": resolve_context_value(patch, ctx)})

    for group, target in links.items():
        if group in seen_groups or group in group_overrides:
            continue
        extra_groups.append({"group": group, "attrs": {"link": resolve_context_value(target, ctx)}})

    if append_extra and extra_groups:
        out.append(
            {
                "name": "Override groups",
                "source": "themes/overrides/nvim",
                "groups": extra_groups,
            }
        )

    return out


def nvim_lua(ctx: dict[str, Any], root: Path) -> str:
    meta = ctx["meta"]
    p = ctx["palette"]
    r = ctx["roles"]
    colors_name = meta["id"].replace("-", "_")
    background = meta["variant"]
    is_light = background == "light"
    nvim_template = load_nvim_template(root)
    nvim_plugin_template = load_nvim_plugin_template(root)
    nvim_override = load_nvim_override(root, meta["id"])

    palette_table = {
        "bg": r["ui"]["bg"],
        "bg_float": r["ui"]["bgElevated"],
        "bg_alt": r["ui"]["bgAlt"],
        "border": r["ui"]["border"],
        "hover": raised_surface(r["ui"]["bgAlt"], r["ui"]["border"], light=is_light),
        "selection": mix(r["ui"]["selection"], r["ui"]["bg"], 0.42 if is_light else 0.16),
        "search": soft_background(r["ui"]["search"], r["ui"]["bg"], light=is_light, strength=0.68),
        "search_active": sharpen(r["ui"]["borderActive"], r["ui"]["bg"], light=is_light),
        "fg": r["ui"]["fg"],
        "fg_muted": r["ui"]["fgMuted"],
        "fg_bright": r["ui"]["currentLineNumber"],
        "comment": r["syntax"]["comment"],
        "red": p["red"],
        "orange": p["orange"],
        "yellow": p["yellow"],
        "green": p["green"],
        "cyan": p["cyan"],
        "blue": p["blue"],
        "magenta": p["magenta"],
        "pink": p["pink"],
        "linenr": p["lineNumber"],
        "syntax_text": r["syntax"]["text"],
        "syntax_comment": r["syntax"]["comment"],
        "syntax_string": r["syntax"]["string"],
        "syntax_string_escape": r["syntax"]["stringEscape"],
        "syntax_number": r["syntax"]["number"],
        "syntax_constant": r["syntax"]["constant"],
        "syntax_keyword": r["syntax"]["keyword"],
        "syntax_operator": r["syntax"]["operator"],
        "syntax_variable": r["syntax"]["variable"],
        "syntax_parameter": r["syntax"]["parameter"],
        "syntax_property": r["syntax"]["property"],
        "syntax_field": r["syntax"]["field"],
        "syntax_func": r["syntax"]["function"],
        "syntax_method": r["syntax"]["method"],
        "syntax_type": r["syntax"]["type"],
        "syntax_class": r["syntax"]["class"],
        "syntax_interface": r["syntax"]["interface"],
        "syntax_namespace": r["syntax"]["namespace"],
        "syntax_builtin": r["syntax"]["builtin"],
        "syntax_tag": r["syntax"]["tag"],
        "syntax_attribute": r["syntax"]["attribute"],
        "syntax_punctuation": r["syntax"]["punctuation"],
        "syntax_link": r["syntax"]["link"],
        "diff_add_bg": soft_background(r["vcs"]["added"], r["ui"]["bg"], light=is_light, strength=0.82),
        "diff_change_bg": soft_background(r["vcs"]["modified"], r["ui"]["bg"], light=is_light, strength=0.82),
        "diff_delete_bg": soft_background(r["vcs"]["removed"], r["ui"]["bg"], light=is_light, strength=0.82),
        "diff_text_bg": soft_background(r["ui"]["search"], r["ui"]["bg"], light=is_light, strength=0.74),
        "cursor": r["ui"]["cursor"],
        "none": "NONE",
    }

    def lua_value(value: Any) -> str:
        if isinstance(value, str) and value.startswith("$"):
            return f"p.{value[1:]}"
        if isinstance(value, bool):
            return "true" if value else "false"
        return lua_string(value)

    def lua_opts(opts: dict[str, Any]) -> str:
        return "{ " + ", ".join(f"{key} = {lua_value(value)}" for key, value in opts.items()) + " }"

    lines = [
        f"-- Auto-generated from themes/core/{meta['id']}.yaml",
        f"-- Template: {nvim_template['name']} v{nvim_template['version']}",
        "local M = {}",
        "",
        "local p = {",
    ]
    for key, value in palette_table.items():
        lines.append(f"  {key} = {lua_string(value)},")
    lines.extend(
        [
            "}",
            "",
            "function M.setup()",
            '  vim.cmd("hi clear")',
            '  if vim.fn.exists("syntax_on") then',
            '    vim.cmd("syntax reset")',
            "  end",
            "  vim.o.termguicolors = true",
            f"  vim.o.background = {lua_string(background)}",
            f"  vim.g.colors_name = {lua_string(colors_name)}",
            "",
            "  local hl = function(group, opts)",
            "    vim.api.nvim_set_hl(0, group, opts)",
            "  end",
        ]
    )

    rendered_sections = apply_nvim_override_sections(nvim_template["sections"], nvim_override, ctx)
    rendered_plugin_sections = apply_nvim_override_sections(
        nvim_plugin_template["sections"], nvim_override, ctx, append_extra=False
    )

    for section in rendered_sections:
        lines.append("")
        lines.append(f"  -- {section['name']}")
        for spec in section["groups"]:
            lines.append(f"  hl({lua_string(spec['group'])}, {lua_opts(spec['attrs'])})")

    for section in rendered_plugin_sections:
        lines.append("")
        lines.append(f"  -- Plugin: {section['name']}")
        for spec in section["groups"]:
            lines.append(f"  hl({lua_string(spec['group'])}, {lua_opts(spec['attrs'])})")

    lines.extend(["end", "", "return M"])
    return "\n".join(lines) + "\n"

def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def write_text(path: Path, data: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data)


def generate_theme(theme_path: Path, template: dict[str, Any], root: Path) -> list[Path]:
    theme = load_and_validate_theme(theme_path, template)
    ctx = theme_context(theme)
    theme_id = ctx["meta"]["id"]

    zed_path = root / "exports" / "zed" / f"{theme_id}.json"
    nvim_path = root / "exports" / "nvim" / f"{theme_id}.lua"

    write_json(zed_path, zed_theme_doc(ctx, root))
    write_text(nvim_path, nvim_lua(ctx, root))
    return [zed_path, nvim_path]


def discover_default_targets(root: Path) -> list[Path]:
    return sorted((root / "core").glob("*.yaml"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate theme exports from canonical YAML schema.")
    parser.add_argument("paths", nargs="*", help="Theme YAML files to generate. Defaults to themes/core/*.yaml")
    parser.add_argument("--template", default=None, help="Path to template YAML. Defaults to themes/TEMPLATE.yaml")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent
    template_path = Path(args.template).resolve() if args.template else root / "TEMPLATE.yaml"

    try:
        template = load_yaml(template_path)
    except ParseError as e:
        print(f"error: failed to parse template: {e}", file=sys.stderr)
        return 2

    targets = [Path(p).resolve() for p in args.paths] if args.paths else [p.resolve() for p in discover_default_targets(root)]
    if not targets:
        print("No theme files found to generate.", file=sys.stderr)
        return 2

    generated: list[Path] = []
    for target in targets:
        try:
            generated.extend(generate_theme(target, template, root))
        except Exception as e:  # noqa: BLE001
            print(f"error: failed to generate {target}: {e}", file=sys.stderr)
            return 1

    for path in generated:
        print(path.relative_to(root.parent))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
