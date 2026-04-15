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

## AeroSpace config

- AeroSpace config is managed through `modules/aerospace/default.nix` on Darwin hosts.
- `home-manager switch` installs `~/.config/aerospace/aerospace.toml` as an out-of-store symlink to `modules/aerospace/files/aerospace.toml`, so the repo file stays mutable.
- The checked-in config is intentionally minimal: `config-version = 2` plus an empty `[mode.main.binding]`.
- Omitted scalar options fall back to AeroSpace's built-in defaults, but keyboard bindings do not inherit from the built-in config and must be added explicitly.

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
