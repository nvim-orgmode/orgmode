local config = require('orgmode.config')
local Files = require('orgmode.parser.files')

local prev_section = nil
local function foldexpr()
  local line = vim.fn.getline(vim.v.lnum)
  if line:find('^%s*#%+%S+:') then
    return 0
  end

  local stars = line:match('^(%*+)%s+')

  if stars then
    local file = Files.get(vim.fn.expand('%:p'))
    if not file then
      return 0
    end
    local section = file.sections_by_line[vim.v.lnum]
    prev_section = section
    if not section.parent and section.level > 1 and not section:has_children() then
      return 0
    end
    return '>' .. section.level
  end

  if line:match('^%s*:END:%s*$') then
    return 's1'
  end

  if line:match('^%s*:[^:]*:%s*$') then
    return 'a1'
  end

  if vim.fn.getline(vim.v.lnum + 1):match('^(%*+)%s+') and prev_section then
    local file = Files.get(vim.fn.expand('%:p'))
    if not file then
      return 0
    end
    local section = file.sections_by_line[vim.v.lnum + 1]
    if section.level <= prev_section.level then
      return '<' .. prev_section.level
    end
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
    line = vim.fn.substitute(line, '\\(^\\*\\+\\)', '\\=repeat(" ", len(submatch(0))-1) . "*"', '')
  end

  if vim.opt.conceallevel:get() > 0 then
    line = string.gsub(line, '%[%[(.-)%]%[?(.-)%]%]$', function(link, text)
      if text == '' then
        return link
      else
        return text
      end
    end)
  end

  return line .. config.org_ellipsis
end

return {
  foldexpr = foldexpr,
  indentexpr = indentexpr,
  foldtext = foldtext,
}
