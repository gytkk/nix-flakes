# tmux Zellij-Style Mode UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans`
> or `superpowers:subagent-driven-development` to implement this plan
> task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show tmux's current interaction mode and the most relevant keys in a
second status line, using only native tmux configuration.

**Architecture:** Keep `modules/tmux/default.nix` as the only implementation
file and add a small `extraConfig` block on top of the Home Manager tmux module
defaults. Use tmux format variables for live mode detection and a custom
`window-mode` key table for the Zellij-style window action layer.

**Tech Stack:** Nix Home Manager tmux module, tmux 3.6a native key tables,
tmux status formats.

---

## Current Baseline

The current `modules/tmux/default.nix` has no custom `extraConfig`.

```nix
{ ... }:

{
  programs.tmux = {
    enable = true;
    prefix = "C-b";
    terminal = "tmux-256color";
    keyMode = "vi";
    mouse = true;
    focusEvents = true;
    historyLimit = 100000;
    clock24 = true;
  };
}
```

Verified baseline from the generated tmux config:

- `extraConfig` is empty.
- tmux defaults keep `status-position bottom`; this plan changes it to `top`.
- `C-b ?` already runs `list-keys -N`.
- `C-b w` already runs `choose-tree -Zw`.
- `C-b c` already creates a window.
- `C-b ,` already renames the current window.
- `C-b r` is tmux's default `refresh-client`, not a reload binding.
- There is no current custom `C-b h` help menu to preserve.
- In `copy-mode-vi`, `/` and `n` already search, `Space` starts selection,
  `q` cancels, and `v` is rectangle toggle by default.

## Scope

- Modify: `modules/tmux/default.nix`
- Modify: `README.md`
- Use tmux native features only.
- Do not add tmux plugins, TPM, byobu, fzf palettes, or dynamic scripts.
- Do not add pane/session/resize modes in this pass.
- Do not bind global `C-w` by default because it steals `Ctrl-w` from shells,
  Vim/Neovim, and other terminal applications running inside tmux.

## UX Requirements

1. `C-b W` enters a custom `window-mode` key table.
2. While `window-mode` is active, the second status line shows `WINDOW` and the
   available window-mode keys.
3. While tmux prefix is active, the second status line shows `PREFIX` and the
   most useful existing prefix keys.
4. While the active pane is in copy mode, the second status line shows `COPY`
   and copy-mode keys that match tmux's vi-mode defaults.
5. In normal state, the second status line shows a compact hint set.
6. Existing tmux defaults such as `C-b ?`, `C-b w`, `C-b c`, `C-b ,`, and
   copy-mode search must continue to work.

## Status-Line Design

Keep the status line at the top and make it two rows:

- Row 1: session/window context and clock.
- Row 2: active mode and key hints.

Mode priority:

1. copy mode, detected with `#{==:#{pane_mode},copy-mode}`.
2. custom window mode, detected with `#{==:#{client_key_table},window-mode}`.
3. prefix state, detected with `#{client_prefix}`.
4. normal state.

Do not use `pane_in_mode` alone for copy-mode detection. `choose-tree` also sets
`pane_in_mode=1` while `pane_mode=tree-mode`, so it would be mislabeled as
`COPY`.

## File Structure

- `modules/tmux/default.nix`: add `modeHintStatus` and `extraConfig`.
- `README.md`: update the tmux config section to describe the two-line status
  UI and `C-b W` window mode.

## Task 1: Add the Mode Hint Status String

**Files:**

- Modify: `modules/tmux/default.nix`

- [ ] **Step 1: Add `modeHintStatus` to the `let` block**

Replace the top-level module shape with a `let` binding:

```nix
{ ... }:

let
  modeHintStatus =
    "#[align=left]"
    + "#{?#{==:#{pane_mode},copy-mode},#[fg=colour16#,bg=colour42#,bold] COPY #[default] Space:select y:yank /:search n:next q:exit,"
    + "#{?#{==:#{client_key_table},window-mode},#[fg=colour16#,bg=colour39#,bold] WINDOW #[default] c:new ,:rename h/l:prev/next w:tree x:kill Esc:exit,"
    + "#{?client_prefix,#[fg=colour16#,bg=colour214#,bold] PREFIX #[default] ?:keys w:tree c:new ,:rename %/\":split [:copy,"
    + "#[fg=colour245] C-b W window | C-b ? keys | C-b w tree}}}";
in
{
  programs.tmux = {
```

Expected:

- `modeHintStatus` is a plain Nix string, not an indented multiline string.
- The generated tmux status format has no trailing newline.
- The `COPY` hint follows tmux's current vi copy-mode defaults.

- [ ] **Step 2: Run Nix evaluation**

Run:

```bash
nix eval --raw '.#homeConfigurations.pylv-sepia.config.programs.tmux.extraConfig'
```

Expected:

- Command succeeds.
- Output may still be empty until Task 2 adds `extraConfig`.

## Task 2: Configure the Two-Line Status

**Files:**

- Modify: `modules/tmux/default.nix`

- [ ] **Step 1: Add `extraConfig` status settings**

Inside `programs.tmux`, add:

```nix
    extraConfig = ''
      set -g status on
      set -g status 2
      set -g status-position top
      set -g status-interval 5
      set -g status-left-length 60
      set -g status-right-length 80
      set -g status-style "bg=colour236,fg=colour248"
      set -g status-left "#[fg=colour16,bg=colour39,bold] #S #[fg=colour39,bg=colour236,nobold] "
      set -g status-right "#[fg=colour39]%Y-%m-%d %H:%M "
      setw -g window-status-format " #I:#W#{?window_flags,#{window_flags},} "
      setw -g window-status-current-format "#[fg=colour16,bg=colour248,bold] #I:#W#{?window_flags,#{window_flags},} #[default]"
      set -g status-format[1] "${modeHintStatus}"
    '';
```

Expected:

- Row 1 keeps session/window/clock context.
- Row 2 is reserved for mode hints.
- The old custom discovery text is not duplicated in `status-right`.

- [ ] **Step 2: Verify generated config text**

Run:

```bash
nix eval --raw '.#homeConfigurations.pylv-sepia.config.programs.tmux.extraConfig'
```

Expected output contains:

```tmux
set -g status 2
set -g status-position top
set -g status-format[1]
COPY
WINDOW
PREFIX
```

## Task 3: Add Prefix-Based Window Mode

**Files:**

- Modify: `modules/tmux/default.nix`

- [ ] **Step 1: Add `window-mode` bindings**

Append these bindings inside the existing `extraConfig` string:

```tmux
      bind-key W switch-client -T window-mode
      bind-key -T window-mode c new-window -c "#{pane_current_path}"
      bind-key -T window-mode , command-prompt -I "#W" "rename-window -- %%"
      bind-key -T window-mode h previous-window
      bind-key -T window-mode l next-window
      bind-key -T window-mode w choose-tree -Zw
      bind-key -T window-mode x confirm-before -p "kill-window #W? (y/n)" kill-window
      bind-key -T window-mode Escape display-message "normal mode"
```

Expected:

- `C-b W` enters `window-mode`.
- `Ctrl-w` remains available to shells, Vim/Neovim, and terminal applications.
- Existing `C-b w` still opens tmux's default window tree.

- [ ] **Step 2: Verify generated key bindings**

Run:

```bash
conf=$(nix eval --raw '.#homeConfigurations.pylv-sepia.config.xdg.configFile."tmux/tmux.conf".source')
socket="tmux-zellij-mode-plan-keys"
tmux -L "$socket" -f "$conf" new-session -d -s plan-test
tmux -L "$socket" list-keys -T prefix | rg 'bind-key +(-r +)?-T prefix (W|w|\?|c|,) '
tmux -L "$socket" list-keys -T window-mode
tmux -L "$socket" kill-server
```

Expected:

- Prefix table contains `W`, `w`, `?`, `c`, and `,`.
- `window-mode` contains `c`, `,`, `h`, `l`, `w`, `x`, and `Escape`.

## Task 4: Leave Copy-Mode Defaults Intact

**Files:**

- Modify: `modules/tmux/default.nix`

- [ ] **Step 1: Do not add custom copy-mode bindings**

No implementation change is needed for copy-mode in this pass.

Expected:

- `/` and `n` continue to use tmux's default vi copy-mode search bindings.
- `Space` remains begin-selection.
- `v` remains rectangle toggle unless a later task explicitly changes copy-mode
  semantics.

- [ ] **Step 2: Verify copy-mode defaults from generated config**

Run:

```bash
conf=$(nix eval --raw '.#homeConfigurations.pylv-sepia.config.xdg.configFile."tmux/tmux.conf".source')
socket="tmux-zellij-mode-plan-copy"
tmux -L "$socket" -f "$conf" new-session -d -s plan-test
tmux -L "$socket" list-keys -T copy-mode-vi | rg 'search-forward|search-again|begin-selection|rectangle-toggle|cancel'
tmux -L "$socket" kill-server
```

Expected:

- Output includes `/` search-forward.
- Output includes `n` search-again.
- Output includes `Space` begin-selection.
- Output includes `v` rectangle-toggle.

## Task 5: Parse and Behavior Smoke Tests

**Files:**

- Modify: `modules/tmux/default.nix`

- [ ] **Step 1: Format Nix**

Run:

```bash
nixfmt modules/tmux/default.nix
```

Expected:

- Command exits 0.
- Formatting changes, if any, are limited to `modules/tmux/default.nix`.

- [ ] **Step 2: Parse generated tmux config in an isolated server**

Run:

```bash
conf=$(nix eval --raw '.#homeConfigurations.pylv-sepia.config.xdg.configFile."tmux/tmux.conf".source')
socket="tmux-zellij-mode-plan-parse"
tmux -L "$socket" -f "$conf" new-session -d -s plan-test
tmux -L "$socket" show -g status
tmux -L "$socket" show -g status-position
tmux -L "$socket" show -g 'status-format[1]'
tmux -L "$socket" kill-server
```

Expected:

- `status` is `2`.
- `status-position` is `top`.
- `status-format[1]` contains `COPY`, `WINDOW`, and `PREFIX`.

- [ ] **Step 3: Verify tree-mode is not labeled as copy-mode**

Run:

```bash
socket="tmux-zellij-mode-plan-tree"
tmux -L "$socket" -f /dev/null new-session -d -s plan-test
tmux -L "$socket" set -g 'status-format[1]' '#{?#{==:#{pane_mode},copy-mode},COPY,not-copy}'
tmux -L "$socket" choose-tree -Zw
tmux -L "$socket" display-message -p '#{pane_mode}:#{?#{==:#{pane_mode},copy-mode},COPY,not-copy}'
tmux -L "$socket" kill-server
```

Expected:

```text
tree-mode:not-copy
```

## Task 6: Update Documentation

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Update the `tmux config` section**

Replace the existing tmux bullets with text that matches the new baseline and
feature:

```markdown
- tmux is managed through `modules/tmux/default.nix`.
- Home Manager installs tmux for every shared environment and writes
  `~/.config/tmux/tmux.conf`.
- The checked-in defaults keep `Ctrl+b` as the tmux prefix, enable mouse
  support and vi copy mode, and use a two-line top status area.
- The first status line shows session/window context and the clock; the second
  line shows the active tmux mode plus available keys.
- Press `Ctrl+b W` to enter window mode. The hint line shows actions such as
  `c` for new window, `,` for rename, `h/l` for previous/next, and `w` for tree.
- Existing tmux defaults such as `Ctrl+b ?`, `Ctrl+b w`, `Ctrl+b c`, and
  `Ctrl+b ,` remain available.
```

- [ ] **Step 2: Check markdown diff**

Run:

```bash
git diff -- README.md TMUX_ZELLIJ_MODE_UI_PLAN.md modules/tmux/default.nix
```

Expected:

- README changes only describe the tmux mode UI.
- `C-b h` appears only as an explicitly excluded custom help menu.
- The plan no longer uses global `Ctrl-w`.

## Task 7: Commit the Implementation

**Files:**

- Modify: `modules/tmux/default.nix`
- Modify: `README.md`

- [ ] **Step 1: Check final status**

Run:

```bash
git status --short
```

Expected:

- Only intentional files for this work are modified.

- [ ] **Step 2: Commit**

Run:

```bash
git add modules/tmux/default.nix README.md
git commit -m "feat(tmux): add zellij-style mode hints"
```

Expected:

- Commit succeeds.
- The plan file is committed separately only if it changed as part of planning.

## Manual Verification Checklist

- [ ] New tmux session shows a two-line status area at the top.
- [ ] Normal state shows compact hints.
- [ ] Pressing `C-b` shows the `PREFIX` hint.
- [ ] Pressing `C-b W` shows the `WINDOW` hint.
- [ ] In window mode, `c` creates a new window.
- [ ] In window mode, `,` opens the rename prompt.
- [ ] In window mode, `h/l` moves between windows.
- [ ] In window mode, `w` opens the window tree.
- [ ] `C-b w` still opens the default window tree.
- [ ] `C-b ?` still shows tmux key help.
- [ ] Copy mode shows the `COPY` hint.
- [ ] Tree mode is not mislabeled as `COPY`.

## Explicitly Excluded

- Global `Ctrl-w` binding.
- Custom `C-b h` help menu.
- Custom reload binding on `C-b r`.
- Copy-mode key remapping.
- tmux plugin manager.
- byobu.
- fzf command palette.
- Pane, session, and resize modes.
- Large theme refactor.
- New Home Manager module options.
