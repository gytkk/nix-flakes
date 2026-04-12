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

- On NixOS and nix-darwin hosts, the static Codex base config is installed to `/etc/codex/config.toml`.
- On standalone Home Manager environments, `home-manager switch` ensures `/etc/codex/config.toml` is a symlink to this repo's `modules/codex/files/config.toml`.
- Standalone activation may prompt for `sudo` on the first switch, when the repo path changes, or after the symlink is removed.
- If `/etc/codex/config.toml` already exists as a regular file, activation stops instead of overwriting it.
- `~/.codex/config.toml` stays writable for user-local state such as `[projects."..."]` trust entries.

## Zellij config

- Zellij is managed through `modules/zellij/default.nix`.
- The current theme is `ayu-light`.
- Startup tips are disabled, and `Ctrl+b` is passed through to terminal apps like Neovim instead of entering Zellij's tmux mode.
- Local interactive shells started from Ghostty automatically `exec zellij`.
- SSH sessions and shells already inside `zellij` or `tmux` are excluded from that auto-start.

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

Standalone Home Manager outputs are still available for profile-only testing:

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

### `pylv-onyx` Open WebUI access

- Tailscale: `https://pylv-onyx.tailbbb9bf.ts.net:8444`
- Local network: `http://pylv-onyx:8080` when LAN DNS/mDNS resolves, otherwise use the current Wi-Fi address `http://192.168.0.10:8080`
- Main desktop or any LAN-only client: `ssh -N -L 3000:127.0.0.1:8080 gytkk@pylv-onyx`, then browse `http://localhost:3000`
- Direct LAN exposure is enabled only on `wlo1` port `8080`; the raw Open WebUI backend stays loopback-only on `127.0.0.1:8081`
- `nginx` injects fixed trusted-auth headers, so LAN, Tailscale, and SSH-tunneled clients are auto-signed in as `gytk.kim@gmail.com`
- The configured backend model is `openclaw/main` via the local trusted proxy on `127.0.0.1:18790`

### `pylv-onyx` OpenClaw Control UI access

- Local network: `http://pylv-onyx:18790` when LAN DNS/mDNS resolves, otherwise use the current Wi-Fi address `http://192.168.0.10:18790`
- The LAN path is an `nginx` reverse proxy on `wlo1` only; the real gateway stays loopback-only on `127.0.0.1:18789`
- Any LAN client that reaches `18790` is intentionally treated as an admin/operator through OpenClaw `trusted-proxy` auth
- No token or email/password is required on the LAN URL
- `openclaw dashboard --no-open` on the host now prints the bare local URL `http://127.0.0.1:18789/`; for a remote LAN browser, just open `http://pylv-onyx:18790` or `http://192.168.0.10:18790`
- OpenClaw bootstrap and guardrails live in [`modules/openclaw/default.nix`](./modules/openclaw/default.nix)
- Nix now seeds `/etc/openclaw/openclaw.seed.json` and `/etc/openclaw/openclaw.guardrails.json`, while the mutable runtime config lives at `~/.openclaw/openclaw.json`

### `pylv-onyx` Hermes WebUI access

- Tailscale: `https://pylv-onyx.tailbbb9bf.ts.net:8445`
- Local network: `http://pylv-onyx:8787` when LAN DNS/mDNS resolves, otherwise use the current Wi-Fi address `http://192.168.0.10:8787`
- Main desktop or any LAN-only client: `ssh -N -L 8787:127.0.0.1:8787 gytkk@pylv-onyx`, then browse `http://localhost:8787`
- Direct LAN exposure is enabled only on `wlo1` port `8787`; the raw Hermes WebUI backend stays loopback-only on `127.0.0.1:8788`
- Hermes WebUI uses its own password auth; the runtime password is seeded from `secrets/hermes-webui-env.age`
- The WebUI reads the live Hermes runtime at `/home/gytkk/.hermes`, so it sees the same `openai-codex / gpt-5.4` provider setup that the running Hermes gateway already uses
- Mutable Hermes WebUI session/state data lives under `/var/lib/hermes-webui`

## Hermes Agent

- `hermes-agent` flake input is imported both as a package source and as the upstream NixOS module.
- Hermes-related local config now lives under `modules/hermes-agent/`:
  - `default.nix` for standalone Home Manager bootstrap
  - `system.nix` for the `pylv-onyx` NixOS module wiring
- `pylv-onyx` now follows the upstream NixOS module flow from the Hermes docs:
  - `services.hermes-agent.enable = true`
  - `services.hermes-agent.addToSystemPackages = true`
  - declarative `settings`
  - token sync into the writable runtime `.env` under `/var/lib/hermes/.hermes`
- On `pylv-onyx`, the upstream system service runs as the primary host user so the CLI can read the same state directory that the gateway uses.
- The system-managed Hermes home is `/var/lib/hermes/.hermes`, which is also what the CLI uses on hosts where `addToSystemPackages` is enabled.
- Discord mention/channel/user gating now lives in that writable runtime `.env`, so Hermes can adjust it without editing the Nix module.
- The local Hermes package is patched so bundled skills copied from the Nix store stay editable instead of inheriting read-only file modes.

## Helpers

```bash
nix flake show

nix flake update
```

## References

- Nix Packages: <https://search.nixos.org/packages>
