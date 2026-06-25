local M = {}

local function refreshReloadedBuffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return end

  local has_treesitter = pcall(vim.treesitter.get_parser, buf)
  if has_treesitter then
    pcall(vim.treesitter.stop, buf)
    pcall(vim.treesitter.start, buf)
  end

  vim.bo[buf].syntax = "ON"
  pcall(vim.api.nvim_buf_call, buf, function()
    vim.cmd("silent! syntax sync fromstart")
  end)

  if vim.api.nvim_get_current_buf() == buf then
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
        vim.cmd("redraw!")
      end
    end)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
      vim.schedule(function()
        local win = vim.api.nvim_get_current_win()
        if not vim.api.nvim_win_is_valid(win) then return end
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "" and vim.bo[buf].buflisted then
          local whl = vim.wo[win].winhighlight
          if whl and whl:find("Snacks") then
            vim.wo[win].winhighlight = ""
          end
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI", "TermClose", "TermLeave" }, {
    callback = function()
      if vim.fn.mode() == "c" then return end

      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].buftype ~= "" or vim.bo[buf].modified then return end

      vim.cmd("checktime")
    end,
  })

  vim.api.nvim_create_autocmd("FileChangedShellPost", {
    callback = function(event)
      refreshReloadedBuffer(event.buf)
    end,
  })
end

return M
