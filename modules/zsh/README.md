# Zsh Module

This module provides a comprehensive Zsh shell configuration with modern features and productivity enhancements.

## What it does

- Installs and configures Zsh as the primary shell
- Sets up Oh-My-Zsh framework with useful plugins
- Configures Powerlevel10k theme for a beautiful and informative prompt
- Enables syntax highlighting, autosuggestion, and completion
- Provides development-focused aliases and tools integration
- Integrates fzf (fuzzy finder) and direnv for enhanced workflow

## Features

### Shell Enhancements

- **Syntax Highlighting**: Real-time syntax highlighting for commands
- **Autosuggestion**: Intelligent command suggestions based on history
- **Tab Completion**: Enhanced completion system
- **History Management**: 10,000 command history with deduplication and sharing

### Theme and Appearance

- **Powerlevel10k**: Modern, fast, and customizable prompt theme
- **Custom Configuration**: Pre-configured `.p10k.zsh` with optimal settings
- **Color Support**: Colorized ls output and completion menus

### Oh-My-Zsh Plugins

- `fzf` - Fuzzy file finder integration
- `git` - Git aliases and functions
- `terraform` - Terraform command completion
- `docker` - Docker command completion
- `aws` - AWS CLI completion
- `kubectl` - Kubernetes command completion
- `z` - Smart directory jumping

### Development Aliases

- **Editor**: `vim`, `vi` → `nvim`, `vimdiff` → `nvim -d`
- **File Listing**: `ll`, `lh` with colors
- **Kubernetes**: `kl` (kubectl), `kx` (kubectx), `kn` (kubens)
- **Python**: `ur` (uv run)
- **Terraform**: `tf` with AWS profile integration

### Tool Integration

- **fzf**: Fuzzy finder with Zsh integration
- **direnv**: Directory-based environment variable management
- **uv**: Python package manager with shell completion

## Requirements

- Nix package manager
- Home Manager
- Zsh shell support

## Configuration Files

- `.p10k.zsh`: Powerlevel10k theme configuration
- `.zsh_history`: Command history storage
- `.cache/oh-my-zsh/`: Oh-My-Zsh cache directory

## Usage

After applying this module, restart your shell or run:

```bash
exec zsh
```

The configuration will automatically:

- Load Powerlevel10k theme
- Enable all plugins and features
- Set up aliases and integrations
- Configure optimal shell settings
