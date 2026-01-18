local helper = require('isearch.helper')

local last_selected_text
local next = true
local regex_search = false
local search_wrapped = false
local search_history = {}
local current_search_history
local hide_func

local function step_to_next(current_pos, _next)
  buffer:goto_pos(current_pos)

  buffer:search_anchor()

  local flags = regex_search and buffer.FIND_REGEXP or 0

  local found_start = _next
    and buffer:search_next(flags, last_selected_text)
    or buffer:search_prev(flags, last_selected_text)

  if found_start >= 0 then
    view:scroll_caret()
  end

  return found_start
end

local function update_marker_selection()
  if helper.get_current_mode() ~= helper.Modes.SEARCH then
    return
  end

  search_wrapped = false

  local selected_text = ui.command_entry:get_text()

  if selected_text ~= last_selected_text then
    last_selected_text = selected_text

    if selected_text and selected_text ~= "" and string.len(selected_text) >= 1 then
      local current_pos = buffer.current_pos

      if buffer.selection_start then
        local prev_pos = buffer:position_before(buffer.selection_start)

        if prev_pos ~= -1 then
          current_pos = prev_pos
        else
          current_pos = buffer.selection_start
        end
      end

      step_to_next(current_pos, next)
    end
  end
end

local function incremental_end()
  helper.set_current_mode(helper.Modes.NONE)
  events.disconnect(events.COMMAND_TEXT_CHANGED, update_marker_selection)

  if last_selected_text then
    helper.remove_by_value(search_history, last_selected_text)
    table.insert(search_history, last_selected_text)
  end
end

local function incremental_search(_next)
  local current_pos = buffer.current_pos

  if _next and buffer.selection_end then
    current_pos = buffer.selection_end
  end

  if not _next and buffer.selection_start then
    local prev_pos = buffer:position_before(buffer.selection_start)

    if prev_pos ~= -1 then
      current_pos = prev_pos
    else
      current_pos = -1
    end
  end

  local found_start = current_pos == -1 and -1 or step_to_next(current_pos, _next)

  if found_start == -1 and not search_wrapped then
    search_wrapped = true
    if _next then
      buffer:document_start()
    else
      buffer:document_end()
    end

    ui.statusbar_text = "Search Wrapped"

    step_to_next(buffer.current_pos, _next)
  else
    if found_start == -1 then
      ui.statusbar_text = "No Result Found"
    else
      ui.statusbar_text = ""
    end
  end
end

local function incremental_next()
  incremental_search(true)
end

local function incremental_prev()
  incremental_search(false)
end

local function history_locate(offset)
  if #search_history == 0 then return end

  local v = current_search_history + offset

  if v >= 1 and v <= #search_history then
    current_search_history = v

    ui.command_entry:set_text(search_history[current_search_history])
  end
end

local function history_next()
  history_locate(1)
  -- keys._command_entry['down']()
end

local function history_prev()
  history_locate(-1)
  -- keys._command_entry['up']()
end

local function incremental_cancel()
  helper.set_current_mode(helper.Modes.NONE)
  events.disconnect(events.COMMAND_TEXT_CHANGED, update_marker_selection)
  hide_func()
end

local function start_incremental_search(_next, _regex_search, _keys)
  helper.set_current_mode(helper.Modes.SEARCH)
  next = _next ~= nil and _next or true
  regex_search = _regex_search ~= nil and _regex_search or false
  search_wrapped = false
  current_search_history = #search_history

  search_keys = helper.merge_tables_overwrite(
    {
      ['ctrl+s'] = incremental_next,
      ['ctrl+r'] = incremental_prev,
      ['ctrl+n'] = history_next,
      ['ctrl+p'] = history_prev,
      ['ctrl+g'] = incremental_cancel,
    }, _keys or {})

  ui.command_entry.run('I-Search:', incremental_end, search_keys)
  hide_func = keys._command_entry['esc']
  keys._command_entry['esc'] = keys._command_entry['ctrl+g']
end

events.connect(events.COMMAND_TEXT_CHANGED, update_marker_selection)

-- External API:
local M = {}

M.start_search = start_incremental_search
M.stop_search = incremental_cancel
M.search_next = incremental_next
M.search_prev = incremental_prev
M.history_next = history_next
M.history_prev = history_prev

return M
