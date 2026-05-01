---@class OrgDiarySexp
---@field _eval fun(self: OrgDiarySexp, date: OrgDate): boolean
local OrgDiarySexp = {}
OrgDiarySexp.__index = OrgDiarySexp

---@param fn fun(date: OrgDate): boolean
---@param raw_expr? string
---@return OrgDiarySexp
function OrgDiarySexp:new(fn, raw_expr)
  return setmetatable({ _eval = fn, _expr = raw_expr }, self)
end

---@param date OrgDate
---@return boolean
function OrgDiarySexp:matches(date)
  return self._eval(date)
end

-- Simple S-expression parser and evaluator specialized for diary sexp needs

---@param input string
---@return string[]
local function tokenize(input)
  local tokens = {}
  local i = 1
  local len = #input
  while i <= len do
    local ch = input:sub(i, i)
    if ch == '(' or ch == ')' then
      table.insert(tokens, ch)
      i = i + 1
    elseif ch == "'" then
      table.insert(tokens, ch)
      i = i + 1
    elseif ch:match('%s') then
      i = i + 1
    else
      local j = i
      while j <= len do
        local cj = input:sub(j, j)
        if cj:match('%s') or cj == '(' or cj == ')' then
          break
        end
        j = j + 1
      end
      local tok = input:sub(i, j - 1)
      table.insert(tokens, tok)
      i = j
    end
  end
  return tokens
end

---@param tokens string[]
---@param idx integer
---@return any, integer
local function parse_expr(tokens, idx)
  local tok = tokens[idx]
  if not tok then
    return nil, idx
  end
  if tok == "'" then
    local node
    node, idx = parse_expr(tokens, idx + 1)
    if not node then
      return nil, idx
    end
    return { 'quote', node }, idx
  end
  if tok == '(' then
    local list = {}
    idx = idx + 1
    while tokens[idx] ~= ')' do
      local node
      node, idx = parse_expr(tokens, idx)
      if node == nil then
        return nil, idx
      end
      table.insert(list, node)
      if not tokens[idx] then
        return nil, idx
      end
    end
    return list, idx + 1
  elseif tok == ')' then
    return nil, idx + 1
  else
    -- atom: number, boolean, or symbol
    local lower = tok:lower()
    if lower == 't' then
      return true, idx + 1
    end
    if lower == 'nil' then
      return false, idx + 1
    end
    local num = tonumber(tok)
    if num ~= nil then
      return num, idx + 1
    end
    return lower, idx + 1
  end
end

local function parse(sexp)
  local tokens = tokenize(sexp)
  local expr, next_idx = parse_expr(tokens, 1)
  if not expr or next_idx <= 1 then
    return nil
  end
  return expr
end

---@param date OrgDate
---@return table<string, number|boolean|string>
local function build_variables(date)
  local wday = date:get_weekday() or 1 -- 1..7 with 1=Sunday
  local dow = (wday - 1) % 7 -- 0..6, 0=Sunday
  return {
    year = date.year,
    month = date.month,
    day = date.day,
    isoweekday = date:get_isoweekday(), -- 1..7, 1=Mon
    dow = dow, -- 0..6, 0=Sun
  }
end

local dayname_to_dow = {
  sun = 0,
  mon = 1,
  tue = 2,
  tues = 2,
  wed = 3,
  thu = 4,
  thur = 4,
  thurs = 4,
  fri = 5,
  sat = 6,
}

---@param v any
---@param vars table<string, any>
---@return any
local function resolve(v, vars)
  if type(v) == 'string' then
    if vars[v] ~= nil then
      return vars[v]
    end
    if v == 't' then
      return true
    end
    if v == 'nil' then
      return false
    end
    local d = dayname_to_dow[v]
    if d ~= nil then
      return d
    end
  end
  return v
end

---@param ast any
---@param date OrgDate
---@return any
local function eval(ast, date)
  if type(ast) ~= 'table' then
    return resolve(ast, build_variables(date))
  end
  if #ast == 0 then
    return false
  end
  local op = ast[1]
  local args = {}
  for i = 2, #ast do
    args[#args + 1] = ast[i]
  end
  local function eval_arg(a)
    return eval(a, date)
  end

  if op == 'and' then
    for _, a in ipairs(args) do
      if not eval_arg(a) then
        return false
      end
    end
    return true
  end
  if op == 'or' then
    for _, a in ipairs(args) do
      if eval_arg(a) then
        return true
      end
    end
    return false
  end
  if op == 'not' then
    return not eval_arg(args[1])
  end
  if op == '=' then
    if #args < 2 then
      return false
    end
    local first = eval_arg(args[1])
    for i = 2, #args do
      if eval_arg(args[i]) ~= first then
        return false
      end
    end
    return true
  end
  if op == '<' or op == '>' or op == '<=' or op == '>=' then
    if #args ~= 2 then
      return false
    end
    local a = eval_arg(args[1])
    local b = eval_arg(args[2])
    if type(a) ~= 'number' or type(b) ~= 'number' then
      return false
    end
    if op == '<' then
      return a < b
    elseif op == '>' then
      return a > b
    elseif op == '<=' then
      return a <= b
    else
      return a >= b
    end
  end
  if op == 'mod' then
    if #args ~= 2 then
      return 0
    end
    local a = tonumber(eval_arg(args[1])) or 0
    local b = tonumber(eval_arg(args[2])) or 1
    if b == 0 then
      return 0
    end
    return a % b
  end
  if op == 'diary-date' then
    -- (diary-date month day [year])
    local month = tonumber(eval_arg(args[1]))
    local day = tonumber(eval_arg(args[2]))
    local year = args[3] and tonumber(eval_arg(args[3])) or nil
    if not month or not day then
      return false
    end
    if year then
      return date.year == year and date.month == month and date.day == day
    end
    return date.month == month and date.day == day
  end
  if op == 'diary-anniversary' then
    -- (diary-anniversary year month day) or (diary-anniversary month day year)
    local a1 = tonumber(eval_arg(args[1]))
    local a2 = tonumber(eval_arg(args[2]))
    local a3 = tonumber(eval_arg(args[3]))
    if not a1 or not a2 or not a3 then
      return false
    end
    local year, month, day
    if a1 >= 1000 then
      year, month, day = a1, a2, a3
    else
      month, day, year = a1, a2, a3
    end
    return date.month == month and date.day == day
  end
  if op == 'org-anniversary' then
    -- (org-anniversary year month day)
    local year = tonumber(eval_arg(args[1]))
    local month = tonumber(eval_arg(args[2]))
    local day = tonumber(eval_arg(args[3]))
    if not year or not month or not day then
      return false
    end
    return date.month == month and date.day == day
  end
  if op == 'diary-remind' then
    -- (diary-remind '(inner-expr) days)
    local inner = args[1]
    -- unwrap quote
    if type(inner) == 'table' and inner[1] == 'quote' then
      inner = inner[2]
    end
    if type(inner) ~= 'table' then
      return false
    end
    local days = tonumber(eval_arg(args[2])) or 0
    -- Fast path for supported anniversary/date forms
    local inner_op = inner[1]
    if inner_op == 'org-anniversary' or inner_op == 'diary-anniversary' or inner_op == 'diary-date' then
      local vars = build_variables(date)
      local month, day_of_month
      if inner_op == 'org-anniversary' then
        month = tonumber(resolve(inner[3], vars))
        day_of_month = tonumber(resolve(inner[4], vars))
      elseif inner_op == 'diary-anniversary' then
        -- (year month day) or (month day year)
        local a1 = tonumber(resolve(inner[2], vars))
        local a2 = tonumber(resolve(inner[3], vars))
        local a3 = tonumber(resolve(inner[4], vars))
        if a1 and a1 >= 1000 then
          month, day_of_month = a2, a3
        else
          month, day_of_month = a1, a2
        end
      else -- diary-date month day [year]
        month = tonumber(resolve(inner[2], vars))
        day_of_month = tonumber(resolve(inner[3], vars))
      end
      if not month or not day_of_month then
        return false
      end
      local event_date = date:set({ month = month, day = day_of_month })
      if event_date:is_same_or_after(date, 'day') then
        return event_date:diff(date) <= days
      end
      return false
    end
    for k = 0, days do
      local d = date:add({ day = k })
      local ok, res = pcall(eval, inner, d)
      if ok and res then
        return true
      end
    end
    return false
  end
  if op == 'diary-float' or op == 'org-float' then
    -- (diary-float month dow nth) where month can be t (any)
    local month_arg = args[1]
    local month = tonumber(eval_arg(month_arg))
    local dow = tonumber(eval_arg(args[2]))
    local nth = tonumber(eval_arg(args[3]))
    if month and date.month ~= month then
      return false
    end
    -- month_arg of t is parsed as boolean true (any month)
    if not month and month_arg ~= true then
      return false
    end
    if dow == nil or nth == nil then
      return false
    end
    -- Compute nth occurrence of dow in this month
    local first_of_month = date:set({ day = 1 })
    local first_wday = (first_of_month:get_weekday() - 1) % 7 -- 0..6
    local first_target_day
    if first_wday <= dow then
      first_target_day = 1 + (dow - first_wday)
    else
      first_target_day = 1 + (7 - (first_wday - dow))
    end
    if nth > 0 then
      local candidate_day = first_target_day + (nth - 1) * 7
      return date.day == candidate_day
    else
      -- Negative nth: count from end of month
      local last_day = date:last_day_of_month().day
      local last_target_day = first_target_day
      while last_target_day + 7 <= last_day do
        last_target_day = last_target_day + 7
      end
      local candidate_day = last_target_day + (nth + 1) * 7
      if candidate_day < 1 then
        return false
      end
      return date.day == candidate_day
    end
  end

  -- Unknown operator: don't match
  return false
end

---@param expr string
---@return OrgDiarySexp|nil
local function compile(expr)
  local ok, ast = pcall(parse, expr)
  if not ok or not ast then
    -- Fallbacks for simple shorthands like "mon", "tue" etc.
    local dn = type(expr) == 'string' and dayname_to_dow[expr:lower()]
    if dn ~= nil then
      return OrgDiarySexp:new(function(date)
        local vars = build_variables(date)
        return vars.dow == dn
      end, expr)
    end
    return nil
  end
  local function matcher(date)
    local success, res = pcall(eval, ast, date)
    if not success then
      return false
    end
    return res and true or false
  end
  return OrgDiarySexp:new(matcher, expr)
end

---Extract event date (month, day) and reminder window from a diary-remind AST.
---@param ast any
---@return number|nil month
---@return number|nil day_of_month
---@return number|nil remind_days
local function extract_remind_info(ast)
  if type(ast) ~= 'table' or ast[1] ~= 'diary-remind' then
    return nil, nil, nil
  end
  local inner = ast[2]
  if type(inner) == 'table' and inner[1] == 'quote' then
    inner = inner[2]
  end
  if type(inner) ~= 'table' then
    return nil, nil, nil
  end
  local days_arg = ast[3]
  local days = type(days_arg) == 'number' and days_arg or tonumber(days_arg)
  if not days then
    return nil, nil, nil
  end
  local inner_op = inner[1]
  local month, day_of_month
  if inner_op == 'org-anniversary' then
    month = tonumber(inner[3])
    day_of_month = tonumber(inner[4])
  elseif inner_op == 'diary-anniversary' then
    local a1 = tonumber(inner[2])
    local a2 = tonumber(inner[3])
    local a3 = tonumber(inner[4])
    if a1 and a1 >= 1000 then
      month, day_of_month = a2, a3
    else
      month, day_of_month = a1, a2
    end
  elseif inner_op == 'diary-date' then
    month = tonumber(inner[2])
    day_of_month = tonumber(inner[3])
  end
  if not month or not day_of_month then
    return nil, nil, nil
  end
  return month, day_of_month, days
end

local M = {}

---@param expr string
---@return OrgDiarySexp|nil
function M.parse(expr)
  if type(expr) ~= 'string' then
    return nil
  end
  local trimmed = vim.trim(expr)
  if trimmed == '' then
    return nil
  end
  if not trimmed:match('^%(') then
    trimmed = '(' .. trimmed .. ')'
  end
  return compile(trimmed)
end

---Extract event month/day and reminder days from a diary-remind expression string.
---@param expr string
---@return number|nil month
---@return number|nil day_of_month
---@return number|nil remind_days
function M.extract_remind_info(expr)
  if type(expr) ~= 'string' then
    return nil, nil, nil
  end
  local trimmed = vim.trim(expr)
  if not trimmed:match('^%(') then
    trimmed = '(' .. trimmed .. ')'
  end
  local ok, ast = pcall(parse, trimmed)
  if not ok or not ast then
    return nil, nil, nil
  end
  return extract_remind_info(ast)
end

return M
