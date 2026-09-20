-- Run with: nvim --headless -u NONE -i NONE -n -l modules/vim/tests/grep-refresh.lua
local module_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local snacks_dir = vim.fn.stdpath("data") .. "/lazy/snacks.nvim"
assert(vim.fn.isdirectory(snacks_dir) == 1, "Install snacks.nvim with Lazy before running this test")

local fixture_dir = vim.fn.tempname()
vim.fn.mkdir(fixture_dir, "p")
local fixture = fixture_dir .. "/fixture.txt"
vim.fn.writefile({ "STALE_TOKEN" }, fixture)

local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n" }, { rpc = true })
assert(child > 0, "Could not start embedded Neovim")
local timer = vim.defer_fn(function() vim.fn.jobstop(child) end, 15000)
local function exec(code, ...)
  return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
end

local ok, err = xpcall(function()
  vim.rpcrequest(child, "nvim_ui_attach", 100, 30, { rgb = true })
  exec([=[
    local module_dir, snacks_dir, fixture_dir, fixture = ...
    vim.opt.rtp:prepend(snacks_dir)
    vim.o.autoread = true
    vim.o.more = false
    errors = {}
    vim.notify = function(message, level)
      if level == vim.log.levels.ERROR then errors[#errors + 1] = message end
    end
    vim.fn.chdir(fixture_dir)
    vim.cmd.edit(vim.fn.fnameescape(fixture))
    fixture_buf = vim.api.nvim_get_current_buf()

    local spec = dofile(module_dir .. "/files/config/plugins/snacks.lua")
    require("snacks").setup({ picker = spec.opts.picker })
    callbacks = {}
    for _, key in ipairs(spec.keys) do callbacks[key[1]] = key[2] end

    function open_grep()
      callbacks["<leader>sg"]()
      local picker = assert(Snacks.picker.get({ tab = false })[1], "grep picker did not open")
      assert(vim.wait(1000, function()
        return picker.input and picker.input.win and type(picker.input.win.buf) == "number"
      end, 10), "grep input did not initialize")
      picker.input:set("", "STALE_TOKEN")
      picker:find({ refresh = false })
      return picker
    end

    function wait_count(picker, count)
      assert(vim.wait(3000, function()
        return not picker.closed and picker:count() == count and not picker:is_active()
      end, 20), ("expected %d results, got %d"):format(count, picker:count()))
    end

    function save_lines(lines)
      vim.api.nvim_buf_set_lines(fixture_buf, 0, -1, false, lines)
      vim.api.nvim_buf_call(fixture_buf, function() vim.cmd.write() end)
    end
  ]=], module_dir, snacks_dir, fixture_dir, fixture)

  -- Saving while grep stays open must remove a stale match.
  exec([=[
    picker = open_grep()
    wait_count(picker, 1)
    save_lines({ "replacement text" })
    wait_count(picker, 0)
  ]=])

  -- An external edit followed by FocusGained must refresh without losing query or cwd.
  exec([=[
    vim.fn.writefile({ "STALE_TOKEN" }, ...)
    vim.api.nvim_exec_autocmds("FocusGained", {})
    wait_count(picker, 1)
    assert(picker.input.filter.search == "STALE_TOKEN", "refresh lost the grep query")
    assert(picker.input.filter.cwd == vim.fn.getcwd(), "refresh lost the grep cwd")
  ]=], fixture)

  -- A retained match in the same file must display its new text in the preview.
  exec([=[
    save_lines({ "STALE_TOKEN updated preview" })
    assert(vim.wait(3000, function()
      local buf = picker.preview.win.buf
      return buf and vim.api.nvim_buf_is_valid(buf)
        and vim.tbl_contains(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "STALE_TOKEN updated preview")
    end, 20), "preview retained the old file contents")
    vim.fn.writefile({ "external replacement" }, ...)
    vim.api.nvim_exec_autocmds("FocusGained", {})
    wait_count(picker, 0)
  ]=], fixture)

  -- Closing and resuming reruns grep against the saved file.
  exec([=[
    save_lines({ "STALE_TOKEN" })
    wait_count(picker, 1)
    picker:close()
    vim.wait(100)
    save_lines({ "replacement text" })
    callbacks["<leader>sr"]()
    picker = assert(Snacks.picker.get({ tab = false })[1], "resume did not open grep")
    wait_count(picker, 0)
    assert(picker.input.filter.search == "STALE_TOKEN", "resume lost the grep query")
    assert(picker.input.filter.cwd == vim.fn.getcwd(), "resume lost the grep cwd")
  ]=])

  -- A resumed picker must retain the save watcher installed by on_show.
  exec([=[
    vim.fn.writefile({ "STALE_TOKEN" }, ...)
    vim.api.nvim_exec_autocmds("FocusGained", {})
    wait_count(picker, 1)
    save_lines({ "replacement text" })
    wait_count(picker, 0)
    picker:close()
    vim.wait(100)
    vim.api.nvim_exec_autocmds("FocusGained", {})
    vim.wait(100)
    assert(#errors == 0, table.concat(errors, "\n"))
    local messages = vim.api.nvim_exec2("messages", { output = true }).output
    assert(not messages:find("E5108") and not messages:find("Error executing"), messages)
  ]=], fixture)

  print("PASS: grep refreshes after saves, external changes, and resume")
end, debug.traceback)

timer:stop()
vim.fn.jobstop(child)
vim.fn.delete(fixture_dir, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
