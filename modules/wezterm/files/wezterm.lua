local wezterm = require 'wezterm'
local act = wezterm.action
local selected_theme = require 'theme'

local config = wezterm.config_builder()

config.color_schemes = {
  [selected_theme.name] = selected_theme.colors,
}
config.color_scheme = selected_theme.name

config.automatically_reload_config = true
config.check_for_updates = false
config.term = 'xterm-256color'
config.enable_kitty_keyboard = true

config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'Sarasa Mono CL',
}
config.font_size = 12

config.default_cursor_style = 'SteadyBar'
config.cursor_thickness = '250%'

config.window_background_opacity = 1.0
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}
config.window_decorations = 'RESIZE'
config.window_frame = {
  font = wezterm.font { family = 'JetBrains Mono', weight = 'Bold' },
  font_size = 12.0,
  active_titlebar_bg = selected_theme.colors.tab_bar.background,
  inactive_titlebar_bg = selected_theme.colors.tab_bar.background,
}

config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.tab_bar_at_bottom = false
config.tab_max_width = 32
config.use_fancy_tab_bar = true

local tab_min_width = 18

local function basename(path)
  if not path or #path == 0 then
    return nil
  end

  local normalized = path:gsub('\\', '/'):gsub('/+$', '')
  return normalized:match('([^/]+)$') or normalized
end

local function decode_uri_path(path)
  return path:gsub('%%(%x%x)', function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

local function cwd_path(cwd)
  if not cwd then
    return nil
  end

  if type(cwd) == 'table' and cwd.file_path and #cwd.file_path > 0 then
    return cwd.file_path
  end

  local path = tostring(cwd)
  if path:match('^file://') then
    path = path:gsub('^file://[^/]*', '')
    return decode_uri_path(path)
  end

  return path
end

local function compact_path(path)
  if not path or #path == 0 then
    return nil
  end

  path = path:gsub('\\', '/'):gsub('/+$', '')

  local home = os.getenv('HOME')
  if home and #home > 0 then
    home = home:gsub('\\', '/'):gsub('/+$', '')
    if path == home then
      return '~'
    end
    if path:sub(1, #home + 1) == home .. '/' then
      path = path:sub(#home + 2)
    end
  end

  local parts = {}
  for part in path:gmatch('[^/]+') do
    table.insert(parts, part)
  end

  if #parts == 0 then
    return '/'
  end
  if #parts == 1 then
    return parts[1]
  end

  return parts[#parts - 1] .. '/' .. parts[#parts]
end

local function tab_title(tab)
  local title = tab.tab_title
  if title and #title > 0 then
    return title
  end

  local pane = tab.active_pane
  local pane_title = pane.title or ''
  local process_name = basename(pane.foreground_process_name)
  if process_name == 'tmux' then
    return pane_title
  end

  local cwd = compact_path(cwd_path(pane.current_working_dir))
  if cwd and process_name and (pane_title == '' or pane_title == process_name) then
    return process_name .. ': ' .. cwd
  end
  if cwd and pane_title == '' then
    return cwd
  end

  return pane_title
end

wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local content_width = math.max(1, max_width - 2)
  local title = wezterm.truncate_right(tab_title(tab), content_width)

  return {
    { Text = ' ' .. wezterm.pad_right(title, math.min(tab_min_width, content_width)) .. ' ' },
  }
end)

config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.9,
}
config.hyperlink_rules = wezterm.default_hyperlink_rules()
config.scrollback_lines = 10000

local ctrl_key_bindings = {
  { key = 'phys:A', byte = 0x01 },
  { key = 'phys:B', byte = 0x02 },
  { key = 'phys:C', byte = 0x03 },
  { key = 'phys:D', byte = 0x04 },
  { key = 'phys:E', byte = 0x05 },
  { key = 'phys:F', byte = 0x06 },
  { key = 'phys:G', byte = 0x07 },
  { key = 'phys:H', byte = 0x08 },
  { key = 'phys:I', byte = 0x09 },
  { key = 'phys:J', byte = 0x0a },
  { key = 'phys:K', byte = 0x0b },
  { key = 'phys:L', byte = 0x0c },
  { key = 'phys:M', byte = 0x0d },
  { key = 'phys:N', byte = 0x0e },
  { key = 'phys:O', byte = 0x0f },
  { key = 'phys:P', byte = 0x10 },
  { key = 'phys:Q', byte = 0x11 },
  { key = 'phys:R', byte = 0x12 },
  { key = 'phys:S', byte = 0x13 },
  { key = 'phys:T', byte = 0x14 },
  { key = 'phys:U', byte = 0x15 },
  { key = 'phys:V', byte = 0x16 },
  { key = 'phys:W', byte = 0x17 },
  { key = 'phys:X', byte = 0x18 },
  { key = 'phys:Y', byte = 0x19 },
  { key = 'phys:Z', byte = 0x1a },
}

config.keys = {}
for _, binding in ipairs(ctrl_key_bindings) do
  table.insert(config.keys, {
    key = binding.key,
    mods = 'CTRL',
    action = act.SendString(string.char(binding.byte)),
  })
end

return config
