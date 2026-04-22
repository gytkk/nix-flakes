# Vim Module

This module configures Neovim as the primary editor with a modern Lua-based setup managed through Home Manager.

## What it does

- Installs and configures Neovim as the default editor
- Creates `vi` and `vim` aliases that point to `nvim`
- Loads the Neovim configuration from `modules/vim/files/config/init.lua`
- Exposes every generated colorscheme from `themes/exports/nvim/`
- Loads `monokai-pro-classic` by default and falls back to it if a selected exported theme is missing

## Included Features

- `lazy.nvim` plugin management
- `snacks.nvim` for file picking, explorer, notifications, status column, inlay hint toggles, and lazygit integration
- `snacks.nvim` extras for git browse, file rename, smooth scrolling, and inline image rendering
- `snacks.nvim` GitHub integration for issues and pull requests via the `gh` CLI
- `blink.cmp` completion with LSP, snippets, path, buffer, and on-demand Minuet AI suggestions
- `minuet-ai.nvim` inline suggestions backed by the OpenAI API
- Built-in Neovim LSP configuration for Nix, Go, Rust, TypeScript, Terraform, YAML, Markdown, and Python via `ty`
- `nvim-treesitter` syntax parsing for the main languages used in this repository
- `conform.nvim` formatting on save, including `nixfmt`, `prettier`, `rustfmt`, `gofmt`, and `ruff_format`
- `gitsigns.nvim`, `lualine.nvim`, `flash.nvim`, `which-key.nvim`, `trouble.nvim`, and `render-markdown.nvim`
- Markdown rendering uses inline icons only, with gutter sign markers disabled to avoid duplicates

## Minuet

- Store the OpenAI API key in `secrets/openai-api-key.age` and apply your Home Manager configuration before launching Neovim.
- The default setup reads the decrypted key from the agenix runtime path exposed to Neovim as `vim.g.openai_api_key_path`.
- Inline suggestions use Minuet's virtual text frontend to avoid duplicate OpenAI API requests from the completion menu.
- Press `<A-y>` to open Minuet suggestions in the `blink.cmp` menu on demand.

Create or update the secret with:

```bash
EDITOR=vim agenix -e secrets/openai-api-key.age
```

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
- `<A-a>`: accept current Minuet inline suggestion
- `<A-l>`: accept current Minuet suggestion line
- `<A-e>`: dismiss current Minuet suggestion
- `<A-y>`: request Minuet completion in the blink menu

## Usage

```bash
nvim filename.txt
vim filename.txt
vi filename.txt
```

## Files

- `modules/vim/default.nix`: Home Manager wiring
- `modules/vim/files/config/init.lua`: main Neovim configuration
- `themes/exports/nvim/*.lua`: generated colorscheme definitions
