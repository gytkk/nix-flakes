-- Options
vim.cmd("syntax enable")
vim.cmd("syntax sync fromstart")
vim.cmd("filetype plugin indent on")
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.opt.mouse = "a"
vim.opt.ruler = true
vim.opt.number = true
vim.opt.termguicolors = true
vim.opt.mousescroll = "ver:1,hor:1"
vim.opt.clipboard:append("unnamedplus")

-- Indentation
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Leader key (must be set before lazy.nvim loads plugins)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local exportedThemeName = vim.g.nix_flakes_theme or "one-half-light"
local fallbackExportedThemeName = "one-half-light"

local function load_exported_theme(theme_name)
  local theme_path = vim.fn.stdpath("config") .. "/themes/" .. theme_name .. ".lua"
  if not (vim.uv or vim.loop).fs_stat(theme_path) then
    return false, ("theme file not found: %s"):format(theme_path)
  end

  local ok, theme_or_err = pcall(dofile, theme_path)
  if not ok then
    return false, theme_or_err
  end
  if type(theme_or_err) ~= "table" or type(theme_or_err.setup) ~= "function" then
    return false, ("theme file does not export setup(): %s"):format(theme_path)
  end

  local setup_ok, setup_err = pcall(theme_or_err.setup)
  if not setup_ok then
    return false, setup_err
  end

  return true
end

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-------------------------------------------------------------------------------
-- Plugin specs
-------------------------------------------------------------------------------

local snacks = {
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
          actions = {
            -- When the explorer is the sole window, open files in a new
            -- split instead of replacing the explorer.
            confirm_with_window = function(picker, item)
              if not item or item.dir then
                picker:action("confirm")
                return
              end
              -- Check for a non-sidebar edit window
              for _, w in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_is_valid(w)
                    and vim.api.nvim_win_get_config(w).relative == ""
                    and not vim.w[w].snacks_layout
                then
                  picker:action("confirm")
                  return
                end
              end
              -- No edit window: open the file directly in a new split
              local file = item.file or item.text
              if not file then return end
              local explorer_win = vim.api.nvim_get_current_win()
              vim.cmd("botright vsplit " .. vim.fn.fnameescape(file))
              vim.schedule(function()
                if vim.api.nvim_win_is_valid(explorer_win) then
                  vim.api.nvim_win_set_width(explorer_win, 40)
                end
              end)
            end,
          },
          win = {
            list = {
              keys = {
                ["<CR>"] = "confirm_with_window",
                ["l"] = "confirm_with_window",
              },
            },
          },
        },
      },
    },
    notifier = { enabled = true },
    notify = { enabled = true },
    bigfile = { enabled = true },
    gh = { enabled = true },
    gitbrowse = { enabled = true },
    image = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    lazygit = { enabled = true },
    quickfile = { enabled = true },
    rename = { enabled = true },
    scroll = { enabled = false },
    scope = { enabled = true },
    statuscolumn = { enabled = true },
    toggle = { enabled = true },
    words = { enabled = true },
  },
  keys = {
    -- Explorer
    { "<leader>e",  function() Snacks.explorer() end,                         desc = "File Explorer" },
    -- Picker: files
    { "<leader>ff", function() Snacks.picker.files() end,                     desc = "Find Files" },
    { "<leader>fr", function() Snacks.picker.recent() end,                    desc = "Recent Files" },
    { "<leader>b",  function() Snacks.picker.buffers() end,                   desc = "Buffers" },
    { "<leader>fb", function() Snacks.picker.buffers() end,                   desc = "Buffers" },
    -- Picker: search
    { "<leader>/",  function() Snacks.picker.grep() end,                      desc = "Grep (Project)" },
    { "<leader>sg", function() Snacks.picker.grep() end,                      desc = "Grep" },
    { "<leader>sw", function() Snacks.picker.grep_word() end,                 desc = "Grep Word",                  mode = { "n", "x" } },
    { "<leader>s/", function() Snacks.picker.lines() end,                     desc = "Buffer Lines" },
    -- Picker: git
    { "<leader>gb", function() Snacks.picker.git_branches() end,              desc = "Git Branches" },
    { "<leader>gd", function() Snacks.picker.git_diff() end,                  desc = "Git Diff (Hunks)" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end,              desc = "Git Log File" },
    { "<leader>gs", function() Snacks.picker.git_status() end,                desc = "Git Status" },
    { "<leader>gS", function() Snacks.picker.git_stash() end,                 desc = "Git Stash" },
    { "<leader>gl", function() Snacks.picker.git_log() end,                   desc = "Git Log" },
    { "<leader>gL", function() Snacks.picker.git_log_line() end,              desc = "Git Log Line" },
    { "<leader>gg", function() Snacks.lazygit() end,                          desc = "Lazygit" },
    { "<leader>gB", function() Snacks.gitbrowse() end,                        desc = "Git Browse",                 mode = { "n", "v" } },
    { "<leader>gh", function() Snacks.git.blame_line() end,                   desc = "Git Blame Line" },
    -- Picker: GitHub
    { "<leader>gi", function() Snacks.picker.gh_issue() end,                  desc = "GitHub Issues (Open)" },
    { "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end, desc = "GitHub Issues (All)" },
    { "<leader>gp", function() Snacks.picker.gh_pr() end,                     desc = "GitHub Pull Requests (Open)" },
    { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end,    desc = "GitHub Pull Requests (All)" },
    -- Picker: LSP
    { "gd",         function() Snacks.picker.lsp_definitions() end,           desc = "Goto Definition" },
    { "gb",         "<C-o>",                                                 desc = "Jump Back" },
    { "gr",         function() Snacks.picker.lsp_references() end,            nowait = true,                       desc = "References" },
    { "gi",         function() Snacks.picker.lsp_implementations() end,       desc = "Goto Implementation" },
    -- Picker: misc
    { "<leader>:",  function() Snacks.picker.command_history() end,           desc = "Command History" },
    { "<leader>cR", function() Snacks.rename.rename_file() end,               desc = "Rename File" },
    { "<leader>fh", function() Snacks.picker.help() end,                      desc = "Help Pages" },
    -- Notifier
    { "<leader>n",  function() Snacks.notifier.show_history() end,            desc = "Notification History" },
  },
}

local noice = {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    cmdline = {
      enabled = true,
      view = "cmdline_popup",
    },
    messages = {
      enabled = true,
      view = "notify",
      view_error = "notify",
      view_warn = "notify",
    },
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
      hover = { enabled = true },
      signature = { enabled = false }, -- blink.cmp handles signature
      progress = { enabled = true, view = "mini" },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      lsp_doc_border = true,
    },
    routes = {
      -- skip "written" messages
      { filter = { event = "msg_show", kind = "", find = "written" }, opts = { skip = true } },
    },
  },
  keys = {
    { "<leader>sn",  "",                                             desc = "+noice" },
    { "<leader>snl", function() require("noice").cmd("last") end,    desc = "Noice Last Message" },
    { "<leader>snh", function() require("noice").cmd("history") end, desc = "Noice History" },
    { "<leader>sna", function() require("noice").cmd("all") end,     desc = "Noice All" },
    { "<leader>snd", function() require("noice").cmd("dismiss") end, desc = "Dismiss All" },
  },
}

local flash = {
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = {},
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
    { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
    { "r", mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
    { "R", mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
  },
}

local whichkey = {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    delay = 100,
  },
}

local exportedTheme = {
  "nix-flakes-exported-theme",
  virtual = true,
  priority = 1000,
  config = function()
    local ok, err = load_exported_theme(exportedThemeName)
    if ok then
      return
    end

    if exportedThemeName ~= fallbackExportedThemeName then
      vim.notify(
        ("Failed to load theme '%s': %s. Falling back to '%s'."):format(
          exportedThemeName,
          err,
          fallbackExportedThemeName
        ),
        vim.log.levels.WARN
      )

      local fallback_ok, fallback_err = load_exported_theme(fallbackExportedThemeName)
      if fallback_ok then
        return
      end

      err = fallback_err
    end

    vim.notify(
      ("Failed to load fallback theme '%s': %s"):format(fallbackExportedThemeName, err),
      vim.log.levels.ERROR
    )
  end,
}

local treesitter = {
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
}

local openaiApiKey

local function resolveAgenixPath(path)
  local resolved = path

  if resolved:find("${XDG_RUNTIME_DIR}", 1, true) then
    local runtimeDir = (vim.env.XDG_RUNTIME_DIR or ""):gsub("/+$", "")
    resolved = resolved:gsub("%${XDG_RUNTIME_DIR}", runtimeDir)
  end

  local command = resolved:match("%$%((.-)%)")
  if command then
    local result = vim.system({ "sh", "-lc", command }, { text = true }):wait()
    if result.code ~= 0 then
      return nil, ("Failed to resolve agenix runtime directory with `%s`."):format(command)
    end

    local runtimeDir = vim.trim(result.stdout or ""):gsub("/+$", "")
    resolved = resolved:gsub("%$%((.-)%)", runtimeDir, 1)
  end

  return resolved
end

local function readOpenAIKeyFile(path)
  if type(path) ~= "string" or path == "" then
    return nil, "Agenix secret path is not configured."
  end

  local resolvedPath, pathErr = resolveAgenixPath(path)
  if not resolvedPath then
    return nil, pathErr
  end

  if not vim.uv.fs_stat(resolvedPath) then
    return nil, ("Agenix secret file does not exist at %s."):format(resolvedPath)
  end

  local ok, lines = pcall(vim.fn.readfile, resolvedPath)
  if not ok then
    return nil, ("Failed to read agenix secret at %s."):format(resolvedPath)
  end

  local value = vim.trim(table.concat(lines, "\n"))
  if value == "" then
    return nil, ("Agenix secret at %s is empty."):format(resolvedPath)
  end

  return value
end

local function getOpenAIKey()
  if openaiApiKey then
    return openaiApiKey
  end

  local value, err = readOpenAIKeyFile(vim.g.openai_api_key_path)
  if value then
    openaiApiKey = value
    return openaiApiKey
  end

  error(
    "Failed to read OPENAI_API_KEY from agenix. "
      .. "Create secrets/openai-api-key.age, run home-manager switch, and ensure Neovim receives "
      .. "vim.g.openai_api_key_path. Last error: "
      .. err
  )
end

local minuet = {
  "milanglacier/minuet-ai.nvim",
  event = "InsertEnter",
  config = function()
    require("minuet").setup({
      provider = "openai",
      n_completions = 1,
      context_window = 8000,
      throttle = 500,
      debounce = 200,
      request_timeout = 2.5,
      notify = "warn",
      after_cursor_filter_length = 24,
      before_cursor_filter_length = 4,
      blink = {
        enable_auto_complete = false,
      },
      virtualtext = {
        auto_trigger_ft = {
          "bash",
          "go",
          "gomod",
          "gosum",
          "hcl",
          "javascript",
          "javascriptreact",
          "json",
          "lua",
          "nix",
          "python",
          "rust",
          "sh",
          "terraform",
          "toml",
          "tsx",
          "typescript",
          "typescriptreact",
          "yaml",
          "zsh",
        },
        keymap = {
          accept = nil,
          accept_line = "<C-g>l",
          accept_n_lines = "<C-g>a",
          next = "<C-g>n",
          prev = "<C-g>p",
          dismiss = "<C-g>e",
        },
      },
      provider_options = {
        openai = {
          model = "gpt-5.4-nano",
          api_key = getOpenAIKey,
          optional = {
            max_completion_tokens = 128,
            reasoning_effort = "none",
          },
        },
      },
    })
  end,
}

local blink = {
  "saghen/blink.cmp",
  version = "1.*",
  dependencies = {
    "rafamadriz/friendly-snippets",
    "milanglacier/minuet-ai.nvim",
  },
  event = "InsertEnter",
  opts = function()
    return {
      keymap = {
        preset = "super-tab",
        ["<Tab>"] = {
          function(cmp)
            local minuetVirtualText = require("minuet.virtualtext").action
            if minuetVirtualText.is_visible() then
              minuetVirtualText.accept()
              return true
            end

            if cmp.snippet_active() then
              return cmp.accept()
            end

            return cmp.select_and_accept()
          end,
          "snippet_forward",
          "fallback",
        },
        ["<C-y>"] = require("minuet").make_blink_map(),
      },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
        ghost_text = { enabled = true },
        trigger = { prefetch_on_insert = false },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            async = true,
            timeout_ms = 2500,
            score_offset = 50,
          },
        },
      },
      signature = { enabled = true },
    }
  end,
  opts_extend = { "sources.default" },
}

local lspServers = { "nixd", "gopls", "rust_analyzer", "ts_ls", "terraformls", "yamlls", "marksman", "ty" }

local function setupLspDiagnostics()
  vim.diagnostic.config({
    virtual_lines = { current_line = true },
  })

  vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous Diagnostic" })
  vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
  vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
  vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Diagnostics List" })
end

local function onLspAttach(args)
  local client = vim.lsp.get_client_by_id(args.data.client_id)
  local opts = { buffer = args.buf }

  if client and client:supports_method("textDocument/inlayHint") then
    vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
  end

  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
end

local lspconfig = {
  "neovim/nvim-lspconfig",
  dependencies = { "saghen/blink.cmp" },
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    vim.lsp.config("*", {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
    })

    vim.lsp.enable(lspServers)
    setupLspDiagnostics()

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = onLspAttach,
    })
  end,
}

local lualine = {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    "milanglacier/minuet-ai.nvim",
  },
  event = "VeryLazy",
  opts = function()
    return {
      options = {
        theme = "auto",
        component_separators = { left = "|", right = "|" },
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { "filename" },
        lualine_x = {
          require("minuet.lualine"),
          {
            function()
              local clients = vim.lsp.get_clients({ bufnr = 0 })
              if #clients == 0 then return "-" end
              local names = {}
              for _, c in ipairs(clients) do
                table.insert(names, c.name)
              end
              return table.concat(names, ", ")
            end,
            icon = " ",
          },
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    }
  end,
}

local gitsigns = {
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
}

local conform = {
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
}

local rendermd = {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  ft = { "markdown" },
  opts = {
    sign = {
      enabled = false,
    },
  },
}

local trouble = {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {},
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",                        desc = "Diagnostics (Trouble)" },
    { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",           desc = "Buffer Diagnostics (Trouble)" },
    { "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>",                desc = "Symbols (Trouble)" },
    { "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP Definitions / References (Trouble)" },
    { "<leader>xL", "<cmd>Trouble loclist toggle<cr>",                            desc = "Location List (Trouble)" },
    { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>",                             desc = "Quickfix List (Trouble)" },
  },
}

-------------------------------------------------------------------------------
-- Setup lazy.nvim
-------------------------------------------------------------------------------

require("lazy").setup({
  spec = {
    snacks,
    { "nvim-tree/nvim-web-devicons", lazy = true },
    { "MunifTanjim/nui.nvim",        lazy = true },
    noice,
    flash,
    whichkey,
    exportedTheme,
    treesitter,
    minuet,
    blink,
    lspconfig,
    lualine,
    gitsigns,
    conform,
    rendermd,
    trouble,
  },
})

-------------------------------------------------------------------------------
-- Post-setup: Snacks toggles
-------------------------------------------------------------------------------

Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.scroll():map("<leader>uS")
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")

-------------------------------------------------------------------------------
-- Autocmds
-------------------------------------------------------------------------------

-- Reset winhighlight when a normal buffer enters a window that still
-- carries Snacks picker/explorer highlights (gray sidebar background).
-- Uses vim.schedule to run after Snacks finishes setting winhighlight.
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.schedule(function()
      local win = vim.api.nvim_get_current_win()
      if not vim.api.nvim_win_is_valid(win) then return end
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "" and vim.bo[buf].buflisted then
        local whl = vim.wo[win].winhighlight
        if whl and whl:find("Snacks") then
          vim.wo[win].winhighlight = ""
        end
      end
    end)
  end,
})

-- Open file picker when neovim starts with no arguments
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 0 then
      Snacks.picker.files()
    end
  end,
})
