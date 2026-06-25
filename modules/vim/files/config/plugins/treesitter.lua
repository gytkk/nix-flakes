return {
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
