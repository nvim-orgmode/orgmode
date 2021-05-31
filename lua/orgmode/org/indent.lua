local function foldexpr()
  local line = vim.fn.getline(vim.v.lnum)
  if line:find('^%s*#%+%S+:') then
    return 0
  end

  local stars = line:match('^(%*+)%s+')

  if stars then
    return '>'..stars:len()
  end

  if line:match('^%s*:END:%s*$') then
    return 's1'
  end

  if line:match('^%s*:[^:]*:%s*$') then
    return 'a1'
  end

  return '='
end

local function indentexpr()
  local prev_line = vim.fn.prevnonblank(vim.v.lnum - 1)
  if prev_line <= 0 then return 0 end
  local line = vim.fn.getline(prev_line)
  if line:find('^%s*#%+%S+:') then
    return 0
  end

  local stars = line:match('^(%*+)%s+')
  if stars then
    return stars:len() + 1
  end
  local checkbox = line:match('^(%s*[%+%-]%s+)%[.?%]')
  if checkbox then
    return checkbox:len()
  end
  return vim.fn.indent(prev_line)
end

return {
  foldexpr = foldexpr,
  indentexpr = indentexpr,
}
