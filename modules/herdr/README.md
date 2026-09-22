# Herdr

[default.nix](default.nix) installs Herdr and links [files/config.toml](files/config.toml) to `~/.config/herdr/config.toml`. The prefix is `Ctrl+Space`.

## Terminal shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Focus the next / previous tab in the current workspace. |
| `Cmd+[` / `Cmd+]` | Focus the previous / next workspace in Ghostty on macOS. |
| `Cmd+t` | Create a Herdr tab without a naming prompt in Ghostty on macOS. |
| `Cmd+w` | Close the current Herdr tab in Ghostty on macOS. |
| `Cmd+1..9` / `Alt+1..9` | Focus a workspace by index in Ghostty on macOS / Windows Terminal on WSL. |

The prefix shortcuts remain available: `c` creates a tab, `Shift+x` closes a tab, and `p` / `n` focuses the previous / next tab. `Ctrl+Space`, then `Shift+s`, opens the workspace picker.

In Herdr 0.9.1, closing a tab terminates its panes. Closing the last tab also closes its workspace, normally without confirmation. With the default `confirm_close = true`, closing the last tab prompts when it would close a linked worktree group. Direct shortcuts apply in terminal mode; popups and overlays handle their own input.

[Ghostty's config](../ghostty/files/config) overrides its native tab, split navigation, and close shortcuts with explicit Kitty keyboard sequences. Physical key bindings preserve the Command shortcuts while an IME is active. These overrides apply throughout Ghostty, including outside Herdr; the keys no longer perform their original Ghostty actions there.

[Windows Terminal's config](../windows-terminal/files/herdr-keybindings.json) forwards `Ctrl+Tab`, `Ctrl+Shift+Tab`, and `Alt+1..9`. Its next/previous tab actions retain their existing `User.herdrNextWorkspace` and `User.herdrPreviousWorkspace` IDs so activation replaces the previously managed actions.

## Subagents

The Pi and Codex Agent layouts in [files/config.toml](files/config.toml) display active child names, models, and activity. The [Pi extension](../pi/README.md#herdr-subagent-sidebar) reports foreground children; the [Codex hook and watcher](../codex/README.md#herdr-subagent-sidebar) read direct child sessions from local rollout files. Empty child rows are hidden. The Pi parent row also retains pi-subagents' existing `$summary` for background work. Other agents use Herdr's default layout.

The expanded desktop sidebar supports seven children with two lines each. If more children are active, it shows six plus an overflow count. The rows belong to the parent pane and do not create additional terminal panes. Collapsed and mobile layouts remain compact.

Apply Home Manager, run `herdr server reload-config`, and start a new Pi or Codex session inside Herdr to load the integration.

## Apply changes

Apply Home Manager for the current environment to install the terminal config, for example `home-manager switch --flake .#devsisters-macbook`. Reload Ghostty with `Cmd+Shift+,`, then run `herdr server reload-config` to reload the running Herdr server's bindings. Editing Herdr's linked config alone does not update Ghostty's generated config.
