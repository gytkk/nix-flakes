# Vim Module

This module configures Neovim as the primary editor with a modern Lua-based setup managed through Home Manager.

## What it does

- Installs and configures Neovim as the default editor
- Creates `vi` and `vim` aliases that point to `nvim`
- Loads the Neovim configuration from modular Lua files under `modules/vim/files/config/`
- Exposes every generated colorscheme from `themes/exports/nvim/`
- Loads `monokai-pro-classic` by default and falls back to it if a selected exported theme is missing

## Included Features

- `lazy.nvim` plugin management
- `snacks.nvim` for file picking, explorer, notifications, status column, inlay hint toggles, and lazygit integration
- `snacks.nvim` extras for git browse, file rename, smooth scrolling, and inline image rendering
- `snacks.nvim` GitHub integration for issues and pull requests via the `gh` CLI
- `persistence.nvim` for directory and branch-aware session saving and restore on bare `nvim` startup
- `blink.cmp` completion with LSP, snippets, path, buffer, and on-demand Minuet AI suggestions
- `minuet-ai.nvim` inline suggestions backed by the OpenAI API
- Built-in Neovim LSP configuration for Nix, Go, Rust, TypeScript, Terraform, YAML, Markdown, and Python via `ty`
- `nvim-treesitter` syntax parsing for the main languages used in this repository
- `conform.nvim` formatting on save, including `nixfmt`, `prettier`, `rustfmt`, `gofmt`, and `ruff_format`
- `gitsigns.nvim`, `lualine.nvim`, `flash.nvim`, `which-key.nvim`, `trouble.nvim`, and `render-markdown.nvim`
- Markdown rendering uses inline icons only, with gutter sign markers disabled to avoid duplicates

## Minuet

- Store the OpenAI API key in `secrets/openai-api-key.age` before launching Neovim.
- NixOS hosts decrypt the secret with system agenix under `/run/agenix/openai-api-key`; home-only environments decrypt it with Home Manager agenix.
- The vim module wires the decrypted agenix path into Neovim as `vim.g.openai_api_key_path` on every environment.
- Inline suggestions use Minuet's virtual text frontend to avoid duplicate OpenAI API requests from the completion menu.
- Press `<Tab>` to accept the current Minuet inline suggestion when one is visible.
- Press `<C-y>` to open Minuet suggestions in the `blink.cmp` menu on demand.

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
- `<leader>qs`: restore the current directory session
- `<leader>qS`: select a saved session
- `<leader>ql`: restore the last saved session
- `<leader>qd`: stop saving the current session on exit
- `gd`: go to definition
- `gb`: jump back in the jumplist
- `<leader>cR`: rename current file with LSP-aware updates
- `<leader>ud`: toggle diagnostics
- `<leader>uh`: toggle LSP inlay hints
- `<leader>ul`: toggle line numbers
- `<leader>uS`: toggle smooth scrolling
- `<leader>uw`: toggle wrap
- `<leader>cf`: format current buffer
- `<Tab>`: accept current Minuet inline suggestion, otherwise fall back to the usual blink/snippet behavior
- `<C-g>l`: accept current Minuet suggestion line
- `<C-g>e`: dismiss current Minuet suggestion
- `<C-g>n`: show next Minuet inline suggestion
- `<C-g>p`: show previous Minuet inline suggestion
- `<C-y>`: request Minuet completion in the blink menu

## Usage

Open a project with the saved session and the left file explorer:

```bash
nvim
```

Opening a specific file skips startup session restore and explorer opening:

```bash
nvim filename.txt
vim filename.txt
vi filename.txt
```

## Files

- `modules/vim/default.nix`: Home Manager wiring
- `modules/vim/files/config/init.lua`: small bootstrap for options, lazy.nvim, plugin specs, and startup hooks
- `modules/vim/files/config/*.lua`: focused modules for options, lazy.nvim bootstrap, theme loading, LSP, session restore, AI helpers, and autocmds
- `modules/vim/files/config/plugins/*.lua`: plugin specs grouped by feature area
- `themes/exports/nvim/*.lua`: generated colorscheme definitions
