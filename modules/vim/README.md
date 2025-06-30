# Vim Module

This module configures Neovim as the primary text editor with essential settings for development work.

## What it does

- Installs and configures Neovim as the default editor
- Sets up basic editing configurations for productivity
- Creates convenient aliases (`vi`, `vim`) that point to Neovim
- Enables essential features like syntax highlighting and file type detection

## Features

### Editor Configuration
- **Default Editor**: Sets Neovim as the system's default editor
- **Aliases**: `vi` and `vim` commands redirect to `nvim`
- **Syntax Highlighting**: Enabled with `syntax enable` and optimized sync
- **File Type Detection**: Automatic file type detection with appropriate plugins and indentation

### Basic Settings
- **Mouse Support**: Full mouse integration (`set mouse=a`)
- **Line Numbers**: Display line numbers (`set nu`)
- **Ruler**: Show cursor position (`set ruler`, `set ru`)
- **File Type Support**: Plugin and indent support for all file types

## Requirements

- Nix package manager
- Home Manager
- Neovim package from nixpkgs

## Configuration Details

The module provides a minimal but functional Neovim setup with:
- Syntax highlighting with optimized synchronization (`syntax sync fromstart`)
- File type detection and appropriate plugin/indent loading
- Basic editor settings for line numbers and cursor position
- Mouse support for enhanced interaction

## Usage

After applying this module, you can use any of these commands to edit files:
```bash
nvim filename.txt    # Direct Neovim command
vim filename.txt     # Alias to Neovim
vi filename.txt      # Alias to Neovim
```

The configuration automatically:
- Enables syntax highlighting for supported file types
- Shows line numbers and cursor position
- Provides mouse support for navigation and selection
- Loads appropriate plugins and indentation for different file types

## Extending the Configuration

This module provides a foundation that can be extended with additional Neovim configuration. You can add more settings to the `extraConfig` section or install additional plugins as needed.