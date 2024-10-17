local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.font = wezterm.font 'Fira Code'
config.font_size = 16.0
config.color_scheme = 'Twilight'
config.window_decorations = 'RESIZE'

return config
