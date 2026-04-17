# Vim Module

This module configures Neovim as the primary editor with a modern Lua-based setup managed through Home Manager.

## What it does

- Installs and configures Neovim as the default editor
- Creates `vi` and `vim` aliases that point to `nvim`
- Loads the Neovim configuration from `modules/vim/files/config/init.lua`
- Applies the generated `monokai-pro-classic` colorscheme

## Included Features

- `lazy.nvim` plugin management
- `snacks.nvim` for file picking, explorer, notifications, status column, inlay hint toggles, and lazygit integration
- `snacks.nvim` extras for git browse, file rename, smooth scrolling, and inline image rendering
- `snacks.nvim` GitHub integration for issues and pull requests via the `gh` CLI
- `blink.cmp` completion with LSP, snippets, path, and buffer sources
- Built-in Neovim LSP configuration for Nix, Go, Rust, TypeScript, Terraform, YAML, Markdown, and Python via `ty`
- `nvim-treesitter` syntax parsing for the main languages used in this repository
- `conform.nvim` formatting on save, including `nixfmt`, `prettier`, `rustfmt`, `gofmt`, and `ruff_format`
- `gitsigns.nvim`, `lualine.nvim`, `flash.nvim`, `which-key.nvim`, `trouble.nvim`, and `render-markdown.nvim`
- Markdown rendering uses inline icons only, with gutter sign markers disabled to avoid duplicates

## Notable Keymaps

- `<leader>e`: file explorer
- `<leader>ff`: find files
- `<leader>sg`: grep
- `<leader>gs`: git status picker
- `<leader>gb`: git branches picker
- `<leader>gd`: git diff picker
- `<leader>gf`: git log for current file
- `<leader>gS`: git stash picker
- `<leader>gl`: git log picker
- `<leader>gL`: git log for current line
- `<leader>gg`: lazygit
- `<leader>gB`: open current file or selection in the git remote browser
- `<leader>gh`: blame current line
- `<leader>gi`: open GitHub issues
- `<leader>gp`: open GitHub pull requests
- `gd`: go to definition
- `gb`: jump back in the jumplist
- `<leader>cR`: rename current file with LSP-aware updates
- `<leader>ud`: toggle diagnostics
- `<leader>uh`: toggle LSP inlay hints
- `<leader>ul`: toggle line numbers
- `<leader>uS`: toggle smooth scrolling
- `<leader>uw`: toggle wrap
- `<leader>cf`: format current buffer

## Usage

```bash
nvim filename.txt
vim filename.txt
vi filename.txt
```

## Files

- `modules/vim/default.nix`: Home Manager wiring
- `modules/vim/files/config/init.lua`: main Neovim configuration
- `themes/exports/nvim/monokai-pro-classic.lua`: generated colorscheme definition
