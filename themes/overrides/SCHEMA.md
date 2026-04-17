# Theme Overrides

Overrides are app-specific patches applied after the canonical core and app template have already been resolved.

Use overrides when:

- the canonical `themes/core/*.yaml` roles are still correct overall
- an app has target-specific highlight semantics or UX expectations
- a specific theme needs a small amount of manual tuning for one app

Do not use overrides to redefine the canonical theme core.

## Current support

- `themes/overrides/nvim/<theme-id>.yaml`
- `python themes/validate_overrides.py`
- `python themes/check_templates.py` now also checks override template/current override file structure

## Resolution order

For Neovim exports, values resolve in this order:

1. rendered template defaults
2. override `groups.<group>` patch
3. override `links.<group>` replacement

If a link override exists for a group, it replaces the final attrs table for that group.

## Neovim override format

```yaml
version: 1

meta:
  app: nvim
  theme: rose-pine
  variant: dark

groups:
  CurSearch:
    fg: "{roles.ui.bg}"
    bg: "{palette.magenta}"
  IncSearch:
    fg: "{roles.ui.bg}"
    bg: "{palette.magenta}"

links:
  @constructor: "@type"
```

## Supported value forms

Override values may be:

- literal strings like `"#403d52"` or `"@type"`
- palette refs like `"{palette.magenta}"`
- role refs like `"{roles.syntax.function}"`
- scalar booleans written as `true` / `false`
- `null`

## Notes

- use plain YAML keys for highlight groups, including names like `@function` or `@constructor`; do not quote the key names in this repo's minimal YAML format
- `groups` patches merge into the existing generated attrs for a group.
- `links` replace the group attrs with `{ link = ... }`.
- unknown groups are appended as an extra override section at the end of the generated Neovim output.
- templates remain the official/default contract; overrides are the narrow exception layer.
