local wezterm = require 'wezterm'

local config = wezterm.config_builder()
local active_tab_bg = '#fdfdfd'
local active_tab_fg = '#383a42'
local tab_bar_bg = '#eef1f4'
local inactive_tab_bg = '#e4e9ef'
local inactive_tab_hover_bg = '#dde3ea'
local inactive_tab_fg = '#5c6370'
local fixed_tab_width = 20

local function tab_title(tab)
  local title = tab.tab_title
  if title ~= nil and #title > 0 then
    return title
  end
  return tab.active_pane.title
end

wezterm.on('format-tab-title', function(tab, _, _, _, hover, max_width)
  local title_width = math.max(fixed_tab_width - 2, 1)
  if max_width ~= nil then
    title_width = math.max(math.min(title_width, max_width - 2), 1)
  end

  local title = wezterm.pad_right(
    wezterm.truncate_right(tab_title(tab), title_width),
    title_width
  )

  local bg = inactive_tab_bg
  local fg = inactive_tab_fg

  if tab.is_active then
    bg = active_tab_bg
    fg = active_tab_fg
  elseif hover then
    bg = inactive_tab_hover_bg
    fg = active_tab_fg
  end

  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = ' ' .. title .. ' ' },
  }
end)

if wezterm.target_triple:find('apple%-darwin') ~= nil then
  config.window_decorations = 'RESIZE'
  config.macos_window_background_blur = 30
end

config.term = 'xterm-256color'

config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'Sarasa Mono CL',
}
config.font_size = 12.0

config.window_background_opacity = 0.98

config.enable_scroll_bar = true
config.scrollback_lines = 90000

config.default_cursor_style = 'SteadyBar'
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true

config.window_frame = {
  active_titlebar_bg = tab_bar_bg,
  inactive_titlebar_bg = tab_bar_bg,
  active_titlebar_fg = active_tab_fg,
  inactive_titlebar_fg = inactive_tab_fg,
  active_titlebar_border_bottom = '#d0d7de',
  inactive_titlebar_border_bottom = '#d0d7de',
}

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
    background = tab_bar_bg,
    inactive_tab_edge = '#d0d7de',
    active_tab = {
      bg_color = active_tab_bg,
      fg_color = active_tab_fg,
    },
    inactive_tab = {
      bg_color = inactive_tab_bg,
      fg_color = inactive_tab_fg,
    },
    inactive_tab_hover = {
      bg_color = inactive_tab_hover_bg,
      fg_color = active_tab_fg,
    },
    new_tab = {
      bg_color = tab_bar_bg,
      fg_color = inactive_tab_fg,
    },
    new_tab_hover = {
      bg_color = inactive_tab_hover_bg,
      fg_color = active_tab_fg,
    },
  },
}

return config
