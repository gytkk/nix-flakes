local lspServers = {
  "nixd",
  "gopls",
  "rust_analyzer",
  "ts_ls",
  "html",
  "cssls",
  "jsonls",
  "lua_ls",
  "bashls",
  "terraformls",
  "yamlls",
  "marksman",
  "taplo",
  "ty",
}

local diagnosticIcons = {
  [vim.diagnostic.severity.ERROR] = "●",
  [vim.diagnostic.severity.WARN] = "●",
  [vim.diagnostic.severity.INFO] = "●",
  [vim.diagnostic.severity.HINT] = "●",
}

local diagnosticHighlights = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticError",
  [vim.diagnostic.severity.WARN] = "DiagnosticWarn",
  [vim.diagnostic.severity.INFO] = "DiagnosticInfo",
  [vim.diagnostic.severity.HINT] = "DiagnosticHint",
}

local lineDiagnosticWin

local function toggleLineDiagnostics()
  if lineDiagnosticWin and vim.api.nvim_win_is_valid(lineDiagnosticWin) then
    vim.api.nvim_win_close(lineDiagnosticWin, true)
    lineDiagnosticWin = nil
    return
  end

  local _, winid = vim.diagnostic.open_float({ scope = "line" })
  lineDiagnosticWin = winid
end

local function setupLspDiagnostics()
  vim.diagnostic.config({
    virtual_lines = false,
    virtual_text = {
      current_line = true,
      spacing = 2,
      prefix = "●",
      virt_text_pos = "eol",
    },
    signs = {
      text = diagnosticIcons,
      numhl = diagnosticHighlights,
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
  })

  vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous Diagnostic" })
  vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
  vim.keymap.set("n", "<leader>d", toggleLineDiagnostics, { desc = "Toggle Line Diagnostics" })
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
