local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.term = 'xterm-256color'

config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'Sarasa Mono CL',
}
config.font_size = 12.0

config.window_background_opacity = 0.95

config.enable_scroll_bar = true
config.scrollback_lines = 90000

config.default_cursor_style = 'SteadyBar'
config.use_fancy_tab_bar = false

config.colors = {
  foreground = '#383a42',
  background = '#fdfdfd',
  cursor_bg = '#3a9a88',
  cursor_fg = '#ffffff',
  cursor_border = '#3a9a88',
  selection_fg = '#383a42',
  selection_bg = '#bfceff',
  scrollbar_thumb = '#d0d7de',
  split = '#e5e7eb',
  ansi = {
    '#383a42',
    '#e45649',
    '#50a14f',
    '#c18401',
    '#0184bc',
    '#d65d0e',
    '#427b58',
    '#fdfdfd',
  },
  brights = {
    '#4f525e',
    '#e06c75',
    '#98c379',
    '#e5c07b',
    '#61afef',
    '#e78a4e',
    '#689d6a',
    '#ffffff',
  },
  tab_bar = {
    background = '#fdfdfd',
    inactive_tab_edge = '#e5e7eb',
    active_tab = {
      bg_color = '#fdfdfd',
      fg_color = '#383a42',
    },
    inactive_tab = {
      bg_color = '#f5f5f5',
      fg_color = '#4f525e',
    },
    inactive_tab_hover = {
      bg_color = '#eceef2',
      fg_color = '#383a42',
    },
    new_tab = {
      bg_color = '#fdfdfd',
      fg_color = '#4f525e',
    },
    new_tab_hover = {
      bg_color = '#eceef2',
      fg_color = '#383a42',
    },
  },
}

return config
