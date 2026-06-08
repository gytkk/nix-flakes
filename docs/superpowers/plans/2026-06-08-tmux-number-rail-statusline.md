# tmux Number Rail Statusline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the tmux window list with the selected Number Rail design: quiet inactive windows, an accent-colored current window number, and a bold current window title.

**Architecture:** Keep the existing tmux module shape. The fallback config in `modules/tmux/files/statusline.conf` and the canonical tmux theme generator in `themes/generate.py` must emit the same window-list layout. Generated theme exports under `themes/exports/tmux/` remain checked in and are regenerated from the canonical theme pipeline.

**Tech Stack:** tmux format strings, Python theme generator, Python `unittest`, canonical YAML theme exports, Home Manager-managed config files.

---

## Scope Check

This is one focused tmux statusline visual change. It does not change tmux keybindings, the `tm` session manager, the session/prefix/sync status segments, or any non-tmux theme exporter.

## File Structure

- Modify: `themes/test_tmux_generator.py`
  - Responsibility: assert that the tmux exporter emits the Number Rail window formats.
- Modify: `themes/generate.py`
  - Responsibility: build canonical tmux statusline slots for every theme export.
- Modify: `modules/tmux/files/statusline.conf`
  - Responsibility: provide a working fallback when `~/.config/tmux/theme.conf` is unavailable.
- Modify generated files: `themes/exports/tmux/*.conf`
  - Responsibility: checked-in app-ready tmux theme artifacts generated from `themes/core/*.yaml`.
- Do not stage: `.superpowers/`
  - Reason: browser mockup session files are local brainstorming artifacts, not repo documentation.

## Design Contract

The final window list should follow this visual contract:

- Inactive windows use the normal statusline background and muted foreground.
- The active window number uses the theme accent already used for the session segment.
- The active window name uses the normal statusline foreground and bold weight.
- The separator remains empty through `set -g window-status-separator ''`.
- `#F` remains attached to the window name so tmux flags such as modified/activity indicators still render.
- Avoid Powerline glyphs, rounded glyphs, or Nerd Font-specific characters.

For the default `vira-graphene` theme, the generated values should be:

```tmux
setw -g window-status-format '#[fg=#545454]#[bg=#212121] #I #W#F #[default]'
setw -g window-status-current-format '#[fg=#82AAFF]#[bg=#212121]#[bold] #I #[fg=#D9D9D9]#[bg=#212121]#[bold]#W#F #[default]'
```

---

### Task 1: Add Failing Generator Coverage

**Files:**
- Modify: `themes/test_tmux_generator.py`

- [ ] **Step 1: Add Number Rail assertions**

In `themes/test_tmux_generator.py`, inside `test_prefix_state_uses_session_accent_and_conditional_help_without_clock`, insert these assertions after the existing `status_right` assertion:

```python
        self.assertEqual(
            "#[fg=#545454]#[bg=#212121] #I #W#F #[default]",
            slots["window_status_format"],
        )
        self.assertEqual(
            "#[fg=#82AAFF]#[bg=#212121]#[bold] #I #[fg=#D9D9D9]#[bg=#212121]#[bold]#W#F #[default]",
            slots["window_status_current_format"],
        )
        self.assertIn(" #I #W#F ", theme_conf)
        self.assertIn(" #I #[fg=#D9D9D9]", theme_conf)
        self.assertNotIn("#I:#W#F", theme_conf)
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
uv run themes/test_tmux_generator.py
```

Expected: FAIL. The failure should show the current colon-based window format, including `#I:#W#F`, where the test expects the Number Rail spacing.

---

### Task 2: Update the tmux Theme Generator

**Files:**
- Modify: `themes/generate.py`
- Test: `themes/test_tmux_generator.py`

- [ ] **Step 1: Replace the tmux slot builder**

In `themes/generate.py`, replace the entire `build_tmux_slots` function with:

```python
def build_tmux_slots(ctx: dict[str, Any]) -> dict[str, str]:
    p = ctx["palette"]
    r = ctx["roles"]
    status_bg = r["ui"]["statuslineBg"]
    status_fg = r["ui"]["statuslineFg"]
    session_bg = r["ui"]["borderActive"]
    prefix_bg = r["diagnostics"]["error"]
    sync_bg = r["diagnostics"]["warning"]
    current_index_fg = session_bg
    session_fg = best_contrast(session_bg, p["white"], r["ui"]["bg"], r["ui"]["fg"])
    prefix_fg = best_contrast(prefix_bg, p["white"], r["ui"]["bg"], r["ui"]["fg"])
    sync_fg = best_contrast(sync_bg, p["white"], r["ui"]["bg"], r["ui"]["fg"])
    normal_session = f"{tmux_style(fg=session_fg, bg=session_bg, bold=True)} #S #[default]"
    prefix_session = f"{tmux_style(fg=prefix_fg, bg=prefix_bg, bold=True)} #S #[default]"
    status_left = (
        f"#{{?client_prefix,{prefix_session},{normal_session}}}"
        f"#{{?pane_synchronized,{tmux_style(fg=sync_fg, bg=sync_bg, bold=True)} SYNC #[default],}}"
    )
    status_right = f"#{{?client_prefix,{tmux_style(fg=status_fg)} ? help | w tree | s sessions #[default],}}"
    window_status = f"{tmux_style(fg=r['ui']['fgMuted'], bg=status_bg)} #I #W#F #[default]"
    current_window = (
        f"{tmux_style(fg=current_index_fg, bg=status_bg, bold=True)} #I "
        f"{tmux_style(fg=status_fg, bg=status_bg, bold=True)}#W#F #[default]"
    )
    return {
        "status_style": f"fg={status_fg},bg={status_bg}",
        "status_left": status_left,
        "status_right": status_right,
        "window_status_format": window_status,
        "window_status_current_format": current_window,
    }
```

The resulting `build_tmux_slots` should no longer define `is_light`, `current_bg`, or `current_fg`, because the Number Rail design does not use a filled current-window background.

- [ ] **Step 2: Run the focused generator test**

Run:

```bash
uv run themes/test_tmux_generator.py
```

Expected: PASS and output equivalent to:

```text
.
----------------------------------------------------------------------
Ran 1 test in 0.0

OK
```

---

### Task 3: Update the Fallback tmux Config

**Files:**
- Modify: `modules/tmux/files/statusline.conf`

- [ ] **Step 1: Replace the fallback window formats**

In `modules/tmux/files/statusline.conf`, replace the two `window-status` lines with:

```tmux
setw -g window-status-format '#[fg=colour244,bg=colour234] #I #W#F #[default]'
setw -g window-status-current-format '#[fg=colour39,bg=colour234,bold] #I #[fg=colour250,bg=colour234,bold]#W#F #[default]'
```

- [ ] **Step 2: Verify the fallback no longer uses colon formatting**

Run:

```bash
rg -n "#I:#W#F" modules/tmux/files/statusline.conf
```

Expected: exit status `1` with no output.

- [ ] **Step 3: Verify the fallback contains Number Rail spacing**

Run:

```bash
rg -n "#I #W#F|#I #\\[fg=colour250" modules/tmux/files/statusline.conf
```

Expected: two matches, one for `window-status-format` and one for `window-status-current-format`.

---

### Task 4: Regenerate tmux Theme Exports

**Files:**
- Modify generated files: `themes/exports/tmux/ayu-mirage.conf`
- Modify generated files: `themes/exports/tmux/catppuccin-mocha.conf`
- Modify generated files: `themes/exports/tmux/monokai-pro-classic.conf`
- Modify generated files: `themes/exports/tmux/one-half-light.conf`
- Modify generated files: `themes/exports/tmux/rose-pine-moon.conf`
- Modify generated files: `themes/exports/tmux/vira-graphene.conf`

- [ ] **Step 1: Regenerate all canonical theme exports**

Run:

```bash
uv run themes/generate.py
```

Expected: command exits `0` and prints generated export paths. The printed list should include each `themes/exports/tmux/*.conf` file.

- [ ] **Step 2: Verify no generated tmux export uses colon formatting**

Run:

```bash
rg -n "#I:#W#F" themes/exports/tmux
```

Expected: exit status `1` with no output.

- [ ] **Step 3: Verify generated tmux exports contain Number Rail formats**

Run:

```bash
rg -n "#I #W#F|#I #\\[fg=" themes/exports/tmux
```

Expected: each generated tmux theme file has two relevant matches: one inactive window format and one current window format.

---

### Task 5: Final Verification and Commit

**Files:**
- Verify: `themes/test_tmux_generator.py`
- Verify: `themes/generate.py`
- Verify: `modules/tmux/files/statusline.conf`
- Verify: `themes/exports/tmux/*.conf`

- [ ] **Step 1: Run the focused Python test**

Run:

```bash
uv run themes/test_tmux_generator.py
```

Expected: PASS.

- [ ] **Step 2: Run a diff whitespace check**

Run:

```bash
git diff --check
```

Expected: no output and exit status `0`.

- [ ] **Step 3: Review the implementation diff**

Run:

```bash
git diff -- themes/test_tmux_generator.py themes/generate.py modules/tmux/files/statusline.conf themes/exports/tmux
```

Expected:

- `themes/test_tmux_generator.py` asserts the Number Rail strings.
- `themes/generate.py` uses statusline background for all window entries and accent foreground for the current window number.
- `modules/tmux/files/statusline.conf` matches the generated layout with 256-color fallback values.
- `themes/exports/tmux/*.conf` are regenerated from the canonical pipeline.
- No `.superpowers/` files appear in the diff.

- [ ] **Step 4: Confirm the worktree only contains intentional implementation files**

Run:

```bash
git status --short
```

Expected: modified entries only for:

```text
 M modules/tmux/files/statusline.conf
 M themes/generate.py
 M themes/test_tmux_generator.py
 M themes/exports/tmux/ayu-mirage.conf
 M themes/exports/tmux/catppuccin-mocha.conf
 M themes/exports/tmux/monokai-pro-classic.conf
 M themes/exports/tmux/one-half-light.conf
 M themes/exports/tmux/rose-pine-moon.conf
 M themes/exports/tmux/vira-graphene.conf
```

- [ ] **Step 5: Commit the Number Rail statusline change**

Run:

```bash
git add modules/tmux/files/statusline.conf themes/generate.py themes/test_tmux_generator.py themes/exports/tmux/*.conf
git commit -m "feat: refine tmux window statusline"
```

Expected: one local commit containing only the tmux Number Rail statusline implementation and regenerated tmux exports.
