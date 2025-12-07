# pylv-sepia

NixOS configuration for pylv-sepia server.

## Initial Installation

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#generic \
  root@<hostname>
```

## Updating Configuration

### From Local Machine

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#generic \
  --target-host root@<hostname>
```

### On the Server

```bash
sudo nixos-rebuild switch --flake /path/to/repo#generic
```

## Adding Packages

Edit `configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  # add packages here
];
```

## File Structure

| File | Description |
|------|-------------|
| `flake.nix` | Flake configuration with nixpkgs, disko inputs |
| `configuration.nix` | NixOS system configuration |
| `disk-config.nix` | Disk partitioning configuration (disko) |
| `hardware-configuration.nix` | Auto-generated hardware configuration |
