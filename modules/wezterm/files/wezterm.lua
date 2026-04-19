local wezterm = require 'wezterm'

local config = wezterm.config_builder()
local theme_path = wezterm.config_dir .. '/themes/__COMMON_THEME__.lua'
local ok, loaded_theme = pcall(dofile, theme_path)
if not ok then
  wezterm.log_error('Failed to load generated WezTerm theme from ' .. theme_path .. ': ' .. tostring(loaded_theme))
  loaded_theme = {}
end
if type(loaded_theme) ~= 'table' then
  wezterm.log_error('Generated WezTerm theme did not return a table: ' .. theme_path)
  loaded_theme = {}
end

local colors = loaded_theme.colors or {}
local tab_bar = loaded_theme.tab_bar or {}
local tab_bar_colors = colors.tab_bar or {}
local active_tab = tab_bar_colors.active_tab or {}
local inactive_tab = tab_bar_colors.inactive_tab or {}
local inactive_tab_hover = tab_bar_colors.inactive_tab_hover or {}
local new_tab = tab_bar_colors.new_tab or {}
local new_tab_hover = tab_bar_colors.new_tab_hover or {}
local fixed_tab_width = 20

local function pick(...)
  for index = 1, select('#', ...) do
    local value = select(index, ...)
    if value ~= nil then
      return value
    end
  end
  return nil
end

local active_tab_bg = pick(tab_bar.active_bg, active_tab.bg_color, colors.background, '#2b2042')
local active_tab_fg = pick(tab_bar.active_fg, active_tab.fg_color, colors.foreground, '#c0c0c0')
local tab_bar_bg = pick(tab_bar.background, tab_bar_colors.background, colors.background, '#1b1032')
local inactive_tab_bg = pick(tab_bar.inactive_bg, inactive_tab.bg_color, new_tab.bg_color, tab_bar_bg)
local inactive_tab_hover_bg = pick(tab_bar.inactive_hover_bg, inactive_tab_hover.bg_color, inactive_tab_bg)
local inactive_tab_fg = pick(tab_bar.inactive_fg, inactive_tab.fg_color, new_tab.fg_color, colors.foreground, '#808080')
local inactive_tab_hover_fg = pick(tab_bar.inactive_hover_fg, inactive_tab_hover.fg_color, active_tab_fg)
local window_frame = loaded_theme.window_frame or {}

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
    fg = inactive_tab_hover_fg
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
elseif wezterm.target_triple:find('windows') ~= nil then
  config.window_decorations = 'RESIZE'
  config.default_domain = 'WSL:Ubuntu'
end

config.term = 'xterm-256color'
config.enable_kitty_keyboard = true
config.keys = {
  -- Keep kitty keyboard enabled so macOS IME/CJK input works reliably.
  -- Work around wezterm/wezterm#3621 where Delete is emitted as Ctrl+H.
  {
    key = 'Delete',
    action = wezterm.action.SendKey { key = 'Delete' },
  },
  -- Keep Shift+Enter distinct for chat-style TUIs.
  {
    key = 'Enter',
    mods = 'SHIFT',
    action = wezterm.action.SendString '\x1b[13;2u',
  },
}

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
  active_titlebar_bg = pick(window_frame.active_titlebar_bg, tab_bar_bg),
  inactive_titlebar_bg = pick(window_frame.inactive_titlebar_bg, tab_bar_bg),
  active_titlebar_fg = pick(window_frame.active_titlebar_fg, active_tab_fg),
  inactive_titlebar_fg = pick(window_frame.inactive_titlebar_fg, inactive_tab_fg),
  active_titlebar_border_bottom = pick(window_frame.active_titlebar_border_bottom, tab_bar.edge, tab_bar_colors.inactive_tab_edge, '#575757'),
  inactive_titlebar_border_bottom = pick(window_frame.inactive_titlebar_border_bottom, tab_bar.edge, tab_bar_colors.inactive_tab_edge, '#575757'),
}

if next(colors) ~= nil then
  config.colors = colors
end

return config
