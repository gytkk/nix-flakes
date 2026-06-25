local ui = require("config.plugins.ui")
local completion = require("config.plugins.completion")
local editing = require("config.plugins.editing")
local session = require("config.session")

return {
  require("config.plugins.snacks"),
  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "MunifTanjim/nui.nvim",        lazy = true },
  ui.noice,
  ui.flash,
  ui.whichkey,
  require("config.theme"),
  require("config.plugins.treesitter"),
  completion.minuet,
  completion.blink,
  require("config.lsp"),
  ui.lualine,
  require("config.plugins.git"),
  editing.conform,
  editing.rendermd,
  ui.trouble,
  session.plugin,
}
