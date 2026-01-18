local helper = require('isearch.helper')

local search_text
local replace_text
local replace_regex = false

local replace_keys = {}

local P, V, C, upper, lower = lpeg.P, lpeg.V, lpeg.C, string.upper, string.lower
local esc = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t', v = '\v', ['\\'] = '\\'}
local re_patt = lpeg.Cs(P{
  (V('text') + V('u') + V('l') + V('U') + V('L') + V('esc'))^1,
  text = (1 - '\\' * lpeg.S('uUlLEbfnrtv\\'))^1, --
  u = '\\u' * C(1) / upper, l = '\\l' * C(1) / lower,
  U = P('\\U') / '' * (V('text') / upper + V('u') + V('l'))^0 * V('E')^-1,
  L = P('\\L') / '' * (V('text') / lower + V('u') + V('l'))^0 * V('E')^-1, --
  E = P('\\E') / '', esc = '\\' * C(1) / esc
})
--- Returns text with the following sequences unescaped:
-- - "\uXXXX" sequences replaced with the equivalent UTF-8 character.
-- - "\d" sequences replaced with the text of capture number *d* from the regular expression
--	(or the entire match for *d* = 0).
-- - "\U" and "\L" sequences convert everything up to the next "\U", "\L", or "\E" to uppercase
--	and lowercase, respectively.
-- - "\u" and "\l" sequences convert the next character to uppercase and lowercase, respectively.
--	They may appear within "\U" and "\L" constructs.
-- @param text String text to unescape.
-- @return unescaped text
local function unescape(text)
  text = text:gsub('%f[\\]\\u(%x%x%x%x)', function(code) return utf8.char(tonumber(code, 16)) end)
    :gsub('\\0', buffer.target_text):gsub('\\(%d)', buffer.tag)
  return re_patt:match(text) or text
end

local function stop_replace()
  helper.set_current_mode(helper.Modes.NONE)
end

local INDIC_REPLACE = view.new_indic_number()

local function replace_all(ftext, rtext)
  if ftext == '' then return end

  local count = 0
  buffer.indicator_current = INDIC_REPLACE

  buffer:begin_undo_action()

  for i = 1, buffer.selections do
    local s, e = buffer.selection_n_start[i], buffer.selection_n_end[i]
    buffer:indicator_fill_range(e, 1)
    local EOF = e == buffer.length + 1 -- no indicator at EOF

    -- Perform the search and replace.
    buffer.search_flags = replace_regex and buffer.FIND_REGEXP or 0
    buffer:set_target_range(s, buffer.length + 1)
    while buffer:search_in_target(ftext) ~= -1 and
      (buffer.target_end <= buffer:indicator_end(INDIC_REPLACE, s) or EOF) do
      local offset = buffer.target_start ~= buffer.target_end and 0 or 1 -- for preventing loops
      if replace_regex and ftext:find('^^') and offset == 0 then offset = 1 end -- avoid extra matches
      buffer:replace_target(not replace_regex and rtext or unescape(rtext))
      count = count + 1
      if buffer.target_end + offset > buffer.length then break end
      buffer:set_target_range(buffer.target_end + offset, buffer.length + 1)
    end

    -- Restore any original selection.
    e = buffer:indicator_end(INDIC_REPLACE, s)
    buffer.selection_n_start[i], buffer.selection_n_end[i] = s, e > 1 and e or buffer.length + 1
    if e > 1 then buffer:indicator_clear_range(e, 1) end
  end
  buffer:end_undo_action()

  ui.statusbar_text = string.format('%d %s', count, _L['replacement(s) made'])
end

local function do_replace_text()
  replace_text = ui.command_entry:get_text()

  replace_all(search_text, replace_text)

  stop_replace()
end

local function get_replace_text()
  local t = ui.command_entry:get_text()

  if t and t ~= "" and string.len(t) >= 1 then
    search_text = t

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

local function start_replace(_regex_search, _keys)
  helper.set_current_mode(helper.Modes.REPLACE)
  replace_regex = _regex_search or false

  replace_keys = helper.merge_tables_overwrite(
    replace_keys, _keys or {})

  ui.command_entry.run(buffer.selection_start and 'Replace string in region' or 'Replace string:',
                       get_replace_text,
                       replace_keys)
end


local M = {}

M.start_replace = start_replace
M.stop_replace = stop_replace

return M
