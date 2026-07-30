local ai = require("config.ai")

local M = {}

M.minuet = {
  "milanglacier/minuet-ai.nvim",
  event = "InsertEnter",
  config = function()
    require("minuet").setup({
      provider = "openai",
      n_completions = 1,
      -- Keep inline completions responsive without sending a request for every
      -- keystroke. A slightly longer timeout avoids silently dropping useful
      -- streamed completions.
      context_window = 6000,
      throttle = 900,
      debounce = 180,
      request_timeout = 4,
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
      },
      provider_options = {
        openai = {
          model = "gpt-5.6-luna",
          api_key = ai.getOpenAIKey,
          optional = {
            max_completion_tokens = 128,
            reasoning_effort = "none",
          },
        },
      },
    })
  end,
}

M.blink = {
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
            -- Keep Blink's manual Minuet source timeout aligned with
            -- minuet.request_timeout above.
            timeout_ms = 4000,
            score_offset = 50,
          },
        },
      },
      signature = { enabled = true },
    }
  end,
  opts_extend = { "sources.default" },
}

return M
