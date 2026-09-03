local core = require "core"
local keymap = require "core.keymap"
local config = require "core.config"
local style = require "core.style"

config.plugins.scale.mode = "ui"
config.plugins.scale.default_scale = 2
core.reload_module("colors.nord")

local lsp_plugin_path = USERDIR .. "/plugins/lsp-servers"
local info = system.get_file_info(lsp_plugin_path)
if info and info.type == "dir" then
  -- Add the directory to Lua's search path for 'require'
  package.path = lsp_plugin_path .. "/?.lua;" .. lsp_plugin_path .. "/?/init.lua;" .. package.path
end

config.highlight_current_line = true -- Options: true, false, "no_selection"
config.indent_size = 2      -- 2 spaces per indent level
config.keep_newline_whitespace = false -- Clean up lines that only contain whitespace
config.max_log_items = 80            -- Capacity of the message log
config.message_timeout = 4           -- Duration for status messages (seconds)
config.tab_type    = "soft" -- Use spaces instead of literal tabs

config.plugins.bracketmatch = {
  color_char = true
}

config.plugins.drawwhitespace = {
  enabled = true,
  show_leading = true,
  show_middle  = true,
  show_trailing = true,
  show_trailing_error = true
}

config.plugins.exterm = {
  executable = "x-terminal-emulator"
}

config.plugins.lineguide = {
  enabled = true
}

config.plugins.trimwhitespace = {
  enabled = true,
  trim_empty_end_lines = true
}
