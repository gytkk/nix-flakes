local M = {}

M.conform = {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  keys = {
    { "<leader>cf", function() require("conform").format({ async = true }) end, mode = "", desc = "Format Buffer" },
  },
  opts = {
    format_on_save = {
      lsp_format = "fallback",
      timeout_ms = 1000,
    },
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

M.rendermd = {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  ft = { "markdown" },
  opts = {
    sign = {
      enabled = false,
    },
  },
}

return M
