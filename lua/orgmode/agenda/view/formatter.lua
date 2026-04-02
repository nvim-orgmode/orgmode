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
    local start_pos, end_pos, optional, alignment, width, spaces, var = format_string:find('%%(%??)(%-?)(%d*)(%s*)([:%a]+)', pos)
    if not start_pos then
      result_content = result_content .. format_string:sub(pos)
      break
    end

    result_content = result_content .. format_string:sub(pos, start_pos - 1)

    local var_key = var
    if not vars[var_key] and #var_key > 1 then
      -- Try to match only the first part if it's a known var (e.g. :c is handled, but others might be single char)
      if vars[var_key:sub(1, 1)] then
        var_key = var_key:sub(1, 1)
        -- adjust end_pos back
        end_pos = start_pos + #optional + #alignment + #width + #spaces + #var_key
      end
    end

    local value = ''
    if vars[var_key] then
      value = vars[var_key]()
    end

    if (optional == '?' or spaces ~= '') and value == '' then
      -- Skip
    else
      local w = tonumber(width)
      if not w then
        if var_key == 'c' or var_key == ':c' then
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
