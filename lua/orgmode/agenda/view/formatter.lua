local utils = require('orgmode.utils')

---@class OrgAgendaFormatterSegment
---@field type 'literal' | 'placeholder'
---@field value? string literal value
---@field var? string variable name
---@field func? function compiled expression or variable fetcher
---@field optional? boolean
---@field alignment? '-' | ''
---@field width? number
---@field spaces? string

---@class OrgAgendaFormatter
---@field private compiled_cache table<string, OrgAgendaFormatterSegment[]>
local Formatter = {
  compiled_cache = {},
}

local builtin_vars = {
  c = function(headline)
    return headline:get_category()
  end,
  [':c'] = function(headline)
    local cat = headline:get_category()
    return cat ~= '' and (cat .. ':') or ''
  end,
  s = function(headline, agenda_item)
    -- Marker for planning info (Deadline, Scheduled, etc.)
    return (agenda_item and agenda_item.marker) or ''
  end,
  t = function(headline, agenda_item)
    return (agenda_item and agenda_item.time) or ''
  end,
  i = function()
    return ''
  end,
  T = function(headline)
    local tags = headline:get_tags()
    return #tags > 0 and headline:tags_to_string() or ''
  end,
  e = function(headline)
    return headline:get_property('effort') or ''
  end,
  l = function(headline)
    return tostring(headline:get_level())
  end,
  b = function(headline)
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

--- Apply formatting specifiers (width, alignment) to a value
---@param value string
---@param segment OrgAgendaFormatterSegment
---@param metadata table
---@return string
local function apply_formatting(value, segment, metadata)
  local w = segment.width
  -- Fallback for category width if not specified
  if not w and (segment.var == 'c' or segment.var == ':c') then
    w = metadata.category_length
  end

  if not w then
    return value
  end

  if segment.alignment == '-' then
    return utils.pad_right(value, w)
  end
  return utils.pad_left(value, w)
end

---@param format_string string
---@return OrgAgendaFormatterSegment[]
function Formatter.compile(format_string)
  if Formatter.compiled_cache[format_string] then
    return Formatter.compiled_cache[format_string]
  end

  local segments = {}
  local pos = 1
  -- pattern_var matches % [optional flags/width] [variable name]
  local pattern_var = '%%([%?%-?%d%s]*)([:%a]+)'
  -- pattern_expr matches % [optional flags/width] (Lua expression)
  local pattern_expr = '%%([%?%-?%d%s]*)(%b())'

  while pos <= #format_string do
    local s_var, e_var, spec_var, var = format_string:find(pattern_var, pos)
    local s_expr, e_expr, spec_expr, expr = format_string:find(pattern_expr, pos)

    local start_pos, end_pos, specifiers, value, is_expr
    -- Determine which pattern matches first
    if s_var and (not s_expr or s_var < s_expr) then
      start_pos, end_pos, specifiers, value, is_expr = s_var, e_var, spec_var, var, false
    elseif s_expr then
      start_pos, end_pos, specifiers, value, is_expr = s_expr, e_expr, spec_expr, expr, true
    end

    -- If no more placeholders, append the rest of the string as literal
    if not start_pos then
      table.insert(segments, { type = 'literal', value = format_string:sub(pos) })
      break
    end

    -- Append literal text before the placeholder
    if start_pos > pos then
      table.insert(segments, { type = 'literal', value = format_string:sub(pos, start_pos - 1) })
    end

    local segment = {
      type = 'placeholder',
      optional = specifiers:match('%?') ~= nil,
      alignment = specifiers:match('%-') or '',
      width = tonumber(specifiers:match('%d+')),
      spaces = specifiers:match('^%s+') or specifiers:match('%s+$') or '',
      var = value,
    }

    if is_expr then
      local lua_code = value:sub(2, -2)
      local f = (loadstring or load)('return ' .. lua_code)
      if f then
        segment.func = function(headline, agenda_item, metadata)
          local env = setmetatable({
            headline = headline,
            item = agenda_item,
            metadata = metadata,
          }, { __index = _G })
          if setfenv then
            setfenv(f, env)
          end
          local ok, res = pcall(f)
          return ok and tostring(res or '') or ''
        end
      end
    elseif builtin_vars[value] then
      local builtin_func = builtin_vars[value]
      segment.func = function(headline, agenda_item)
        return builtin_func(headline, agenda_item)
      end
    else
      segment.func = function()
        return ''
      end
    end

    table.insert(segments, segment)
    pos = end_pos + 1
  end

  Formatter.compiled_cache[format_string] = segments
  return segments
end

---@param format_string string | OrgAgendaFormatterSegment[]
---@param agenda_item? OrgAgendaItem
---@param metadata table
---@param headline? OrgHeadline
---@return string
function Formatter.format(format_string, agenda_item, metadata, headline)
  local segments = type(format_string) == 'string' and Formatter.compile(format_string) or format_string
  headline = headline or (agenda_item and agenda_item.headline)
  if not headline then
    return ''
  end

  local result = ''
  for _, segment in ipairs(segments) do
    if segment.type == 'literal' then
      result = result .. segment.value
    else
      local value = segment.func(headline, agenda_item, metadata)

      -- Handle optional placeholders and leading/trailing spaces
      if (segment.optional or segment.spaces ~= '') and value == '' then
        -- Skip empty optional values
      else
        local formatted_value = apply_formatting(value, segment, metadata)
        result = result .. segment.spaces .. formatted_value
      end
    end
  end

  return result
end

return Formatter
