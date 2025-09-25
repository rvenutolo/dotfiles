local wezterm = require("wezterm")
local format_functions = require("format_functions")
local mouse = require("mouse")
local keybindings = require("keybindings")

wezterm.on("format-tab-title", format_functions.format_tab_tile)
wezterm.on("format-window-title", format_functions.format_window_title)

local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.color_scheme = "nord"

config.cursor_blink_rate = 1000

config.default_cursor_style = "BlinkingBlock"

config.enable_scroll_bar = true

config.font = wezterm.font({
  family = "JetBrains Mono",
  weight = "Regular",
})

config.font_size = 11.0

config.hide_tab_bar_if_only_one_tab = true

config.inactive_pane_hsb = {
  saturation = 0.24,
  brightness = 0.5
}

config.initial_cols = 120

config.initial_rows = 36

config.keys = keybindings.keys

config.mouse_bindings = mouse.bindings

config.scrollback_lines = 10000

config.warn_about_missing_glyphs = false

config.window_close_confirmation = "NeverPrompt"

return config
