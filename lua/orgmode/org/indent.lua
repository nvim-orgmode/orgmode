local config = require('orgmode.config')
local Files = require('orgmode.parser.files')
local ts_utils = require('nvim-treesitter.ts_utils')
local query = nil

local prev_section = nil
local function foldexpr()
  local line = vim.fn.getline(vim.v.lnum)

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

local function get_is_list_item(line)
  local line_numbered_list_item = line:match('^%s*(%d+[%)%.]%s+)')
  local line_unordered_list_item = line:match('^%s*([%+%-]%s+)')
  return line_numbered_list_item or line_unordered_list_item
end

local get_indent_matches = ts_utils.memoize_by_buf_tick(function(bufnr)
  local tree = vim.treesitter.get_parser(bufnr, 'org'):parse()
  if not tree or not #tree then
    return {}
  end
  local matches = {}
  local root = tree[1]:root()
  for _, match, _ in query:iter_matches(root, bufnr, 0, -1) do
    for id, node in pairs(match) do
      local range = ts_utils.node_to_lsp_range(node)
      local type = node:type()

      local opts = {
        type = type,
        line_nr = range.start.line + 1,
        name = query.captures[id],
        indent = vim.fn.indent(range.start.line + 1),
      }

      if type == 'headline' then
        opts.stars = vim.treesitter.query.get_node_text(node:field('stars')[1], bufnr):len()
        opts.indent = opts.indent + opts.stars + 1
        matches[range.start.line + 1] = opts
      end

      if type == 'list' then
        local first_list_item = node:named_child(0)
        local first_list_item_linenr = first_list_item:start()
        local first_item_indent = vim.fn.indent(first_list_item_linenr + 1)
        opts.indent = first_item_indent

        for i = range.start.line, range['end'].line - 1 do
          matches[i + 1] = opts
        end
      end

      if type == 'paragraph' or type == 'drawer' or type == 'property_drawer' then
        opts.type = 'other'
        local parent = node:parent()
        while parent and parent:type() ~= 'section' do
          parent = parent:parent()
          if not parent then
            break
          end
        end
        if parent then
          local headline = parent:named_child('headline')
          local stars = vim.treesitter.query.get_node_text(headline:field('stars')[1], bufnr):len()
          opts.indent = stars + 1
          for i = range.start.line, range['end'].line - 1 do
            matches[i + 1] = opts
          end
        end
      end
    end
  end

  return matches
end)

local function indentexpr()
  local noindent_mode = config.org_indent_mode == 'noindent'

  if not query then
    query = vim.treesitter.get_query('org', 'org_indent')
  end

  local prev_linenr = vim.fn.prevnonblank(vim.v.lnum - 1)

  local matches = get_indent_matches(0)
  local match = matches[vim.v.lnum]
  local prev_line_match = matches[prev_linenr]

  if not match and not prev_line_match then
    return -1
  end

  match = match or {}
  prev_line_match = prev_line_match or {}

  if match.type == 'headline' then
    return 0
  end

  if prev_line_match.type == 'headline' then
    if noindent_mode then
      return 0
    end
    return prev_line_match.indent
  end

  if match.type == 'list' and prev_line_match.type == 'list' then
    local prev_line_list_item = get_is_list_item(vim.fn.getline(prev_linenr))
    local cur_line_list_item = get_is_list_item(vim.fn.getline(vim.v.lnum))

    if cur_line_list_item then
      local diff = match.indent - vim.fn.indent(match.line_nr)
      local indent = vim.fn.indent(vim.v.lnum)
      return indent - diff
    end

    if prev_line_list_item then
      return vim.fn.indent(prev_linenr) + prev_line_list_item:len()
    end
  end

  if noindent_mode then
    return 0
  end

  if match.type == 'other' then
    return match.indent
  end

  return vim.fn.indent(prev_linenr)
end

local function foldtext()
  local line = vim.fn.getline(vim.v.foldstart)

  if config.org_hide_leading_stars then
    line = vim.fn.substitute(line, '\\(^\\*\\+\\)', '\\=repeat(" ", len(submatch(0))-1) . "*"', '')
  end

  if vim.opt.conceallevel:get() > 0 and string.find(line, '[[', 1, true) then
    line = string.gsub(line, '%[%[(.-)%]%[?(.-)%]?%]', function(link, text)
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
