local utils = require('orgmode.utils')

---@class OrgAgendaFormatter
local Formatter = {}

---@param format_string string
---@param agenda_item? OrgAgendaItem
---@param metadata table
---@param headline? OrgHeadline
---@return string
function Formatter.format(format_string, agenda_item, metadata, headline)
  headline = headline or (agenda_item and agenda_item.headline)
  if not headline then return '' end

  local vars = {
    c = function() return headline:get_category() end,
    [':c'] = function()
      local cat = headline:get_category()
      return cat ~= '' and (cat .. ':') or ''
    end,
    s = function() return (agenda_item and agenda_item.extra) or '' end,
    t = function() return (agenda_item and agenda_item.time) or '' end,
    i = function() return '' end,
    T = function()
      local tags = headline:get_tags()
      return #tags > 0 and headline:tags_to_string() or ''
    end,
    e = function() return headline:get_property('effort') or '' end,
    l = function() return tostring(headline:get_level()) end,
    b = function()
      -- Breadcrumbs: build from parent headlines
      local breadcrumbs = {}
      local parent = headline.parent
      while parent and parent.level > 0 do
        table.insert(breadcrumbs, 1, parent:get_title())
        parent = parent.parent
      end
      return table.concat(breadcrumbs, '->')
    end,
  }

  -- Regex to match format specifiers: % [optional ?] [optional -] [optional number] [var]
  -- vars can be :c or single char
  local pos = 1
  local result_content = ''

  while pos <= #format_string do
    local start_pos, end_pos, prefix, var = format_string:find('%%([%?%-?%d%s]*)([:%a]+)', pos)
    local is_expr = false
    if not start_pos then
      start_pos, end_pos, prefix, var = format_string:find('%%([%?%-?%d%s]*)(%b())', pos)
      is_expr = true
    else
      -- Check if there is an expression before the found variable
      local s2, e2, p2, v2 = format_string:find('%%([%?%-?%d%s]*)(%b())', pos)
      if s2 and s2 < start_pos then
        start_pos, end_pos, prefix, var = s2, e2, p2, v2
        is_expr = true
      end
    end

    if not start_pos then
      result_content = result_content .. format_string:sub(pos)
      break
    end

    result_content = result_content .. format_string:sub(pos, start_pos - 1)

    local optional = prefix:match('%?') or ''
    local alignment = prefix:match('%-') or ''
    local width = prefix:match('%d+') or ''
    local spaces = prefix:match('^%s+') or prefix:match('%s+$') or ''

    local value = ''
    if is_expr then
      local expr = var:sub(2, -2)
      local env = {
        headline = headline,
        item = agenda_item,
        metadata = metadata,
      }
      setmetatable(env, { __index = _G })
      local f, err = (loadstring or load)('return ' .. expr)
      if f then
        if setfenv then
          setfenv(f, env)
        end
        local ok, res = pcall(f, env)
        if ok then
          value = tostring(res or '')
        end
      end
    elseif vars[var] then
      value = vars[var]()
    elseif #var > 1 and vars[var:sub(1, 1)] then
      -- Handle cases like :c if needed, but our vars table already has :c
      value = vars[var]()
    end

    if (optional == '?' or spaces ~= '') and value == '' then
      -- Skip
    else
      local w = tonumber(width)
      if not w then
        if var == 'c' or var == ':c' then
          w = metadata.category_length
        end
      end
      if w then
        if alignment == '-' then
          value = utils.pad_right(value, w)
        else
          value = utils.pad_left(value, w)
        end
      end
      result_content = result_content .. spaces .. value
    end

    pos = end_pos + 1
  end

  return result_content
end

return Formatter
