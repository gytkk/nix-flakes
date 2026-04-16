local wezterm = require 'wezterm'
local shared = require 'shared'

local config = wezterm.config_builder()

shared.apply_to_config(config, wezterm)
config.window_decorations = 'RESIZE'
config.default_domain = 'WSL:Ubuntu'

return config
