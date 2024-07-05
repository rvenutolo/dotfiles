local wezterm = require("wezterm")
local act = wezterm.action

return {
  bindings = {
    --{
    --  -- override default copy behavior with a no-op
    --  event = { Up = { streak = 1, button = "Left" } },
    --  mods = "NONE",
    --  action = act.Nop,
    --},
    --{
    --  -- disable down event to avoid unexpected behavior
    --  event = { Down = { streak = 1, button = "Left" } },
    --  mods = "CTRL",
    --  action = act.Nop,
    --},
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
}
