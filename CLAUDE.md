# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context for MCPs

- Use context7

## Commands

### Home Manager Operations

```bash
# Switch to environment-specific configuration
home-manager switch --flake .#devsisters-macbook
home-manager switch --flake .#devsisters-macstudio
home-manager switch --flake .#wsl-ubuntu

# Build without switching
home-manager build --flake .#macbook

# List available configurations
nix flake show

# Update flake inputs
nix flake update
```

### Nix Development

```bash
# Check flake configuration
nix flake check

# Show flake metadata
nix flake metadata

# Enter development shell
nix develop
```

## Architecture

This is a Nix flakes-based Home Manager configuration supporting multiple environments (macOS and WSL Ubuntu). The configuration is modular and environment-specific.

### Core Structure

- `flake.nix`: Main flake configuration defining inputs, outputs, and environment-specific configurations
- `home.nix`: Base Home Manager configuration imported by all environments
- `modules/`: Modular configuration components

### Environment Configurations

The flake defines three main environments:

- `devsisters-macbook`: ARM64 macOS configuration
- `devsisters-macstudio`: ARM64 macOS configuration with devsisters-specific tools
- `wsl-ubuntu`: x86_64 Linux configuration for WSL

Each environment has both `darwinConfigurations` and `homeConfigurations` entries, with the latter being the primary configurations used.

### Module System

- `modules/claude/`: Claude Code installation and MCP configuration
- `modules/git/`: Git configuration with user settings and global gitignore
- `modules/zsh/`: Zsh configuration with Oh-My-Zsh, Powerlevel10k theme, and development aliases
- `modules/devsisters/`: Company-specific tools (saml2aws, vault) and environment variables

### Key Features

- **Environment-specific configurations**: Each environment can have different packages and settings
- **Modular design**: Common functionality is extracted into reusable modules
- **Development tooling**: Includes mise for version management, various CLI tools, and IDE configurations
- **Shell customization**: Zsh with Powerlevel10k theme and productivity aliases
- **Authentication tools**: SAML2AWS and Vault integration for devsisters environment

### Package Management

Packages are defined in `home.nix` and include development tools (mise, docker, nodejs), editors (neovim, cursor), cloud tools (awscli2, kubectl), and shell enhancements.

### Configuration Updates

When modifying configurations, test with `home-manager build` before switching to avoid breaking the current environment.
