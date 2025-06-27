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

# Build without switching (test configuration)
home-manager build --flake .#devsisters-macbook
home-manager build --flake .#devsisters-macstudio
home-manager build --flake .#wsl-ubuntu

# List available configurations
nix flake show

# Update flake inputs
nix flake update

# Format Nix files
nixfmt-rfc-style flake.nix home.nix modules/**/*.nix
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

This is a Nix flakes-based Home Manager configuration supporting multiple environments (macOS and WSL Ubuntu). The configuration is modular with environment-specific customizations.

### Core Structure

- `flake.nix`: Main flake configuration with inputs, outputs, and environment definitions
- `home.nix`: Base Home Manager configuration imported by all environments
- `modules/`: Modular configuration components
- `plans/`: Planning documents for improvements and refactoring

### Environment Configurations

The flake defines three environments with specific user and system settings:

- **`devsisters-macbook`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters tools
- **`devsisters-macstudio`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters tools  
- **`wsl-ubuntu`**: x86_64 Linux (gytkk@/home/gytkk) without devsisters tools

Environment configs are managed through the `environmentConfigs` attribute set in `flake.nix:52-71`.

### Module System

- **`modules/claude/`**: Claude Code installation with MCP support enabled
- **`modules/git/`**: Git configuration (gytkk/gytk.kim@gmail.com) with LFS, custom aliases, and global gitignore
- **`modules/zsh/`**: Zsh with Oh-My-Zsh, Powerlevel10k theme, fzf, direnv, and development aliases
- **`modules/devsisters/`**: Company tools (saml2aws, vault, eclair) and authentication scripts

### Key Features

- **Multi-environment support**: Different user accounts and system architectures
- **Modular design**: Reusable components with environment-specific overrides
- **Development tooling**: mise, docker, uv, nodejs, kubectl, k9s, awscli2
- **Shell experience**: Zsh with syntax highlighting, autosuggestion, and custom aliases
- **Code editing**: Neovim with development utilities
- **Nix tooling**: nixfmt-rfc-style for code formatting

### Package Management

Base packages defined in `home.nix:29-61`:
- **System**: coreutils, findutils, ripgrep, direnv
- **Development**: mise, docker, uv, nodejs, awscli2, yq
- **Kubernetes**: kubectl, kubectx, k9s
- **Editor**: neovim
- **Nix**: nixfmt-rfc-style

Additional environment-specific packages added via module imports.

### Configuration Management

- Test changes: `home-manager build --flake .#<environment>`
- Apply changes: `home-manager switch --flake .#<environment>`
- Format code: `nixfmt-rfc-style` for consistent styling
- Version control: All configurations tracked in git
