local wezterm = require("wezterm")
local act = wezterm.action

local function basename(path)
  return path:gsub('(.*[/\\])(.*)', '%2')
end

local function remove_trailing_slash(s)
  return s:gsub("/$", "")
end

local function get_display_cwd(tab)
  local current_dir = remove_trailing_slash(tab.active_pane.current_working_dir.file_path)
      or "unknown"
  return current_dir == remove_trailing_slash(os.getenv("HOME"))
      and "~"
      or basename(current_dir)
end

local function get_process(tab)
  return (not tab.active_pane or tab.active_pane.foreground_process_name == "")
      and "[?]"
      or basename(tab.active_pane.foreground_process_name)
end

local function get_tab_title(tab)
  local title = tab.tab_title
  return (title and #title > 0)
      and title
      or string.format(" [%s] %s ", get_display_cwd(tab), get_process(tab))
end

wezterm.on(
  'format-tab-title',
  function(tab, tabs, panes, config, hover, max_width)
    return {
      { Text = get_tab_title(tab) }
    }
  end
)

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
