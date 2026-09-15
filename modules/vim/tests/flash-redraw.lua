-- Run with: nvim --headless -u NONE -i NONE -n -l modules/vim/tests/flash-redraw.lua
local module_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local flash_dir = vim.fn.stdpath("data") .. "/lazy/flash.nvim"
assert(vim.fn.isdirectory(flash_dir) == 1, "Install flash.nvim with Lazy before running this test")

local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n" }, { rpc = true })
assert(child > 0, "Could not start embedded Neovim")
local fixture = vim.fn.tempname() .. ".mdx"
local timer = vim.defer_fn(function() vim.fn.jobstop(child) end, 10000)
local function exec(code, ...)
  return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
end
local function input(keys)
  vim.rpcrequest(child, "nvim_input", keys)
  vim.wait(100)
end

local ok, err = xpcall(function()
  vim.rpcrequest(child, "nvim_ui_attach", 100, 30, { rgb = true })
  exec([[
    local module_dir, flash_dir, fixture = ...
    vim.opt.rtp:prepend(flash_dir)
    vim.opt.rtp:prepend(module_dir .. '/files')
    vim.o.more = false
    _G.errors = {}
    vim.notify = function(msg, level)
      if level == vim.log.levels.ERROR then errors[#errors + 1] = msg end
    end
    require('flash').setup(require('config.plugins.ui').flash.opts)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      '# Example', '', '<Notice>data data data</Notice>', '', 'Some data text.',
    })
    vim.bo.filetype = 'markdown'
    vim.api.nvim_buf_set_name(0, fixture)
    _G.writes = 0
    vim.api.nvim_create_autocmd('BufWritePost', { callback = function()
      writes = writes + 1
      _G.saved_cursor = vim.api.nvim_win_get_cursor(0)
    end })
  ]], module_dir, flash_dir, fixture)

  input("ggjj0fd")
  input(":w\r")
  -- Dismiss any error prompt so the failing version can report instead of hanging.
  input("\027\r")
  local result = exec([[
    return {
      errors = errors, messages = vim.api.nvim_exec2('messages', { output = true }).output,
      writes = writes, cursor = saved_cursor,
    }
  ]])
  assert(#result.errors == 0, table.concat(result.errors, "\n"))
  assert(not result.messages:find("E5108"), result.messages)
  assert(result.writes == 1, "The MDX buffer was not saved")
  assert(vim.deep_equal(result.cursor, { 3, 8 }), "Flash did not jump to the first 'd'")
  assert(vim.fn.filereadable(fixture) == 1, "The MDX file was not written")

  exec([[
    local Search = require('flash.search')
    local State = require('flash.state')
    local Hacks = require('flash.hacks')
    local state = State.new({ pattern = 'data' })
    local matches = Search.new(vim.api.nvim_get_current_win(), state):get()
    assert(#matches == 4, 'Expected four search matches')
    assert(matches[1].pos[2] == 8 and matches[1].end_pos[2] == 11, 'Incorrect match bounds')
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.fn.searchpos('data', 'W')
    local before = Hacks.get_end_pos({ 3, 8 })
    Hacks.save_incsearch_state()
    vim.fn.searchpos('Example', 'bw')
    Hacks.restore_incsearch_state()
    assert(vim.deep_equal(Hacks.get_end_pos({ 3, 8 }), before), 'Search state was not restored')
    state:hide()
  ]])
  print("PASS: Flash motion, MDX save/redraw, search bounds, and search-state restoration")
end, debug.traceback)

timer:stop()
vim.fn.jobstop(child)
vim.fn.delete(fixture)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
