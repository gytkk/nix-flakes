# pylv-sepia

NixOS configuration for pylv-sepia server with Home Manager integration.

## Initial Installation

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#generic \
  --generate-hardware-config nixos-generate-config ./hardware-configuration.nix \
  <hostname>
```

## Updating Configuration

### From Local Machine (Recommended)

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#generic \
  --target-host gytkk@<hostname> \
  --use-remote-sudo
```

### From GitHub

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake github:gytkk/nix-flakes?dir=hosts/pylv-sepia#generic \
  --target-host gytkk@<hostname> \
  --use-remote-sudo
```

### On the Server

```bash
sudo nixos-rebuild switch --flake /path/to/repo#generic
```

## Adding Packages

### User Packages (Home Manager)

Edit `home.nix`:

```nix
home.packages = with pkgs; [
  htop
  tmux
  # add packages here
];
```

### System Packages (NixOS)

Edit `configuration.nix`:

```nix
environment.systemPackages = map lib.lowPrio [
  pkgs.curl
  pkgs.gitMinimal
  # add packages here
];
```

## File Structure

| File | Description |
|------|-------------|
| `flake.nix` | Flake configuration with nixpkgs, disko, home-manager inputs |
| `configuration.nix` | NixOS system configuration |
| `home.nix` | Home Manager user configuration |
| `disk-config.nix` | Disk partitioning configuration (disko) |
| `hardware-configuration.nix` | Auto-generated hardware configuration |
