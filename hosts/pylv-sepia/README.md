# pylv-sepia

NixOS configuration for pylv-sepia server, managed from the main flake.

## Initial Installation

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#pylv-sepia \
  root@<hostname>
```

## Updating Configuration

### From Local Machine

```bash
# From repository root
nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#pylv-sepia \
  --target-host root@<hostname>
```

### On the Server

```bash
sudo nixos-rebuild switch --flake github:gytkk/nix-flakes#pylv-sepia
```

## Adding Packages

User packages are managed via Home Manager modules in `base/pylv/`.

Edit `base/pylv/home.nix` or `base/pylv/sepia.nix`:

```nix
home.packages = with pkgs; [
  # add packages here
];
```

## File Structure

| File | Description |
|------|-------------|
| `configuration.nix` | NixOS system configuration (services, users) |
| `disk-config.nix` | Disk partitioning configuration (disko) |
| `hardware-configuration.nix` | Auto-generated hardware configuration |

## Shared Modules

This configuration uses shared modules from the main flake:

- `modules/git` - Git configuration
- `modules/zsh` - Zsh with Oh-My-Zsh and Powerlevel10k
- `modules/vim` - Neovim configuration
- `modules/claude` - Claude Code configuration
- `modules/terraform` - Terraform version management


