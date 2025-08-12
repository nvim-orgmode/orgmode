local M = {}

local function ordinal_suffix(n)
  local teen = n % 100
  if teen == 11 or teen == 12 or teen == 13 then
    return 'th'
  end
  local last = n % 10
  if last == 1 then
    return 'st'
  elseif last == 2 then
    return 'nd'
  elseif last == 3 then
    return 'rd'
  end
  return 'th'
end

---Interpolate %d and %s in text for common sexp forms like diary-anniversary
---@param text string
---@param expr string
---@param date OrgDate
---@return string
function M.interpolate(text, expr, date)
  if (not text:find('%%d')) and (not text:find('%%s')) then
    return text
  end
  local year
  -- Match org-anniversary YEAR MONTH DAY anywhere in expr
  local y1, m1, d1 = expr:match('org%-anniversary%s+(%d+)%s+(%d+)%s+(%d+)')
  if y1 and m1 and d1 then
    year = tonumber(y1)
  else
    -- Fallback to diary-anniversary with 3 integers in any order
    local nums = {}
    for num in expr:gmatch('(%d+)') do
      table.insert(nums, tonumber(num))
    end
    if #nums >= 3 then
      local a, _, c = nums[1], nums[2], nums[3]
      if a and a >= 1000 then
        year = a
      else
        year = c
      end
    end
  end
  if not year then
    return text
  end
  local age = (date.year or 0) - year
  local suff = ordinal_suffix(age)
  local out = text
  out = out:gsub('%%d', tostring(age))
  out = out:gsub('%%s', suff)
  return out
end

return M


