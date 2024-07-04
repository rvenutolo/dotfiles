local string_utils = require("string_utils")

local module = {}

local function get_cwd(tab)
  local cwd = string_utils.remove_trailing_slash(tab.active_pane.current_working_dir.file_path) or "UNKNOWN"
  return cwd == string_utils.remove_trailing_slash(os.getenv("HOME")) and "~" or string_utils.basename(cwd)
end

local function get_tab_title(tab)
  local tab_title = tab.tab_title
  if tab_title and #tab_title > 0 then
    return tab_title
  end
  local process = string_utils.basename(tab.active_pane.foreground_process_name)
  return string_utils.is_empty(process) and "(debug)" or string.format("[%s] %s", get_cwd(tab), process)
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

function module.format_tab_tile(tab, tabs, panes, config, hover, max_width)
  local tab_title = get_tab_title(tab)
  if tab.is_active then
    return {
      { Foreground = { AnsiColor = "White" } },
      { Text = tab_title }
    }
  elseif has_unseen_output(tab) then
    return {
      { Foreground = { AnsiColor = "Green" } },
      { Text = tab_title }
    }
  else
    return {
      { Foreground = { AnsiColor = "Blue" } },
      { Text = tab_title }
    }
  end
end

function module.format_window_title(active_tab, pane, tabs, panes, config)
  if #tabs > 1 then
    return string.format("%s (%d/%d)", get_tab_title(active_tab), active_tab.tab_index + 1, #tabs)
  else
    return get_tab_title(active_tab)
  end
end

return module
