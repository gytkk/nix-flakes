-- Basic vim settings (migrated from extraConfig vimscript)
vim.cmd([[
  syntax enable
  syntax sync fromstart
  filetype plugin indent on
  set encoding=utf-8
  set fileencoding=utf-8
  set mouse=a
  set ruler
  set nu
  set ru
  set termguicolors
  set mousescroll=ver:1,hor:1
]])

-- Leader key (must be set before lazy.nvim loads plugins)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Use system clipboard
vim.opt.clipboard:append("unnamedplus")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    {
      "folke/snacks.nvim",
      priority = 1000,
      lazy = false,
      ---@type snacks.Config
      opts = {
        explorer = { enabled = true },
        picker = {
          enabled = true,
          sources = {
            explorer = {
              layout = { preset = "sidebar" },
            },
          },
        },
        notifier = { enabled = true },
        bigfile = { enabled = true },
        indent = { enabled = true },
        input = { enabled = true },
        quickfile = { enabled = true },
        scope = { enabled = true },
        statuscolumn = { enabled = true },
        words = { enabled = true },
      },
      keys = {
        -- Explorer
        { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },
        -- Picker: files
        { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
        { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent Files" },
        { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
        -- Picker: search
        { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
        { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Grep Word", mode = { "n", "x" } },
        { "<leader>s/", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
        -- Picker: git
        { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
        { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git Log" },
        -- Picker: LSP
        { "gd", function() Snacks.picker.lsp_definitions() end, desc = "Goto Definition" },
        { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "References" },
        { "gi", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
        -- Picker: misc
        { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
        { "<leader>fh", function() Snacks.picker.help() end, desc = "Help Pages" },
        -- Notifier
        { "<leader>n", function() Snacks.notifier.show_history() end, desc = "Notification History" },
      },
    },
    { "nvim-tree/nvim-web-devicons", lazy = true },
    {
      "folke/flash.nvim",
      event = "VeryLazy",
      opts = {},
      keys = {
        { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
        { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
        { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
        { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
        { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
      },
    },
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      opts = {
        preset = "modern",
        delay = 100,
      },
    },
    {
      "onelight",
      virtual = true,
      priority = 1000,
      config = function()
        local cfg_dir = vim.fn.stdpath("config")
        package.loaded["onelight"] = nil
        dofile(cfg_dir .. "/onelight.lua").setup()
      end,
    },
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      event = { "BufReadPost", "BufNewFile" },
      config = function()
        require("nvim-treesitter").setup({
          ensure_installed = {
            "go", "gomod", "gosum",
            "rust",
            "typescript", "tsx", "javascript",
            "nix",
            "hcl", "terraform",
            "lua", "vim", "vimdoc", "query",
            "json", "yaml", "toml", "markdown", "markdown_inline",
            "bash", "dockerfile", "html", "css",
          },
          auto_install = true,
        })
      end,
    },
    {
      "saghen/blink.cmp",
      version = "1.*",
      dependencies = { "rafamadriz/friendly-snippets" },
      event = "InsertEnter",
      opts = {
        keymap = { preset = "default" },
        appearance = { nerd_font_variant = "mono" },
        completion = {
          documentation = { auto_show = true, auto_show_delay_ms = 300 },
          ghost_text = { enabled = true },
        },
        sources = {
          default = { "lsp", "path", "snippets", "buffer" },
        },
        signature = { enabled = true },
      },
      opts_extend = { "sources.default" },
    },
    {
      "neovim/nvim-lspconfig",
      dependencies = { "saghen/blink.cmp" },
      event = { "BufReadPre", "BufNewFile" },
      config = function()
        local capabilities = require("blink.cmp").get_lsp_capabilities()
        local servers = { "nixd", "gopls", "rust_analyzer", "ts_ls", "terraformls", "yamlls", "marksman" }
        for _, server in ipairs(servers) do
          vim.lsp.config(server, { capabilities = capabilities })
        end
        vim.lsp.enable(servers)

        vim.diagnostic.config({
          virtual_lines = { current_line = true },
        })

        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous Diagnostic" })
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
        vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics List" })

        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(args)
            local opts = { buffer = args.buf }
            vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
            vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
          end,
        })
      end,
    },
    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      event = "VeryLazy",
      opts = {
        options = {
          theme = "auto",
          component_separators = { left = "|", right = "|" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      },
    },
    {
      "lewis6991/gitsigns.nvim",
      event = { "BufReadPre", "BufNewFile" },
      opts = {
        signs = {
          add = { text = "+" },
          change = { text = "~" },
          delete = { text = "_" },
          topdelete = { text = "\u{203e}" },
          changedelete = { text = "~" },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
          end
          map("n", "]h", gs.next_hunk, "Next Hunk")
          map("n", "[h", gs.prev_hunk, "Previous Hunk")
          map("n", "<leader>hs", gs.stage_hunk, "Stage Hunk")
          map("n", "<leader>hr", gs.reset_hunk, "Reset Hunk")
          map("n", "<leader>hp", gs.preview_hunk, "Preview Hunk")
          map("n", "<leader>hb", function() gs.blame_line() end, "Blame Line")
        end,
      },
    },
    {
      "stevearc/conform.nvim",
      event = "BufWritePre",
      cmd = "ConformInfo",
      keys = {
        { "<leader>cf", function() require("conform").format({ async = true }) end, mode = "", desc = "Format Buffer" },
      },
      opts = {
        format_on_save = {
          lsp_format = "fallback",
          timeout_ms = 500,
        },
        formatters_by_ft = {
          nix = { "nixfmt" },
          go = { "gofmt" },
          rust = { "rustfmt" },
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          typescript = { "prettier" },
          typescriptreact = { "prettier" },
          json = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
          html = { "prettier" },
          css = { "prettier" },
          python = { "ruff_format" },
        },
      },
    },
    {
      "folke/trouble.nvim",
      cmd = "Trouble",
      opts = {},
      keys = {
        { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
        { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
        { "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols (Trouble)" },
        { "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP Definitions / References (Trouble)" },
        { "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List (Trouble)" },
        { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List (Trouble)" },
      },
    },
  },
})
