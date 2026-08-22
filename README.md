# nix-flakes

Nix flake configuration for standalone Home Manager and NixOS.

## Prerequisites

- Install Nix: <https://nixos.org/download>
- Enable flakes:

```bash
sudo mkdir -p /etc/nix
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
```

- This repo assumes the checkout lives at `~/development/nix-flakes`.
  Several modules create out-of-store symlinks from that path.
- Standalone Home Manager commands evaluate without `--impure`.
  The checkout path still matters for modules that intentionally install
  out-of-store symlinks back to the repo.

## Secrets with agenix and 1Password

Encrypted secrets live in `secrets/*.age`, while `secrets/secrets.nix` defines
which administrator, host, or workstation public keys may decrypt each file.
Only public keys and encrypted files belong in Git.

- Home Manager uses each workstation's `~/.ssh/id_ed25519` as its agenix
  identity.
- NixOS hosts use their SSH host keys for unattended system secret activation.
- The current workstation key is the primary agenix administrator key. Keep its
  recovery copy in the 1Password item `pylv/agenix-admin-key`; never commit or
  symlink the private key into this repository.

Home Manager installs `agx`, which fixes the checkout's `secrets` directory,
rules file, and `~/.ssh/id_ed25519` identity for every operation:

```bash
agx -e openai-api-key.age
agx -d cloudflare-tunnel-sepia-token.age
agx -r
```

`agx -d` writes plaintext to standard output. After adding or removing a
recipient in `secrets/secrets.nix`, run `agx -r` and commit the rules and all
changed `.age` files together. To recover the administrator identity, restore
it from 1Password to `~/.ssh/id_ed25519`, set mode `0600`, and verify its public
key matches `agenixAdmin` before editing or rekeying secrets.

## Architecture

This flake supports standalone Home Manager environments and NixOS hosts.
macOS entries in `inventory.nix` are Home Manager only; Linux NixOS entries
compose system configuration plus a Home Manager user.

```text
flake.nix                         # Main flake configuration
inventory.nix                     # All Home Manager environments and NixOS hosts
base/default.nix                  # Common Home Manager imports and default enables
base/<profile>/home.nix           # Profile-specific Home Manager extensions
modules/<name>/default.nix        # Reusable Home Manager or NixOS module
modules/agent-prompts/              # Shared global rules for coding agents
modules/nixos/                    # Common NixOS modules and shared secrets
hosts/<name>/configuration.nix    # Host-specific NixOS imports and values
lib/pkgs.nix                      # Overlay and per-system package-set construction
lib/home-configurations.nix       # Home Manager configuration builder
lib/nixos-configurations.nix      # NixOS configuration builder
lib/builders.nix                  # Backward-compatible builder aggregation
```

Home Manager modules expose `modules.<name>.enable`; `base/default.nix` owns
common default enables, and profile files can override them. NixOS input modules
that are host-specific, such as Disko, Copyparty, niri, and DankMaterialShell,
are imported by the relevant `hosts/<name>/configuration.nix`.

`modules/openclaw` is a parameterized NixOS module. `pylv-onyx` currently
enables it and provides host values such as `lanInterface`, proxy ports, and
`stateDir` in `hosts/pylv-onyx/configuration.nix`.

Global coding-agent instructions are assembled from shared rules under
`modules/agent-prompts/` and a harness-specific file under each agent module.
The same directory also owns the shared skill registry. The registry reads the
25 official skills from the locked `mattpocock-skills` input and exposes them to
Claude Code, Codex, and Pi. Home Manager generates the final instruction and
skill links, so changes take effect after the relevant configuration is
applied.

## Codex Plugin for Claude Code

The official [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) plugin is installed, enabling Codex integration from within Claude Code.
Superpowers is also installed for both Codex CLI and Claude Code from their
official plugin marketplaces.

### Available Commands

- `/codex:review` — Code review of current changes or branch
- `/codex:adversarial-review` — Challenge-based review questioning design decisions
- `/codex:rescue` — Delegate tasks to Codex (investigate bugs, fixes, etc.)
- `/codex:status` — Check running and recent Codex jobs
- `/codex:result` — View results of completed jobs
- `/codex:cancel` — Cancel active background jobs
- `/codex:setup` — Verify Codex installation and configuration

### Codex CLI Config

- On NixOS hosts, the static Codex base config is installed to `/etc/codex/managed_config.toml`.
- Codex-specific admin skills live under `modules/codex/skills`. They are merged with the shared official skills from `modules/agent-prompts/skills.nix` and exposed at `/etc/codex/skills`.
- On standalone Home Manager environments, `home-manager switch` ensures `/etc/codex/managed_config.toml` is a symlink to this repo's `modules/codex/files/config.toml`.
- On standalone Home Manager environments, `home-manager switch` points `/etc/codex/skills` at the generated skill farm. Local Codex skills still link back to this checkout, while official shared skills use the revision pinned in `flake.lock`.
- Standalone activation only prompts for `sudo` when `/etc/codex` needs to be created or repaired, or when migrating from the legacy `/etc/codex/config.toml` path.
- Using the repo path instead of the flake source store path avoids repeated sudo prompts after unrelated repo changes.
- If `/etc/codex/managed_config.toml` or the legacy `/etc/codex/config.toml` already exists as a regular file, activation stops instead of overwriting it.
- `~/.codex/config.toml` stays writable and is not rewritten by activation,
  preserving user-local state such as project trust, hook trust, notices, and
  TUI state.
- Repo-managed Codex-specific skills currently include
  `parallel-research-merge` and `devils-advocate`. The shared registry adds the
  25 official Matt Pocock skills.
- Update the shared upstream revision explicitly with
  `nix flake update mattpocock-skills`.
- The Cloudflare API MCP uses OAuth at `https://mcp.cloudflare.com/mcp`; run
  `codex mcp login cloudflare` once per Codex host. Write-capable tools require
  approval by default.
- `home-manager switch` ensures `superpowers@openai-curated` is installed and
  enabled for Codex CLI; restart Codex after switching so plugin skills are
  rediscovered.
- If the bundled Codex marketplace has not synced yet, activation falls back to
  the upstream Codex install path by cloning `obra/superpowers` under
  `~/.codex/superpowers` and linking its skills into `~/.agents/skills`.

### Agent Session Record Hooks

- Claude `SessionEnd` and Codex `Stop` / `SessionStart` hooks are installed by
  default through `modules/agent-session-record`.
- Session transcripts are uploaded best-effort to `pylv-onyx` over `rsync` +
  SSH and stored under `/home/gytkk/agent-sessions/<agent>/<YYYY>/<MM>/<DD>/`.
- `pylv-denim` overrides the agent session upload target to `192.168.0.10`
  because that machine reaches `pylv-onyx` over the local network instead of
  the tailnet.
- Hook failures append one-line summaries under
  `~/.local/state/agent-session-record/warnings.log`.
- Detailed worker stderr from SSH / `rsync` failures is appended to
  `~/.local/state/agent-session-record/debug.log`.
- These logs do not block Claude exit or Codex continuation.

### Codex LSP MCP Implementation Plan

This section is a design plan only. The bridge and skills below are not
implemented yet.

#### Goals

- Give Codex symbol-aware navigation and diagnostics through MCP instead of
  relying on plain text search alone.
- Reuse LSP binaries already installed by this flake when possible, while also
  supporting language servers that Claude Code treats as built-in.
- Auto-detect roughly ten languages from the current workspace without
  requiring per-repo manual MCP edits.
- Keep the first rollout read-only and deterministic so it is safe to enable by
  default in Codex.

#### Design Target

- Follow `lspi` for runtime design: explicit workspace roots, `doctor`,
  warmup, structured diagnostics, and server lifecycle management.
- Follow `symbols` for agent UX: a compact MCP tool surface plus bundled skills
  that teach Codex when to prefer semantic navigation over `rg`.
- Expose LSP functionality through a local `stdio` MCP server because Codex
  currently treats MCP as the primary extension path.

#### Planned Components

1. `codex-lsp-mcp` local server
   - Starts as a local `stdio` process from Codex config.
   - Owns language detection, LSP process supervision, tool dispatch, and
     diagnostic caching.
2. Profile registry
   - Data-driven definitions for each supported language instead of hardcoded
     branching.
   - Each profile includes file extensions, project markers, root markers,
     command candidates, default args, timeouts, and capability flags.
3. Workspace detector
   - Chooses the best profile from file extension plus nearby project files.
   - Resolves the workspace root before any LSP request so definitions and
     references stay scoped correctly.
4. LSP supervisor
   - Maintains one live session per `<workspace root, profile>`.
   - Supports lazy startup, optional warmup, restart-on-crash, and per-server
     logs for debugging.
5. Repo-local skills
   - Add a small skill set that nudges Codex toward semantic tools first for
     navigation, diagnostics, and safe refactors.

#### Initial Language Matrix

- `nix` via `nixd`, rooted by `flake.nix` or nearby `.nix` files
- `go` via `gopls`, rooted by `go.mod`
- `rust` via `rust-analyzer`, rooted by `Cargo.toml`
- `typescript` and `javascript` via `typescript-language-server`, rooted by
  `package.json`, `tsconfig.json`, or `jsconfig.json`
- `python` via `ty server` first, with room for a fallback profile later
- `terraform` via `terraform-ls serve`
- `scala` via `metals`, rooted by `build.sbt` or `project/build.properties`
- `yaml` via `yaml-language-server --stdio`
- `markdown` via `marksman server`
- one extra slot reserved for a future default such as `clangd` or
  `bash-language-server`

#### MCP Tool Shape

The first version should stay intentionally small:

- `hover_at`
- `find_definition_at`
- `find_references_at`
- `get_document_symbols`
- `search_workspace_symbols`
- `get_diagnostics`
- `doctor`

Resources should supplement the tools instead of expanding the tool count:

- `lsp://profiles`
- `lsp://profiles/<id>`
- `lsp://logs/<workspace>/<profile>`
- `lsp://diagnostics/<workspace>/<path>`

#### Detection and Routing Rules

- Prefer explicit project markers over extension-only guesses.
- Resolve the workspace root first, then select or start the matching server.
- Treat missing binaries as a diagnosable state, not a hard crash.
- Keep auto-detection separate from auto-installation. The first version only
  uses binaries already on `PATH`.
- Allow profile-specific adapters where raw LSP behavior is known to need extra
  shaping, especially for TypeScript-family servers.

#### Rollout Phases

1. Prototype the bridge
   - Build the MCP server with profile registry, detector, supervisor, and the
     seven read-only tools.
   - Add `doctor` output that explains which binaries, roots, and profiles were
     selected.
2. Integrate with `modules/codex`
   - Add the bridge as a default local MCP entry in
     `modules/codex/files/config.toml`.
   - Keep the bridge opt-in or read-only until the manual smoke tests are
     stable.
3. Add Codex skills
   - Ship a navigation skill and a diagnostics-first editing skill so Codex
     reaches for LSP tools before wide text scans.
4. Expand carefully
   - Add preview-first rename and other write-capable workflows only after the
     read-only path is stable.

#### Verification Plan

- Unit-test profile detection from extensions, markers, and missing-binary
  cases.
- Add fixture workspaces for at least `nix`, `go`, `rust`, `typescript`, and
  `python`.
- Verify `doctor` output for both healthy and degraded setups.
- Smoke-test MCP registration with `codex mcp list` and direct tool calls.
- Confirm that multiple files in the same workspace reuse one LSP session.
- Confirm that failures degrade to actionable diagnostics rather than hanging
  Codex.

#### Non-Goals for the First Iteration

- No raw 1:1 exposure of every LSP method.
- No automatic package downloads or language server installation.
- No write-capable refactors by default.
- No attempt to replace broad semantic search or indexing tools across the
  whole repository.

## Zed config

- Zed is managed through `modules/zed/default.nix`.
- On macOS and Linux, `home-manager switch` installs `~/.config/zed/settings.json` and `keymap.json` as out-of-store symlinks to the repo, and exposes the entire `themes/exports/zed` directory at `~/.config/zed/themes`.
- That means mutable settings can switch between generated theme names without requiring another switch just to materialize a newly referenced theme file.
- On WSL hosts, activation still copies settings, keymaps, and the full set of generated `themes/exports/zed/*.json` files into the Windows Zed config directory on each switch.
- The checked-in defaults point both light and dark mode at the generated
  `Catppuccin Mocha` theme.

## Zellij config

- Zellij is managed through `modules/zellij/default.nix`.
- `home-manager switch` renders `~/.config/zellij/config.kdl` from the platform-specific template in `modules/zellij/files/` and exposes the generated `themes/exports/zellij` directory at `~/.config/zellij/themes`.
- The checked-in defaults keep the selected shared theme, use Zellij's builtin `default` layout, disable startup tips, and leave `Ctrl+b` unbound so terminal apps like Neovim still receive it instead of entering Zellij's tmux mode.
- On macOS, the repo-managed Darwin config includes `copy_command "pbcopy"` so explicit Zellij copy actions continue to target the system clipboard.
- Local interactive shells started from the terminal automatically `exec zellij`.
- SSH sessions and shells already inside `zellij` or `tmux` are excluded from that auto-start.

## Herdr config

- Herdr is managed through `modules/herdr/default.nix` and enabled by default.
- Home Manager links `~/.config/herdr/config.toml` to
  `modules/herdr/files/config.toml` as an out-of-store symlink, so changes made
  through Herdr settings update the checked-in source file directly.
- The configured prefix is `Ctrl+a`. Press `Ctrl+a` twice to send a literal
  `Ctrl+a` to a shell or application inside a pane. If tmux is ever nested
  inside Herdr, press `Ctrl+a` twice before the tmux command key.
- `Ctrl+a`, then `Shift+n`, opens a popup that selects a previously visited
  directory with `zoxide` and `fzf`, then creates and focuses a workspace there.
- `Ctrl+Shift+Tab` or `Ctrl+Tab` focuses the previous or next workspace.
  `Cmd+1..9` focuses a workspace by index in Ghostty on macOS, and `Alt+1..9`
  does the same in Windows Terminal on WSL. `Ctrl+a`, then `Shift+1..9` focuses
  the corresponding visible agent. The terminal configs forward the direct
  workspace shortcuts as distinct Kitty keyboard sequences so Herdr receives
  every modifier.
- On WSL, the `windows-terminal` module merges the corresponding `sendInput`
  actions into the existing Windows Terminal `settings.json` during Home Manager
  activation.
  Existing profiles, themes, and unrelated keybindings are preserved; the first
  managed update creates a `settings.json.home-manager.bak` backup.
- Herdr uses the native terminal cursor so pane applications such as Neovim can
  preserve mode-specific cursor shapes. On Windows or WSL, this may expose
  ConPTY cursor flicker that Herdr's default drawn cursor avoids.
- Reload a running server after editing the config with
  `herdr server reload-config`.

## tmux config

- tmux is managed through `modules/tmux/default.nix`.
- Home Manager installs tmux plus a `tm` session-manager wrapper and links
  `~/.config/tmux/tmux.conf`, `keybindings.conf`, and `statusline.conf` to
  `modules/tmux/files/` through out-of-store symlinks.
- Home Manager also links `~/.config/tmux/themes` to `themes/exports/tmux` and
  exposes the selected `modules.commonTheme` as `~/.config/tmux/theme.conf`.
- Running bare interactive `tm` outside tmux opens the fzf-backed session
  manager; `tmux` remains the original tmux binary. Use arrow keys to select a
  session, `Enter` to attach, type a new session name and press `Enter` to
  create it, `Ctrl+r` to rename, and `Ctrl+d` to delete.
- The checked-in tmux config uses `Ctrl+a` as the prefix, starts window and
  pane indexes at `1`, enables mouse support, and keeps the statusline at the
  top with generated canonical theme colors. Mouse-wheel scrolling moves one
  line per event in copy mode. Pressing the prefix accent-colors the session
  segment and shows key hints on the right; synchronized panes still show a
  `SYNC` indicator.
- Resize the active pane in five-cell steps with `Ctrl+a`, then
  `Ctrl+h`/`Ctrl+j`/`Ctrl+k`/`Ctrl+l`.
- Close the active pane immediately with `Ctrl+a`, then `x`; use uppercase
  `X` to close the entire window.
- tmux sets the outer terminal title to the current session name, so terminal
  tabs that use pane titles, including WezTerm, show the tmux session instead
  of the `tmux` process name.
- Pi windows use `pi` as their tmux window label instead of the underlying
  `node` process name and keep that label while tmux copy mode is active.
- Claude Code windows likewise use `claude` instead of the Nix wrapper name
  `.claude-wrapped`, including while tmux copy mode is active.
- tmux enables CSI-u extended keys so modified keys such as `Shift+Enter`
  survive through tmux into TUI apps like Codex. Restart tmux fully after
  changing this setting, because existing clients keep the old key mode.
- Press `Ctrl+a ?` for the key list, `Ctrl+a w` for the tree, and `Ctrl+a s`
  for the session tree.

## WezTerm config

- WezTerm is managed through `modules/wezterm/default.nix`.
- `home-manager switch` installs `~/.config/wezterm/wezterm.lua` as an
  out-of-store symlink to `modules/wezterm/files/wezterm.lua`, so repo edits
  are reflected in the live config file.
- Home Manager renders `~/.config/wezterm/theme.lua` with the selected
  `modules.commonTheme` and links `~/.config/wezterm/themes` to the generated
  `themes/exports/wezterm` directory.
- The checked-in defaults keep `xterm-256color`, the generated shared theme,
  JetBrains Mono with Sarasa Mono CL fallback, a beam cursor, opaque
  background, hidden titlebar via resize-only decorations, a compact tab bar,
  shell/process tab titles enriched with compact current-directory context, and
  IME-safe physical `Ctrl+letter` bindings.

## Kitty config

- Kitty is managed through `modules/kitty/default.nix`.
- `home-manager switch` installs `~/.config/kitty/kitty.conf` as an out-of-store symlink to `modules/kitty/files/kitty.conf`, so the repo file stays mutable.
- The checked-in defaults mirror the current WezTerm look and feel: One Half Light colors, JetBrains Mono with Sarasa Mono CL as the Hangul fallback, a beam cursor, opaque background, and muted split borders.
- The module only manages config. Install the `kitty` app or binary separately.

## AeroSpace config

- AeroSpace config is managed through `modules/aerospace/default.nix` on Darwin hosts.
- `home-manager switch` installs `~/.config/aerospace/aerospace.toml` as an out-of-store symlink to `modules/aerospace/files/aerospace.toml`, so the repo file stays mutable.
- The activation step treats `~/.aerospace.toml` as a legacy path: if it exists, Home Manager backs it up to `~/.aerospace.toml.pre-xdg-backup` and removes the original to avoid path ambiguity.
- The checked-in config keeps `config-version = 2` plus AeroSpace's default `main` and `service` keybindings.
- Omitted scalar options still fall back to AeroSpace's built-in defaults, but keyboard bindings do not inherit from the built-in config and must be declared explicitly in the repo file.

## Standalone Home Manager

Standalone Home Manager outputs are still available for profile-only testing.

```bash
home-manager switch --flake .#devsisters-macbook

home-manager switch --flake .#devsisters-macstudio

home-manager switch --flake .#pylv-denim

home-manager switch --flake .#pylv-onyx

home-manager switch --flake .#pylv-sepia
```

### Build without switching

```bash
home-manager build --flake .#devsisters-macbook
```

## NixOS

Available NixOS hosts:

- `pylv-onyx`
- `pylv-sepia`

```bash
sudo nixos-rebuild switch --flake .#pylv-onyx

sudo nixos-rebuild switch --flake .#pylv-sepia
```

### Build without switching

```bash
nix build .#nixosConfigurations.pylv-onyx.config.system.build.toplevel

nix build .#nixosConfigurations.pylv-sepia.config.system.build.toplevel
```

### `pylv-onyx` OpenClaw Control UI access

- Local network: `http://pylv-onyx:18790` when LAN DNS/mDNS resolves, otherwise use the current Wi-Fi address `http://192.168.0.10:18790`
- The LAN path is an `nginx` reverse proxy on `wlo1` only; the real gateway stays loopback-only on `127.0.0.1:18789`
- Any LAN client that reaches `18790` is intentionally treated as an admin/operator because the local `nginx` proxy injects the loopback gateway bearer token
- No token or email/password is required on the LAN URL
- For Cloudflare Tunnel / Access exposure, use the separate loopback-only origin `http://127.0.0.1:18791` instead of reusing the LAN listener
- Suggested public hostname target: map your Cloudflare public hostname to `http://127.0.0.1:18791`, then protect it with a Cloudflare Access self-hosted app
- `openclaw dashboard --no-open` on the host now prints the bare local URL `http://127.0.0.1:18789/`; for a remote LAN browser, just open `http://pylv-onyx:18790` or `http://192.168.0.10:18790`
- OpenClaw reusable wiring lives in [`modules/openclaw/default.nix`](./modules/openclaw/default.nix); `pylv-onyx` supplies host values through `modules.openclaw`.
- Nix seeds `/etc/openclaw/openclaw.seed.json`, while the mutable runtime config lives at `~/.openclaw/openclaw.json`.
- The host-level `openclaw` command is a hybrid wrapper: Nix installs the package, but CLI service management overrides the upstream `OPENCLAW_NIX_MODE=1` default with an empty value so `openclaw gateway install` can manage the user service directly

### `pylv-onyx` Hermes Dashboard access

- Suggested public hostname: `https://hermes.pylv.dev`
- Access control: protect the public hostname with a Cloudflare Access self-hosted app. The dashboard can expose Hermes config/API-key management, so do not publish it without Access.
- The `hermes dashboard` process stays loopback-only on `127.0.0.1:9119`; nginx exposes a separate Cloudflare Tunnel origin on `127.0.0.1:19119`.
- NixOS runs the `pylv-onyx` Cloudflare Tunnel connector with the agenix-managed `cloudflare-tunnel-onyx-token` secret.
- The Cloudflare-managed ingress maps `hermes.pylv.dev` to `http://127.0.0.1:19119`.

## Helpers

```bash
nix flake show

nix flake update

# Update a single input to its latest tracked ref (rewrites flake.lock only).
# Example: bump kc2aws (keycloak2aws input) to the latest commit on main,
# then apply it with a home-manager switch and commit the flake.lock change.
nix flake update keycloak2aws
```

Generic tooling that probes `nix build .` now hits a small compatibility package instead of failing on a missing default output. For actual host builds, keep using explicit flake attributes such as `.#homeConfigurations...` or `.#nixosConfigurations...`.

## References

- Nix Packages: <https://search.nixos.org/packages>
