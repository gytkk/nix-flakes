require("config.options")

local lazypath = require("config.lazy")
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = require("config.plugins"),
})

-- Register lazy-loading handlers before syntax activation triggers filetype events.
vim.cmd("syntax enable")
vim.cmd("syntax sync fromstart")
vim.cmd("filetype plugin indent on")

Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.scroll():map("<leader>uS")
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")

require("config.autocmds").setup()
require("config.session").setup()
