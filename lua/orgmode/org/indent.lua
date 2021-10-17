local config = require('orgmode.config')

local function foldexpr()
  local line = vim.fn.getline(vim.v.lnum)
  if line:find('^%s*#%+%S+:') then
    return 0
  end

  local stars = line:match('^(%*+)%s+')

  if stars then
    local next_line = vim.fn.getline(vim.v.lnum + 1)
    local next_line_star = next_line:match('^(%*+)%s+')
    if next_line_star and next_line_star:len() == stars:len() then
      return -1
    end
    return '>' .. stars:len()
  end

  if line:match('^%s*:END:%s*$') then
    return 's1'
  end

  if line:match('^%s*:[^:]*:%s*$') then
    return 'a1'
  end

  return '='
end

local function noindent_mode()
  local prev_line = vim.fn.prevnonblank(vim.v.lnum - 1)
  if prev_line <= 0 then
    return 0
  end
  local line = vim.fn.getline(prev_line)

  local list_item = line:match('^(%s*[%+%-]%s+)')
  if list_item then
    return list_item:len()
  end

  return 0
end

local function indentexpr()
  if config.org_indent_mode == 'noindent' then
    return noindent_mode()
  end

  local cur_line = vim.trim(vim.fn.getline(vim.v.lnum))
  if cur_line ~= '' then
    return -1
  end

  local prev_line = vim.fn.prevnonblank(vim.v.lnum - 1)
  if prev_line <= 0 then
    return 0
  end
  local line = vim.fn.getline(prev_line)
  if line:find('^%s*#%+%S+:') then
    return 0
  end

  local stars = line:match('^(%*+)%s+')
  if stars then
    return stars:len() + 1
  end
  local list_item = line:match('^(%s*[%+%-]%s+)')
  if list_item then
    return list_item:len()
  end
  return vim.fn.indent(prev_line)
end

local function foldtext()
  local line = vim.fn.getline(vim.v.foldstart)
  if config.org_hide_leading_stars then
    return vim.fn.substitute(line, '\\(^\\**\\)', '\\=repeat(" ", len(submatch(0))-1) . "*"', '')
  end
  return line
end

return {
  foldexpr = foldexpr,
  indentexpr = indentexpr,
  foldtext = foldtext,
}
