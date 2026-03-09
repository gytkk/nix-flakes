-- Leader key (must be set before lazy.nvim loads plugins)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

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
        picker = { enabled = true },
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
      "sonph/onehalf",
      priority = 1000,
      config = function(plugin)
        vim.opt.rtp:append(plugin.dir .. "/vim")
        vim.o.background = "light"
        vim.cmd.colorscheme("onehalflight")
      end,
    },
  },
})
