# nix-flakes

Nix flake configuration for Home Manager, nix-darwin, and NixOS.

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

## Codex Plugin for Claude Code

The official [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) plugin is installed, enabling Codex integration from within Claude Code.

### Available Commands

- `/codex:review` — Code review of current changes or branch
- `/codex:adversarial-review` — Challenge-based review questioning design decisions
- `/codex:rescue` — Delegate tasks to Codex (investigate bugs, fixes, etc.)
- `/codex:status` — Check running and recent Codex jobs
- `/codex:result` — View results of completed jobs
- `/codex:cancel` — Cancel active background jobs
- `/codex:setup` — Verify Codex installation and configuration

### Codex CLI Config

- On NixOS and nix-darwin hosts, the static Codex base config is installed to `/etc/codex/managed_config.toml`.
- Codex admin skills live under `modules/codex/skills` in this repo and are exposed at `/etc/codex/skills`.
- On standalone Home Manager environments, `home-manager switch` ensures `/etc/codex/managed_config.toml` is a symlink to this repo's `modules/codex/files/config.toml`.
- On standalone Home Manager environments, `home-manager switch` also ensures `/etc/codex/skills` is a symlink to this repo's `modules/codex/skills`.
- Standalone activation only prompts for `sudo` when `/etc/codex` needs to be created or repaired, or when migrating from the legacy `/etc/codex/config.toml` path.
- Using the repo path instead of the flake source store path avoids repeated sudo prompts after unrelated repo changes.
- If `/etc/codex/managed_config.toml` or the legacy `/etc/codex/config.toml` already exists as a regular file, activation stops instead of overwriting it.
- `~/.codex/config.toml` stays writable for user-local state such as `[projects."..."]` trust entries.

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
  supporting language servers that Claude Code or OpenCode treat as built-in.
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
- Local interactive shells started from Ghostty automatically `exec zellij`.
- SSH sessions and shells already inside `zellij` or `tmux` are excluded from that auto-start.

## Ghostty config

- Ghostty is managed through `modules/ghostty/default.nix`.
- `home-manager switch` renders `~/.config/ghostty/config` with the selected
  `modules.commonTheme` as `theme = "<commonTheme>.conf"`.
- Home Manager links `~/.config/ghostty/themes` to the generated
  `themes/exports/ghostty` directory managed by the flake.
- Repo edits to Ghostty config and generated themes take effect on the next
  switch instead of updating live files immediately.
- The checked-in defaults keep `xterm-256color`, the generated shared theme,
  JetBrains Mono with Sarasa Mono CL fallback, a beam cursor, 95% background
  opacity, shell integration, and the IME-safe `Ctrl+key_*` bindings.

## Kitty config

- Kitty is managed through `modules/kitty/default.nix`.
- `home-manager switch` installs `~/.config/kitty/kitty.conf` as an out-of-store symlink to `modules/kitty/files/kitty.conf`, so the repo file stays mutable.
- The checked-in defaults mirror the current Ghostty look and feel: One Half Light colors, JetBrains Mono with Sarasa Mono CL as the Hangul fallback, a beam cursor, 95% background opacity, shell integration, and muted split borders.
- The module only manages config. Install the `kitty` app or binary separately.

## AeroSpace config

- AeroSpace config is managed through `modules/aerospace/default.nix` on Darwin hosts.
- `home-manager switch` installs `~/.config/aerospace/aerospace.toml` as an out-of-store symlink to `modules/aerospace/files/aerospace.toml`, so the repo file stays mutable.
- The activation step treats `~/.aerospace.toml` as a legacy path: if it exists, Home Manager backs it up to `~/.aerospace.toml.pre-xdg-backup` and removes the original to avoid path ambiguity.
- The checked-in config keeps `config-version = 2` plus AeroSpace's default `main` and `service` keybindings.
- Omitted scalar options still fall back to AeroSpace's built-in defaults, but keyboard bindings do not inherit from the built-in config and must be declared explicitly in the repo file.

## macOS (`nix-darwin`)

Available Darwin hosts:

- `devsisters-macbook`
- `devsisters-macstudio`

### First bootstrap

Run this once from the repo root to install and invoke `darwin-rebuild` through the flake:

```bash
sudo nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake .#devsisters-macbook
```

For the Mac Studio host:

```bash
sudo nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake .#devsisters-macstudio
```

If the Darwin profile uses agenix-managed secrets, make sure the decrypting SSH key already exists at `~/.ssh/id_ed25519` or `~/.ssh/id_rsa` before the first switch.

### Rebuild after bootstrap

```bash
sudo darwin-rebuild switch --flake .#devsisters-macbook

sudo darwin-rebuild switch --flake .#devsisters-macstudio
```

### Build without switching

```bash
nix build .#darwinConfigurations.devsisters-macbook.system

nix build .#darwinConfigurations.devsisters-macstudio.system
```

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
- `openclaw dashboard --no-open` on the host now prints the bare local URL `http://127.0.0.1:18789/`; for a remote LAN browser, just open `http://pylv-onyx:18790` or `http://192.168.0.10:18790`
- OpenClaw bootstrap and guardrails live in [`modules/openclaw/default.nix`](./modules/openclaw/default.nix)
- Nix now seeds `/etc/openclaw/openclaw.seed.json` and `/etc/openclaw/openclaw.guardrails.json`, while the mutable runtime config lives at `~/.openclaw/openclaw.json`
- The host-level `openclaw` command is a hybrid wrapper: Nix installs the package, but CLI service management overrides the upstream `OPENCLAW_NIX_MODE=1` default with an empty value so `openclaw gateway install` can manage the user service directly

### `pylv-onyx` OpenClaw Open WebUI access

- Public hostname: `https://openwebui.pylv.dev` once the existing `pylv-onyx` Cloudflare Tunnel is mapped to that hostname in Cloudflare Zero Trust
- Access control: protect the public hostname with a Cloudflare Access self-hosted app; for your current plan, allow only `gytk.kim@gmail.com` and keep Google MFA/passkey enabled on that account
- The nginx origin listens only on loopback `127.0.0.1:8787`; the raw Open WebUI backend stays loopback-only on `127.0.0.1:8788`
- Open WebUI talks to the local OpenClaw reverse proxy on `http://127.0.0.1:18790/v1` and defaults to `openclaw/main`
- `nginx` injects the loopback gateway bearer token for OpenClaw and trusted-auth headers for Open WebUI, so the public path auto-signs in as `gytk.kim@gmail.com` after Cloudflare Access admits the request
- `secrets/open-webui-env.age` seeds the initial Open WebUI admin environment
- Mutable Open WebUI data lives under `/var/lib/open-webui`
- Suggested Cloudflare origin target: `http://127.0.0.1:8787`

## Helpers

```bash
nix flake show

nix flake update
```

Generic tooling that probes `nix build .` now hits a small compatibility package instead of failing on a missing default output. For actual host builds, keep using explicit flake attributes such as `.#homeConfigurations...` or `.#nixosConfigurations...`.

## References

- Nix Packages: <https://search.nixos.org/packages>
