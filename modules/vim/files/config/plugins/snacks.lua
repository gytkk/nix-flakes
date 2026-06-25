return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    explorer = { enabled = true },
    picker = {
      enabled = true,
      sources = {
        explorer = {
          layout = { preset = "sidebar" },
          actions = {
            -- When the explorer is the sole window, open files in a new
            -- split instead of replacing the explorer.
            confirm_with_window = function(picker, item)
              if not item or item.dir then
                picker:action("confirm")
                return
              end
              -- Check for a non-sidebar edit window
              for _, w in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_is_valid(w)
                    and vim.api.nvim_win_get_config(w).relative == ""
                    and not vim.w[w].snacks_layout
                then
                  picker:action("confirm")
                  return
                end
              end
              -- No edit window: open the file directly in a new split
              local file = item.file or item.text
              if not file then return end
              local explorer_win = vim.api.nvim_get_current_win()
              vim.cmd("botright vsplit " .. vim.fn.fnameescape(file))
              vim.schedule(function()
                if vim.api.nvim_win_is_valid(explorer_win) then
                  vim.api.nvim_win_set_width(explorer_win, 40)
                end
              end)
            end,
          },
          win = {
            list = {
              keys = {
                ["<CR>"] = "confirm_with_window",
                ["l"] = "confirm_with_window",
              },
            },
          },
        },
      },
    },
    notifier = { enabled = true },
    notify = { enabled = true },
    bigfile = { enabled = true },
    gh = { enabled = true },
    gitbrowse = { enabled = true },
    image = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    lazygit = { enabled = true },
    quickfile = { enabled = true },
    rename = { enabled = true },
    scroll = { enabled = false },
    scope = { enabled = true },
    statuscolumn = { enabled = true },
    toggle = { enabled = true },
    words = { enabled = true },
  },
  keys = {
    -- Explorer
    { "<leader>e",  function() Snacks.explorer() end,                         desc = "File Explorer" },
    -- Picker: files
    { "<leader>ff", function() Snacks.picker.files() end,                     desc = "Find Files" },
    { "<leader>fr", function() Snacks.picker.recent() end,                    desc = "Recent Files" },
    { "<leader>b",  function() Snacks.picker.buffers() end,                   desc = "Buffers" },
    { "<leader>fb", function() Snacks.picker.buffers() end,                   desc = "Buffers" },
    -- Picker: search
    { "<leader>/",  function() Snacks.picker.grep() end,                      desc = "Grep (Project)" },
    { "<leader>sg", function() Snacks.picker.grep() end,                      desc = "Grep" },
    { "<leader>sw", function() Snacks.picker.grep_word() end,                 desc = "Grep Word",                  mode = { "n", "x" } },
    { "<leader>s/", function() Snacks.picker.lines() end,                     desc = "Buffer Lines" },
    -- Picker: git
    { "<leader>gb", function() Snacks.picker.git_branches() end,              desc = "Git Branches" },
    { "<leader>gd", function() Snacks.picker.git_diff() end,                  desc = "Git Diff (Hunks)" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end,              desc = "Git Log File" },
    { "<leader>gs", function() Snacks.picker.git_status() end,                desc = "Git Status" },
    { "<leader>gS", function() Snacks.picker.git_stash() end,                 desc = "Git Stash" },
    { "<leader>gl", function() Snacks.picker.git_log() end,                   desc = "Git Log" },
    { "<leader>gL", function() Snacks.picker.git_log_line() end,              desc = "Git Log Line" },
    { "<leader>gg", function() Snacks.lazygit() end,                          desc = "Lazygit" },
    { "<leader>gB", function() Snacks.gitbrowse() end,                        desc = "Git Browse",                 mode = { "n", "v" } },
    { "<leader>gh", function() Snacks.git.blame_line() end,                   desc = "Git Blame Line" },
    -- Picker: GitHub
    { "<leader>gi", function() Snacks.picker.gh_issue() end,                  desc = "GitHub Issues (Open)" },
    { "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end, desc = "GitHub Issues (All)" },
    { "<leader>gp", function() Snacks.picker.gh_pr() end,                     desc = "GitHub Pull Requests (Open)" },
    { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end,    desc = "GitHub Pull Requests (All)" },
    -- Picker: LSP
    { "gd",         function() Snacks.picker.lsp_definitions() end,           desc = "Goto Definition" },
    { "gb",         "<C-o>",                                                 desc = "Jump Back" },
    { "gr",         function() Snacks.picker.lsp_references() end,            nowait = true,                       desc = "References" },
    { "gi",         function() Snacks.picker.lsp_implementations() end,       desc = "Goto Implementation" },
    -- Picker: misc
    { "<leader>:",  function() Snacks.picker.command_history() end,           desc = "Command History" },
    { "<leader>cR", function() Snacks.rename.rename_file() end,               desc = "Rename File" },
    { "<leader>fh", function() Snacks.picker.help() end,                      desc = "Help Pages" },
    -- Notifier
    { "<leader>n",  function() Snacks.notifier.show_history() end,            desc = "Notification History" },
  },
}
