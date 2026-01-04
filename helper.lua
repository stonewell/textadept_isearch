local M = {}

M.Modes = {
  NONE = {},
  SEARCH = {},
  REPLACE = {}
}

local current_mode = M.Modes.NONE

function M.merge_tables_overwrite(t1, t2)
    for k, v in pairs(t2) do
        t1[k] = v -- Assign value, overwrites if key 'k' already exists in t1
    end
    return t1
end

function M.remove_by_value(tab, value)
    for i, v in ipairs(tab) do
        if v == value then
            table.remove(tab, i)
            return true -- Exit after the first match (optional)
        end
    end
    return false
end

function M.get_current_mode()
  return current_mode
end

function M.set_current_mode(mode)
  current_mode = mode
end

return M
