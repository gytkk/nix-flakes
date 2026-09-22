# Herdr

[default.nix](default.nix) installs Herdr and links [files/config.toml](files/config.toml) to `~/.config/herdr/config.toml`. The prefix is `Ctrl+Space`.

## Terminal shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Focus the next / previous tab in the current workspace. |
| `Cmd+[` / `Cmd+]` | Focus the previous / next workspace in Ghostty on macOS. |
| `Cmd+Shift+[` / `Cmd+Shift+]` | Focus the previous / next agent in sidebar order in Ghostty on macOS, wrapping at either end. |
| `Cmd+t` | Create a Herdr tab without a naming prompt in Ghostty on macOS. |
| `Cmd+w` | Close the current Herdr tab in Ghostty on macOS. |
| `Cmd+1..9` / `Alt+1..9` | Focus a workspace by index in Ghostty on macOS / Windows Terminal on WSL. |

The prefix shortcuts remain available: `c` creates a tab, `Shift+x` closes a tab, `p` / `n` focuses the previous / next tab, and `Shift+,` / `Shift+.` focuses the previous / next agent. `Ctrl+Space`, then `Shift+s`, opens the workspace picker.

In Herdr 0.9.1, closing a tab terminates its panes. Closing the last tab also closes its workspace, normally without confirmation. With the default `confirm_close = true`, closing the last tab prompts when it would close a linked worktree group. Direct shortcuts apply in terminal mode; popups and overlays handle their own input.

[Ghostty's config](../ghostty/files/config) overrides its native tab, split navigation, and close shortcuts with explicit Kitty keyboard sequences. Physical key bindings preserve the Command shortcuts while an IME is active. These overrides apply throughout Ghostty, including outside Herdr; the keys no longer perform their original Ghostty actions there.

[Windows Terminal's config](../windows-terminal/files/herdr-keybindings.json) forwards `Ctrl+Tab`, `Ctrl+Shift+Tab`, and `Alt+1..9`. Its next/previous tab actions retain their existing `User.herdrNextWorkspace` and `User.herdrPreviousWorkspace` IDs so activation replaces the previously managed actions.

## Agent detection

The packaged Herdr excludes direct `claude plugin ...`, `claude mcp ...`, `claude --version` / `-v`, and `claude --help` / `-h` invocations from process-based agent detection. Home Manager runs plugin and MCP management commands during `setupClaudeCode`; they do not represent an interactive Claude session. Normal Claude sessions, including resume and continue, remain detectable. Unrecognized argument layouts retain upstream detection behavior.

This behavior comes from [the local detection patch](../../packages/apps/herdr/claude-admin-detection.patch). After applying Home Manager, restart the Herdr server when its running tasks can be interrupted to load the patched binary. `herdr server reload-config` only reloads configuration.

## Subagents

Agent entries in [files/config.toml](files/config.toml) show the agent name and reported model on their second row. Codex reads the parent's latest `turn_context.model`, Pi reports its current session model, and [Claude's status line](../claude/README.md#settingsjson) reports its selected model. Claude's model expires after 45 seconds without a status line update and may disappear while idle. Missing model metadata is hidden; agents without a model reporter show only their name. Parent rows do not display summaries or child counts.

The Pi and Codex layouts also display child names, models, and activity. The [Pi extension](../pi/README.md#herdr-subagent-sidebar) reports foreground children; the [Codex hook and watcher](../codex/README.md#herdr-subagent-sidebar) read direct child sessions from local rollout files, including native subagents that continue in the background. Empty child rows are hidden.

Codex shows a colored status icon, name, and model on each child's first line, with a dimmed excerpt of its latest assistant message below it. The [local separator patch](../../packages/apps/herdr/sidebar-status-separator.patch) places one space after custom lifecycle and overflow icons, without a dot separator. Load this patch by applying Home Manager and restarting the Herdr server when its running tasks can be interrupted; config reload alone does not load binary changes. The excerpt is limited to 80 characters with an ellipsis when truncated; tool events preserve it, and task completion uses the final response when available. Fixed labels are English; messages retain their original language. Running, completed, interrupted, and failed are separate states. Terminal states remain visible for five seconds. Read failures show an unknown state and the last message. If the watcher dies or cannot reach Herdr, its last metadata expires within 15 seconds; expiration removes rows rather than generating an unknown icon.

The expanded desktop sidebar supports seven children with two lines each. If more children are visible, it shows six plus an overflow count. Codex prioritizes running and unknown children before recent terminal states. The rows belong to the parent pane and do not create additional terminal panes. Collapsed and mobile layouts remain compact.

Apply Home Manager, run `herdr server reload-config`, and start a new Pi or Codex session inside Herdr to load the integration.

## Apply changes

Apply Home Manager for the current environment to install the terminal config, for example `home-manager switch --flake .#devsisters-macbook`. Reload Ghostty with `Cmd+Shift+,`, then run `herdr server reload-config` to reload the running Herdr server's bindings. Editing Herdr's linked config alone does not update Ghostty's generated config.
