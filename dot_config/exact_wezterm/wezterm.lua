local wezterm = require("wezterm")
local act = wezterm.action

local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

config.color_scheme = "Nord (base16)"

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

config.mouse_bindings = {
  {
    -- override default copy behavior with a no-op
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.Nop,
  },
  {
    -- disable down event to avoid unexpected behavior
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.Nop,
  },
  {
    -- CTRL-click to open hyperlinks
    event = { Up = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
  {
    -- disable down event to avoid unexpected behavior
    event = { Down = { streak = 1, button = "Left" } },
    mods = "CTRL",
    action = act.Nop,
  }
}

config.scrollback_lines = 10000

-- TODO dynamically enable based on number of tabs
config.window_close_confirmation = "NeverPrompt"

-- TODO
config.warn_about_missing_glyphs = false
-- scroll lines (10 lines)
-- config.disable_default_key_bindings = true

return config
