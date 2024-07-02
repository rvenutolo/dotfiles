local wezterm = require("wezterm")
local act = wezterm.action

local function is_empty(s)
  return s == nil or s == ""
end

local function basename(path)
  return string.gsub(path, "(.*[/\\])(.*)", "%2")
end

local function remove_trailing_slash(s)
  return string.gsub(s, "/$", "")
end

local function get_display_cwd(tab)
  if tab.active_pane.current_working_dir then
    local cwd = remove_trailing_slash(tab.active_pane.current_working_dir.file_path)
    if cwd == remove_trailing_slash(os.getenv("HOME")) then
      return "~"
    else
      return basename(cwd)
    end
  else
    return "???"
  end
end

local function get_process(tab)
  local process_name = tab.active_pane.foreground_process_name
  if not tab.active_pane or process_name == "" then
    return "???"
  else
    return basename(process_name)
  end
end

local function get_tab_title(tab)
  local title = tab.tab_title
  if title and #title > 0 then
    return title
  else
    return string.format(" [%s] %s ", get_display_cwd(tab), get_process(tab))
  end
end

local function has_unseen_output(tab)
  if not tab.is_active then
    for _, pane in ipairs(tab.panes) do
      if pane.has_unseen_output then
        return true
      end
    end
  end
  return false
end

local function scheme_color(key)
  local current_color_scheme = wezterm.color.get_builtin_schemes()[COLOR_SCHEME]
  local key_to_color = {
    black = current_color_scheme.ansi[1],
    red = current_color_scheme.ansi[2],
    green = current_color_scheme.ansi[3],
    yellow = current_color_scheme.ansi[4],
    blue = current_color_scheme.ansi[5],
    magenta = current_color_scheme.ansi[6],
    cyan = current_color_scheme.ansi[7],
    white = current_color_scheme.ansi[8],
    black_bright = current_color_scheme.brights[1],
    red_bright = current_color_scheme.brights[2],
    green_bright = current_color_scheme.brights[3],
    yellow_bright = current_color_scheme.brights[4],
    blue_bright = current_color_scheme.brights[5],
    magenta_bright = current_color_scheme.brights[6],
    cyan_bright = current_color_scheme.brights[7],
    white_bright = current_color_scheme.brights[8]
  }
  return key_to_color[key]
end

wezterm.on(
  "format-tab-title",
  function(tab, tabs, panes, config, hover, max_width)
    local tab_title = get_tab_title(tab)
    if tab.is_active then
      return {
        { Foreground = { Color = scheme_color("blue_bright") } },
        { Attribute = { Intensity = "Bold" } },
        { Text = tab_title }
      }
    elseif has_unseen_output(tab) then
      return {
        { Foreground = { Color = scheme_color("green_bright") } },
        { Text = tab_title }
      }
    else
      return {
        { Text = tab_title }
      }
    end
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
