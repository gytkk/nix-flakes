local M = {}

local skip_format_on_save = {
  markdown = true,
  yaml = true,
}

M.conform = {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    { "<leader>cf", function() require("conform").format({ async = true }) end, mode = "", desc = "Format Buffer" },
  },
  opts = {
    format_on_save = function(bufnr)
      -- These filetypes are still formattable on demand with <leader>cf.
      if skip_format_on_save[vim.bo[bufnr].filetype] then
        return
      end

      return {
        lsp_format = "fallback",
        timeout_ms = 1000,
      }
    end,
    formatters_by_ft = {
      nix = { "nixfmt" },
      go = { "gofmt" },
      rust = { "rustfmt" },
      javascript = { "biome" },
      javascriptreact = { "biome" },
      typescript = { "biome" },
      typescriptreact = { "biome" },
      json = { "biome" },
      jsonc = { "biome" },
      css = { "biome" },
      yaml = { "prettier" },
      markdown = { "prettier" },
      html = { "prettier" },
      python = { "ruff_format" },
    },
  },
}

M.markview = {
  "OXY2DEV/markview.nvim",
  lazy = false,
}

return M
