local wezterm = require("wezterm")

return {
  bindings = {
    --{
    --  -- override default copy behavior with a no-op
    --  event = { Up = { streak = 1, button = "Left" } },
    --  mods = "NONE",
    --  action = wezterm.action.Nop,
    --},
    --{
    --  -- disable down event to avoid unexpected behavior
    --  event = { Down = { streak = 1, button = "Left" } },
    --  mods = "CTRL",
    --  action = wezterm.action.Nop,
    --},
    {
      -- CTRL-click to open hyperlinks
      event = { Up = { streak = 1, button = "Left" } },
      mods = "CTRL",
      action = wezterm.action.OpenLinkAtMouseCursor,
    },
    {
      -- disable down event to avoid unexpected behavior
      event = { Down = { streak = 1, button = "Left" } },
      mods = "CTRL",
      action = wezterm.action.Nop,
    }
  }
}
