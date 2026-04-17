# Theme Schema Draft

This document proposes a canonical theme schema for this repository.

Status: draft
Goal: keep one reusable source of truth under `themes/` that can later be exported to terminal, editor, and UI-specific theme formats.

## Design Goals

- Base24-friendly palette as the foundation
- Additional semantic roles for better editor and UI export quality
- Keep the core schema small, stable, and app-agnostic
- Move application-specific logic into adapters and optional overrides
- Easy to read and edit by hand
- Easy to consume from Nix
- Easy to export to VS Code, terminals, Zed, Neovim, and future targets

## Recommended Directory Layout

```text
themes/
├── SCHEMA.md                  # this document
├── TEMPLATE.yaml              # strict authoring template
├── core/
│   ├── <theme-name>.yaml      # canonical theme definitions
│   └── <theme-name>.yaml
├── exports/
│   ├── vscode/
│   ├── wezterm/
│   ├── ghostty/
│   ├── zed/
│   └── vim/
├── lib/
│   ├── schema.nix             # loader and validators
│   ├── roles.nix              # shared role defaults and fallback rules
│   └── exporters/
│       ├── vscode.nix
│       ├── wezterm.nix
│       ├── ghostty.nix
│       ├── zed.nix
│       └── vim.nix
├── overrides/
│   ├── vscode/
│   │   └── <theme-name>.nix
│   ├── zed/
│   │   └── <theme-name>.nix
│   └── wezterm/
│       └── <theme-name>.nix
└── examples/
    └── theme.example.yaml
```

## Canonical Model

The canonical schema should have 3 layers:

1. `meta`
   - metadata such as name, variant, author, description
2. `palette`
   - raw named colors
   - includes Base24-compatible slots
3. `roles`
   - semantic mapping used by exporters
   - separates UI, syntax, diagnostics, VCS, ANSI

Application-specific settings should not live in the canonical schema.
Those belong in exporters and optional override files outside `core/`.

## Draft YAML Shape

```yaml
version: 1

meta:
  id: tokyo-night-ish
  name: Tokyo Night-ish
  variant: dark        # dark | light
  family: tokyo-night
  author: pylv
  description: Base24-oriented canonical theme schema draft

palette:
  # Base24-compatible base slots
  base00: "#1a1b26"
  base01: "#16161e"
  base02: "#2f3549"
  base03: "#444b6a"
  base04: "#787c99"
  base05: "#a9b1d6"
  base06: "#cbccd1"
  base07: "#d5d6db"
  base08: "#c0caf5"
  base09: "#a9b1d6"
  base0A: "#0db9d7"
  base0B: "#9ece6a"
  base0C: "#b4f9f8"
  base0D: "#2ac3de"
  base0E: "#bb9af7"
  base0F: "#f7768e"
  base10: "#ff9e64"
  base11: "#e0af68"
  base12: "#9ece6a"
  base13: "#b4f9f8"
  base14: "#2ac3de"
  base15: "#bb9af7"
  base16: "#c0caf5"
  base17: "#565f89"

  # Strict alias set. Keep names and order stable across all themes.
  bg: "{palette.base00}"
  bgElevated: "{palette.base01}"
  bgAlt: "{palette.base02}"
  border: "{palette.base03}"
  muted: "{palette.base04}"
  comment: "{palette.base16}"
  fgMuted: "{palette.base04}"
  fg: "{palette.base05}"
  fgBright: "{palette.base06}"
  fgMax: "{palette.base07}"

  red: "{palette.base08}"
  orange: "{palette.base09}"
  yellow: "{palette.base0A}"
  green: "{palette.base0B}"
  cyan: "{palette.base0C}"
  blue: "{palette.base0D}"
  magenta: "{palette.base0E}"
  pink: "{palette.base0F}"

  yellowBright: "{palette.base10}"
  greenBright: "{palette.base11}"
  cyanBright: "{palette.base12}"
  blueBright: "{palette.base13}"
  magentaBright: "{palette.base14}"

  selection: "{palette.base15}"
  lineNumber: "{palette.base16}"
  whitespace: "{palette.base17}"
  blackBright: "{palette.base03}"
  white: "{palette.base07}"

roles:
  ui:
    bg: "{palette.bg}"
    bgAlt: "{palette.bgAlt}"
    bgElevated: "{palette.bgElevated}"
    fg: "{palette.fg}"
    fgMuted: "{palette.fgMuted}"
    border: "{palette.border}"
    borderActive: "{palette.blue}"
    selection: "{palette.selection}"
    selectionInactive: "{palette.bgAlt}"
    currentLine: "{palette.bgElevated}"
    currentLineNumber: "{palette.fgBright}"
    cursor: "{palette.fg}"
    caretText: "{palette.bg}"
    search: "{palette.yellowBright}"
    searchText: "{palette.bg}"
    match: "{palette.border}"
    panelBg: "{palette.bgElevated}"
    sidebarBg: "{palette.bgElevated}"
    statuslineBg: "{palette.bgElevated}"
    statuslineFg: "{palette.fg}"

  syntax:
    text: "{palette.fg}"
    comment: "{palette.comment}"
    string: "{palette.green}"
    stringEscape: "{palette.cyan}"
    number: "{palette.orange}"
    constant: "{palette.orange}"
    keyword: "{palette.magenta}"
    operator: "{palette.fg}"
    variable: "{palette.fg}"
    parameter: "{palette.fg}"
    property: "{palette.red}"
    field: "{palette.red}"
    function: "{palette.blue}"
    method: "{palette.blue}"
    type: "{palette.yellow}"
    class: "{palette.yellow}"
    interface: "{palette.yellow}"
    namespace: "{palette.blue}"
    builtin: "{palette.cyan}"
    tag: "{palette.red}"
    attribute: "{palette.yellow}"
    punctuation: "{palette.fg}"
    link: "{palette.blue}"

  diagnostics:
    error: "{palette.red}"
    warning: "{palette.yellow}"
    info: "{palette.blue}"
    hint: "{palette.cyan}"
    ok: "{palette.green}"

  vcs:
    added: "{palette.green}"
    modified: "{palette.yellow}"
    removed: "{palette.red}"
    renamed: "{palette.blue}"
    conflict: "{palette.orange}"

  ansi:
    black: "{palette.bg}"
    red: "{palette.red}"
    green: "{palette.green}"
    yellow: "{palette.yellow}"
    blue: "{palette.blue}"
    magenta: "{palette.magenta}"
    cyan: "{palette.cyan}"
    white: "{palette.fg}"
    brightBlack: "{palette.blackBright}"
    brightRed: "{palette.pink}"
    brightGreen: "{palette.greenBright}"
    brightYellow: "{palette.yellowBright}"
    brightBlue: "{palette.blueBright}"
    brightMagenta: "{palette.magentaBright}"
    brightCyan: "{palette.cyanBright}"
    brightWhite: "{palette.white}"
```

## Schema Rules

### 1. Required Top-Level Keys

- `version`
- `meta`
- `palette`
- `roles`

There is no app-specific top-level key in the canonical schema.

### 2. Required `meta` Keys

- `id`
- `name`
- `variant`

Optional:

- `family`
- `author`
- `description`

### 3. Required `palette` Keys

At minimum, require Base24-compatible slots:

- `base00` through `base17`

Use the strict alias set from `themes/TEMPLATE.yaml`.
Do not add extra alias names casually, and prefer keeping alias names and ordering identical across all theme files.

### 4. Required `roles` Groups

- `ui`
- `syntax`
- `diagnostics`
- `vcs`
- `ansi`

Not every leaf must be required on day 1, but exporters should have shared fallback logic.

## Role Naming Conventions

### General naming rules

- use short semantic names, not target-specific names
- use lower camelCase for role leaf names
- avoid app vocabulary like `activityBar`, `gutter`, `tabBar`, `titleBar`
- prefer meaning over rendering detail
- a role name should make sense across at least 2 target families

Good examples:

- `ui.bg`
- `ui.bgElevated`
- `ui.selection`
- `syntax.comment`
- `syntax.function`
- `diagnostics.error`
- `vcs.added`

Bad examples:

- `ui.activityBarBackground`
- `ui.editorGutterModified`
- `ui.tabInactiveForeground`
- `syntax.textmateKeywordControl`

### Role group intent

#### `ui`

Use for shared interface roles that many apps have in some form.

Recommended leaves:

- `bg`
- `bgAlt`
- `bgElevated`
- `fg`
- `fgMuted`
- `border`
- `borderActive`
- `selection`
- `selectionInactive`
- `currentLine`
- `currentLineNumber`
- `cursor`
- `caretText`
- `search`
- `searchText`
- `match`
- `panelBg`
- `sidebarBg`
- `statuslineBg`
- `statuslineFg`

#### `syntax`

Use for language and markup meaning, not parser-specific scope systems.

Recommended leaves:

- `text`
- `comment`
- `string`
- `stringEscape`
- `number`
- `constant`
- `keyword`
- `operator`
- `variable`
- `parameter`
- `property`
- `field`
- `function`
- `method`
- `type`
- `class`
- `interface`
- `namespace`
- `builtin`
- `tag`
- `attribute`
- `punctuation`
- `link`

#### `diagnostics`

Use for editor and tooling feedback states.

Recommended leaves:

- `error`
- `warning`
- `info`
- `hint`
- `ok`

#### `vcs`

Use for version control or diff meaning.

Recommended leaves:

- `added`
- `modified`
- `removed`
- `renamed`
- `conflict`

#### `ansi`

Use for terminal palette export only.

Recommended leaves:

- `black`
- `red`
- `green`
- `yellow`
- `blue`
- `magenta`
- `cyan`
- `white`
- `brightBlack`
- `brightRed`
- `brightGreen`
- `brightYellow`
- `brightBlue`
- `brightMagenta`
- `brightCyan`
- `brightWhite`

## Shared Rules

### 1. Semantic first

When choosing a role, prefer semantic meaning over source palette ancestry.
For example:

- comments should map to `syntax.comment` even if they come from `base16`
- current-line highlight should map to `ui.currentLine` even if one app calls it `lineHighlight`

### 2. Promote only shared meaning

A role should be added to the core schema only if:

- it appears useful across multiple targets, or
- it captures a stable semantic concept, not just one app's option name

If it only helps one app, keep it in exporter logic or an override file.

### 3. Prefer derivation over duplication

If a role can be cleanly derived from another role or from the palette, do not add a new core role yet.
Examples:

- `panelBg` can often derive from `bgElevated`
- `selectionInactive` can often derive from `bgAlt` or `selection`

### 4. Keep contrast semantics stable

Across both light and dark themes, the intended meaning should remain stable:

- `bg` is the primary surface
- `bgElevated` is the raised or floating surface
- `fg` is the primary readable foreground
- `fgMuted` is secondary readable foreground
- `comment` is quieter than `text`
- `selection` must remain visibly distinct from `bg`

### 5. Do not encode typography or effects into role names

Use color roles for color meaning only.
Do not create names like:

- `commentItalic`
- `errorUnderline`
- `strongBold`

Style details such as italic, bold, underline, or opacity should be handled by exporters or a future separate styling layer.

### 6. Light and dark themes use the same role contract

Do not rename roles based on variant.
Only the color assignments change.
For example, both light and dark themes should expose the same role names such as:

- `ui.bg`
- `ui.fg`
- `syntax.keyword`
- `diagnostics.warning`

### 7. Alias palette names are helpers, not the contract

Names like `red`, `blue`, `fg`, `bg`, or `comment` in `palette` are convenience aliases.
The stable public contract for exporters is the `roles` section.

## Authoring Rules

When creating a new theme file:

1. start from `themes/TEMPLATE.yaml`
2. keep top-level key order exactly as shown in the template
3. keep alias names and role names exactly as shown in the template
4. prefer palette or alias references over raw hex in `roles`
5. only use raw hex in `roles` when a theme truly needs a value that should not become a shared alias
6. keep the same leaf ordering in each role group as the template
7. if a value is theme-specific but the role name is shared, change only the value, not the structure
8. if you think a new alias or role is needed, update `SCHEMA.md` and `TEMPLATE.yaml` first

In short, `SCHEMA.md` defines the rules and `TEMPLATE.yaml` defines the exact authoring shape.

Validation helper:

```bash
python themes/validate.py
python themes/validate.py themes/core/one-half-light.yaml
```

Override validation helper:

```bash
python themes/validate_overrides.py
python themes/validate_overrides.py themes/overrides/nvim/rose-pine.yaml
```

Generation helper:

```bash
python themes/generate.py
python themes/generate.py themes/core/one-half-light.yaml
```

Template consistency helper:

```bash
python themes/check_templates.py
```

This now checks both:

- app template JSON files under `themes/templates/`
- override template/current override YAML files under `themes/overrides/`

Current generators:

- `zed` -> `themes/exports/zed/*.json`
- `nvim` -> `themes/exports/nvim/*.lua`
- `rio` -> `themes/exports/rio/*.toml`

Adapter templates and schema helpers:

- `themes/templates/zed/schema-v0.2.0.json` -> vendored official Zed theme JSON Schema
- `themes/templates/zed/official-template.json` -> Zed official template split into `style_sections`, `syntax_sections`, and `players`
  - note: Zed's official schema strictly enumerates outer `style` keys, but `style.syntax` remains open-ended and is validated as `HighlightStyleContent` entries rather than a fixed syntax-key list
- `themes/templates/nvim/official-template.json` -> Neovim builtin highlight template derived from official help
- `themes/templates/nvim/plugins.json` -> Neovim plugin-specific highlight template
- `themes/templates/rio/official-template.json` -> Rio Terminal color template derived from the official Rio config color contract
- `themes/check_templates.py` -> consistency check for app template metadata, contract fields, section layout, duplicate entries, and declared key coverage

## Resolution Rules

Exporters should resolve values in this order:

1. per-app override outside the core schema
2. `roles.*`
3. `palette.*`
4. exporter fallback defaults

This keeps app-specific tweaks possible without weakening the canonical schema.

## Core vs Adapter Boundary

### What belongs in the core schema

Only values that are:

- cross-application
- semantic rather than app-key specific
- likely to be reused by multiple exporters
- stable over time

Examples:

- `roles.ui.bg`
- `roles.ui.selection`
- `roles.syntax.comment`
- `roles.syntax.string`
- `roles.syntax.function`
- `roles.diagnostics.error`
- `roles.vcs.added`
- `roles.ansi.red`

### What should stay out of the core schema

App-specific keys and layout details that are really just target configuration.

Examples:

- VS Code `activityBarBadge.background`
- VS Code `editorGutter.modifiedBackground`
- WezTerm tab bar edge colors
- Zed title bar or player-specific UI fragments
- any exact output key that only one target understands

Those belong in:

- exporter logic, when the mapping is generally derivable from roles
- per-app override files, when the target needs manual tuning

## Why This Structure

### Why Base24 as the palette base

- strong compatibility with terminal-oriented theming
- easy ANSI mapping
- existing ecosystem and mental model
- enough slots to avoid overloading the original Base16 meanings too hard

### Why not only Base24 slots

Base24 slots alone are not expressive enough for:

- VS Code workbench colors
- semantic token colors
- diagnostics and VCS states
- future non-terminal UI theming

That is why `roles` should be first-class.

### Why not keep app-specific config in the core

Because it tends to:

- pollute the canonical schema with transient target details
- make the source of truth harder to understand
- force app vocabulary into a supposedly shared model
- create pressure to add more one-off keys over time

A small stable core plus adapters is easier to maintain.

### Why YAML

- readable in reviews
- friendly for hand editing
- easy to load from Nix
- easy to transform into JSON outputs

## Override Strategy

Default rule:

- do not write per-app settings into `themes/core/*.yaml`

Instead use this progression:

1. derive from `roles`
2. fallback to `palette`
3. if still not good enough, add a small override file in `themes/overrides/<app>/`

This keeps exceptions visible and isolated.

Current override support:

- `themes/overrides/SCHEMA.md` -> override-layer format notes
- `themes/overrides/TEMPLATE.yaml` -> minimal authoring template
- `themes/overrides/nvim/<theme-id>.yaml` -> Neovim per-theme override patches
- `themes/validate_overrides.py` -> override validator for current Neovim override files

Current Neovim override precedence:

1. rendered template attrs
2. `groups.<highlight-group>` patch merge
3. `links.<highlight-group>` replacement

Use overrides for app-specific exceptions like:

- matching an official app theme more closely for one theme only
- correcting interaction colors such as search, selection, or float emphasis
- nudging exact highlight groups without changing canonical roles

## Export Targets to Support First

Suggested first exporters:

1. `wezterm`
2. `ghostty`
3. `zed`
4. `vscode`
5. `vim`

Rationale:

- terminal targets are the easiest validation path for Base24 alignment
- Zed and VS Code benefit most from semantic roles
- Vim or Neovim can initially consume generated Lua tables or theme fragments

## Suggested Nix API Shape

Possible helper API under `themes/lib/`:

```nix
{
  loadTheme = path: ...;
  validateTheme = theme: ...;
  exportTheme = {
    theme,
    target,
    override ? null,
  }: ...;
}
```

Possible flake-facing structure later:

```nix
{
  themes = {
    tokyo-night-ish = import ./themes/core/tokyo-night-ish.yaml;
  };
}
```

Or better, expose generated outputs:

```nix
{
  themeExports.vscode.tokyo-night-ish = ...;
  themeExports.wezterm.tokyo-night-ish = ...;
}
```

## Open Questions

- whether aliases like `bg`, `fg`, `red`, `blue` should be required or derived
- whether references like `{palette.base00}` should be supported literally or resolved by Nix-only logic
- whether override files should be plain attrsets or functions over the loaded theme
- whether font, opacity, and spacing hints belong in this schema or a separate appearance schema
- whether light themes need additional constraints for contrast validation
- how strict the validator should be about required role leaves in v1

## Current Recommendation

Adopt this approach:

- canonical source of truth: `themes/core/*.yaml`
- required base palette: Base24-compatible slots
- required semantic layer: `roles`
- app-specific behavior lives in exporters and optional override files
- shared exporter fallback logic in Nix

In short:

- Base24 gives us portability
- semantic roles give us quality
- adapters keep the core clean
- optional overrides keep edge cases manageable
