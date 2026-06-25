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
vim.opt.updatetime = 1000
vim.opt.sessionoptions:remove("blank")

vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smartindent = true
vim.opt.autoindent = true

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.autoread = true

vim.g.mapleader = " "
vim.g.maplocalleader = " "
