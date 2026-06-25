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

return {
  "neovim/nvim-lspconfig",
  dependencies = { "saghen/blink.cmp" },
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    vim.lsp.config("*", {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
    })

    vim.lsp.config("rust_analyzer", {
      settings = {
        ["rust-analyzer"] = {
          files = { watcher = "server" },
        },
      },
    })

    vim.lsp.enable(lspServers)
    setupLspDiagnostics()

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = onLspAttach,
    })
  end,
}
