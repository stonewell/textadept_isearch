local helper = require('isearch.helper')

local search_text
local replace_text

local replace_keys = {}

local function stop_replace()
  helper.set_current_mode(helper.Modes.NONE)
end

local function do_replace_text()
  stop_replace()
end

local function get_replace_text()
  local t = ui.command_entry:get_text()

  if t and t ~= "" and string.len(t) >= 1 then
    ui.command_entry.run(
      buffer.selection_start
        and 'Replace string in region ' .. t .. ' with: '
        or 'Replace string ' .. t .. ' with: ',
      do_replace_text,
      replace_keys)
  else
    stop_replace()
  end
end

local function start_replace()
  helper.set_current_mode(helper.Modes.REPLACE)
  ui.command_entry.run(buffer.selection_start and 'Replace string in region' or 'Replace string:',
                       get_replace_text,
                       replace_keys)
end


local M = {}

M.start_replace = start_replace
M.stop_replace = stop_replace

return M
