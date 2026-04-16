local wezterm = require 'wezterm'

local config_path = wezterm.home_dir:gsub('\\', '/') .. '/.config/wezterm/wezterm.lua'
local ok, config_or_err = pcall(dofile, config_path)

if not ok then
  wezterm.log_error(
    'Failed to load bridged WezTerm config from '
      .. config_path
      .. ': '
      .. tostring(config_or_err)
  )
  return {}
end

return config_or_err
