local config = require('orgmode.config')
local ts_utils = require('nvim-treesitter.ts_utils')
local query = nil

local function get_indent_for_linenr(matches, linenr, mode)
  linenr = linenr or vim.v.lnum
  mode = mode or vim.fn.mode()
  local noindent_mode = config.org_indent_mode == 'noindent'
  local prev_linenr = vim.fn.prevnonblank(linenr - 1)
  local match = matches[linenr]
  local prev_line_match = matches[prev_linenr]

  if not match and not prev_line_match then
    return -1
  end

  match = match or {}
  prev_line_match = prev_line_match or {}

  if prev_line_match.type == 'headline' then
    if noindent_mode or (match.type == 'headline' and match.stars > 0) then
      return 0
    end
    return prev_line_match.indent
  end

  if match.type == 'headline' then
    return 0
  end

  if match.type == 'listitem' then
    -- We first figure out the indent of the first line of a listitem. Then we
    -- check if we're on the first line or a "hanging" line. In the latter
    -- case, we add the overhang.
    local first_line_indent
    local parent_linenr = match.nesting_parent_linenr
    if parent_linenr then
      local parent_match = matches[parent_linenr]
      if parent_match.type == 'listitem' then
        -- Nested listitem. Because two listitems cannot start on the same line,
        -- we simply fetch the parent's indentation and add its overhang.
        -- Don't use parent_match.indent, it might be stale if the parent
        -- already got reindented.
        first_line_indent = vim.fn.indent(parent_linenr) + parent_match.overhang
      elseif parent_match.type == 'headline' and not noindent_mode then
        -- Un-nested list inside a section, indent according to section.
        first_line_indent = parent_match.indent
      else
        -- Noindent mode.
        first_line_indent = 0
      end
    else
      -- Top-level list before the first headline.
      first_line_indent = 0
    end
    -- Add overhang if this is a hanging line.
    if linenr ~= match.line_nr then
      return first_line_indent + match.overhang
    end
    return first_line_indent
  end

  -- In insert mode, we also count the non-listitem line *after* a listitem as
  -- part of the listitem. Keep in mind that double empty lines end a list as
  -- per Orgmode syntax.
  if mode:match('^[iR]') and prev_line_match.type == 'listitem' and linenr - prev_linenr < 3 then
    -- After the first line of a listitem, we have to add the overhang to the
    -- listitem's own base indent. After all further lines, we can simply copy
    -- the indentation.
    if prev_linenr == prev_line_match.line_nr then
      return vim.fn.indent(prev_linenr) + prev_line_match.overhang
    end
    return vim.fn.indent(prev_linenr)
  end

  if match.indent_type == 'block' then
    return match.indent
  end

  if noindent_mode then
    return 0
  end

  if match.indent_type == 'other' then
    return match.indent
  end

  return vim.fn.indent(prev_linenr)
end

local get_matches = ts_utils.memoize_by_buf_tick(function(bufnr)
  local tree = vim.treesitter.get_parser(bufnr, 'org', {}):parse()
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
        node = node,
        parent = node:parent(),
        line_nr = range.start.line + 1,
        line_end_nr = range['end'].line,
        name = query.captures[id],
        indent = vim.fn.indent(range.start.line + 1),
      }

      if type == 'headline' then
        opts.stars = vim.treesitter.get_node_text(node:field('stars')[1], bufnr):len()
        opts.indent = opts.indent + opts.stars + 1
        matches[range.start.line + 1] = opts
      end

      if type == 'listitem' then
        local content = node:named_child(1)
        if content then
          local content_linenr, content_indent = content:start()
          if content_linenr == range.start.line then
            opts.overhang = content_indent - opts.indent
          end
        end
        if not opts.overhang then
          local bullet = node:named_child(0)
          opts.overhang = vim.treesitter.get_node_text(bullet, bufnr):len() + 1
        end

        local parent = node:parent()
        while parent and parent:type() ~= 'section' and parent:type() ~= 'listitem' do
          parent = parent:parent()
        end
        opts.nesting_parent_linenr = parent and (parent:start() + 1)

        for i = range.start.line, range['end'].line - 1 do
          matches[i + 1] = opts
        end
      end

      if type == 'block' then
        opts.indent_type = 'block'
        local parent = node:parent()
        while parent and parent:type() ~= 'section' and parent:type() ~= 'listitem' do
          parent = parent:parent()
        end
        -- We want to find the difference in indentation level between the item to be indented and the parent node.
        -- If the item is in the block, we shouldn't change the indentation beyond how much we modify the indent of the
        -- block header and footer. This keeps code correctly indented in `BEGIN_SRC` blocks as well as ensuring
        -- `BEGIN_EXAMPLE` blocks don't have their indentation changed inside of them.
        local parent_indent = get_indent_for_linenr(matches, parent:start() + 1)

        if config.org_indent_mode == 'indent' and parent:type() == 'section' then
          local headline = parent:named_child('headline')
          if headline then
            local stars = vim.treesitter.get_node_text(headline:field('stars')[1], bufnr):len() + 1
            parent_indent = stars
          end
        end

        -- We want to align to the listitem body, not the bullet
        if parent:type() == 'listitem' then
          parent_indent = parent_indent + 2
        end

        local curr_header_indent = vim.fn.indent(range.start.line + 1)
        local header_indent_diff = curr_header_indent - parent_indent
        local new_header_indent = curr_header_indent - header_indent_diff
        -- Ensure the block footer is properly aligned with the header
        matches[range['end'].line] = vim.tbl_deep_extend('force', opts, {
          indent = new_header_indent,
        })

        local content_indent_pad = 0
        -- Only include the header line and the content. Do not include the footer in the loop.
        for i = range.start.line, range['end'].line - 2 do
          local curr_indent = vim.fn.indent(i + 1)
          -- Correctly align the pad to the new header position if it was underindented
          local new_indent_pad = new_header_indent - curr_indent
          -- If the current content indentaion is less than the new header indent we want to increase all of the
          -- content by the largest difference in indentation between a given content line and the new header indent.
          if curr_indent < new_header_indent then
            content_indent_pad = math.max(new_indent_pad, content_indent_pad)
          else
            -- If the current content indentation is more than the new header indentation, but it was the current
            -- content indentation was less than the current header indent then we want to add some indentation onto
            -- the content by the largest negative difference (meaning -1 > -2 > -3 so take -1 as the pad).
            --
            -- We do a check for 0 here as we don't want to do a max of neg number against 0. 0 will always win. As
            -- such if the current pad is 0 just set to the new calculated pad.
            if content_indent_pad == 0 then
              content_indent_pad = new_indent_pad
            else
              content_indent_pad = math.max(new_indent_pad, content_indent_pad)
            end
          end
          matches[i + 1] = vim.tbl_deep_extend('force', opts, {
            indent = curr_indent - header_indent_diff,
          })
        end
        -- If any of the content is underindented relative to the header and footer, we need to indent all of the
        -- content until the most underindented content is equal in indention to the header and footer.
        --
        -- Only loop the content.
        for i = range.start.line + 1, range['end'].line - 2 do
          matches[i + 1] = vim.tbl_deep_extend('force', opts, {
            indent = vim.fn.indent(i + 1) + content_indent_pad,
          })
        end
      elseif type == 'paragraph' or type == 'drawer' or type == 'property_drawer' then
        opts.indent_type = 'other'
        local parent = node:parent()
        while parent and parent:type() ~= 'section' do
          parent = parent:parent()
        end
        if parent then
          local headline = parent:named_child('headline')
          local stars = vim.treesitter.get_node_text(headline:field('stars')[1], bufnr):len()
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

local prev_section = nil
local function foldexpr()
  query = query or vim.treesitter.query.get('org', 'org_indent')
  local matches = get_matches(0)
  local match = matches[vim.v.lnum]
  local next_match = matches[vim.v.lnum + 1]
  if not match and not next_match then
    return '='
  end
  match = match or {}

  if match.type == 'headline' then
    prev_section = match
    if
      match.parent:parent():type() ~= 'section'
      and match.stars > 1
      and match.parent:named_child_count('section') == 0
    then
      return 0
    end
    return '>' .. match.stars
  end

  if match.type == 'drawer' or match.type == 'property_drawer' or match.type == 'block' then
    if match.line_nr == vim.v.lnum then
      return 'a1'
    end
    if match.line_end_nr == vim.v.lnum then
      return 's1'
    end
  end

  if next_match and next_match.type == 'headline' and prev_section then
    if next_match.stars <= prev_section.stars then
      return '<' .. prev_section.stars
    end
  end

  return '='
end

local function indentexpr(linenr, mode)
  linenr = linenr or vim.v.lnum
  mode = mode or vim.fn.mode()
  query = query or vim.treesitter.query.get('org', 'org_indent')
  local matches = get_matches(0)

  return get_indent_for_linenr(matches, linenr, mode)
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
