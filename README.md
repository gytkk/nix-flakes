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

## Codex config

- On NixOS and nix-darwin hosts, the static Codex base config is installed to `/etc/codex/config.toml`.
- On standalone Home Manager environments, `home-manager switch` ensures `/etc/codex/config.toml` is a symlink to this repo's `modules/codex/files/config.toml`.
- Standalone activation may prompt for `sudo` on the first switch, when the repo path changes, or after the symlink is removed.
- If `/etc/codex/config.toml` already exists as a regular file, activation stops instead of overwriting it.
- `~/.codex/config.toml` stays writable for user-local state such as `[projects."..."]` trust entries.

## Zellij config

- Zellij is managed through `modules/zellij/default.nix`.
- The current default theme is `one-half-light`, matching the repo's light palette and Ghostty tab background more closely.
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

## Helpers

```bash
nix flake show

nix flake update
```

## References

- Nix Packages: <https://search.nixos.org/packages>
