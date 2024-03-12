local config = require('orgmode.config')
local VirtualIndent = require('orgmode.ui.virtual_indent')
local ts_utils = require('orgmode.utils.treesitter')
local utils = require('orgmode.utils')
---@type vim.treesitter.Query
local query = nil

local function get_indent_pad(linenr, bufnr)
  if config:should_indent(bufnr) then
    local headline = ts_utils.closest_headline_node({ linenr, 0 })
    if not headline then
      return 0
    end
    local _, level = headline:field('stars')[1]:end_()
    return level + 1
  end
  return 0
end

local function get_indent_for_match(matches, linenr, mode, bufnr)
  linenr = linenr or vim.v.lnum
  mode = mode or vim.fn.mode()
  local prev_linenr = vim.fn.prevnonblank(linenr - 1)
  local match = matches[linenr]
  local prev_line_match = matches[prev_linenr]
  local indent = 0

  if not match and not prev_line_match then
    return indent + get_indent_pad(linenr, bufnr)
  end

  match = match or {}
  prev_line_match = prev_line_match or {}

  if match.type == 'headline' then
    -- We ensure we check headlines (even if a bit redundant) to ensure nothing else is checked below
    return 0
  end
  if match.type == 'listitem' then
    -- We first figure out the indent of the first line of a listitem. Then we
    -- check if we're on the first line or a "hanging" line. In the latter
    -- case, we add the overhang.
    local first_line_indent = nil
    local parent_linenr = match.nesting_parent_linenr
    if parent_linenr then
      local parent_match = matches[parent_linenr]
      if parent_match.type == 'listitem' then
        -- Nested listitem. We recursively find the correct indent for this
        -- based on its parents correct indentation level.
        first_line_indent = vim.fn.indent(parent_linenr) + parent_match.overhang
      end
    end
    -- If the first_line_indent wasn't found then this is the root of the list, as such we just pad accordingly
    indent = first_line_indent or (0 + get_indent_pad(linenr, bufnr))
    -- If the current line is hanging content as part of the listitem but not on the same line we want to indent it
    -- such that it's in line with the general content body, not the bullet.
    --
    -- - I am the "first" line listitem
    --   I am the content body as part of the listitem, but on a different line!
    if linenr ~= match.line_nr then
      indent = indent + match.overhang
    end
    return indent
  end
  if mode:match('^[iR]') and prev_line_match.type == 'listitem' and linenr - prev_linenr < 3 then
    -- In insert mode, we also count the non-listitem line *after* a listitem as
    -- part of the listitem. Keep in mind that double empty lines end a list as
    -- per Orgmode syntax.
    --
    -- After the first line of a listitem, we have to add the overhang to the
    -- listitem's own base indent. After all further lines, we can simply copy
    -- the indentation.
    indent = get_indent_for_match(matches, prev_linenr, mode, bufnr)
    if prev_linenr == prev_line_match.line_nr then
      indent = indent + prev_line_match.overhang
    end
    return indent
  end
  if match.indent_type == 'block' then
    -- Blocks do some precalculation of their own against the intended indent level of the parent. As such we just want
    -- to return their indent without any other modifications.
    return match.indent
  end

  return indent + get_indent_pad(linenr, bufnr)
end

local get_matches = ts_utils.memoize_by_buf_tick(function(bufnr)
  local tree = vim.treesitter.get_parser(bufnr, 'org', {}):parse()
  if not tree or not #tree then
    return false
  end
  local matches = {}
  local mode = vim.fn.mode()
  local root = tree[1]:root()
  if root:has_error() then
    return false
  end
  for id, node in query:iter_captures(root, bufnr, 0, -1) do
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
      local _, level = node:field('stars')[1]:end_()
      opts.stars = level
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
      local prev_sibling = node:prev_sibling()
      opts.prev_sibling_linenr = prev_sibling and (prev_sibling:start() + 1)
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
      local start = (parent and parent:start() or node:start()) + 1
      local parent_indent = get_indent_for_match(matches, start, mode, bufnr)

      -- We want to align to the listitem body, not the bullet
      if parent and parent:type() == 'listitem' then
        local parent_linenr = parent:start() + 1
        parent_indent = parent_indent + matches[parent_linenr].overhang
      else
        parent_indent = get_indent_pad(range.start.line + 1, bufnr)
      end

      local curr_header_indent = vim.fn.indent(range.start.line + 1)
      local header_indent_diff = curr_header_indent - parent_indent
      local new_header_indent = curr_header_indent - header_indent_diff
      -- Ensure the block footer is properly aligned with the header
      matches[range.start.line + 1] = vim.tbl_deep_extend('force', opts, {
        indent = new_header_indent,
      })
      matches[range['end'].line] = vim.tbl_deep_extend('force', opts, {
        indent = new_header_indent,
      })

      local content_indent_pad
      -- Only include the header line and the content. Do not include the footer in the loop.
      for i = range.start.line + 1, range['end'].line - 2 do
        local linenr = i + 1
        local line_content = vim.api.nvim_buf_get_lines(bufnr, linenr - 1, linenr, true)[1]
        -- If the line is blank, we should ignore it as `vim.fn.indent` will return a 0 indent for
        -- it which may be less indented than the header indentation. We shouldn't factor in blank
        -- lines for indentation.
        if not line_content:match('^$') then
          local curr_indent = vim.fn.indent(linenr)
          -- Correctly align the pad to the new header position if it was underindented
          local new_indent_pad = new_header_indent - curr_indent
          -- If the current content indentaion is less than the new header indent we want to increase all of the
          -- content by the largest difference in indentation between a given content line and the new header indent.
          if curr_indent < new_header_indent then
            content_indent_pad = math.max(new_indent_pad, content_indent_pad or 0)
          else
            -- If the current content indentation is more than the new header indentation, but it was the current
            -- content indentation was less than the current header indent then we want to add some indentation onto
            -- the content by the largest negative difference (meaning -1 > -2 > -3 so take -1 as the pad).
            --
            -- We do a check for 0 here as we don't want to do a max of neg number against 0. 0 will always win. As
            -- such if the current pad is 0 just set to the new calculated pad.
            if not content_indent_pad then
              content_indent_pad = new_indent_pad
            else
              content_indent_pad = math.max(new_indent_pad, content_indent_pad)
            end
          end
        end
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

-- Some explanation as to the caching insanity inside of this function. The `get_matches` function
-- is memoized, but that only goes so far. When a user wants to indent a large region, say with
-- `norm! 0gg=G` every indent operation will call `get_matches` and get *new* matches. For the most
-- part, this is fine, but on occasion the cache can end up invalidated when the indent operation doesn't
-- occur fast enough. When the cache is invalidated new matches are returned and this leads to an
-- issue in which the indent calculated for the line is no longer correct as it is based on bad
-- data. This causes indents, especially for lists, to be incorrect as many indents are dependent on
-- the previous node's indentation.
--
-- By caching the matches and previous line numbers matched we can effectively check if a range was
-- requested for indentation and, if so, stop requesting new matches; then we only use the initial
-- matches while updating the previous indent amounts as we return the new indents. We invalidate
-- the cached matches when the user isn't in normal mode as it's likely they're modifying buffer
-- content which requires us to get the updated matches for the changed content.
--
-- TLDR: The caching avoids some inconsistent race conditions with getting the Treesitter matches.
local buf_indentexpr_cache = {}
local function indentexpr(linenr, bufnr)
  linenr = linenr or vim.v.lnum
  local mode = vim.fn.mode()
  query = query or vim.treesitter.query.get('org', 'org_indent')

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local indentexpr_cache = buf_indentexpr_cache[bufnr] or { prev_linenr = -1 }
  if indentexpr_cache.prev_linenr ~= linenr - 1 or not mode:lower():find('n') then
    indentexpr_cache.matches = get_matches(bufnr)
  end

  -- Treesitter failed to parse the document (due to errors or missing tree)
  -- So we just fallback to autoindent
  if indentexpr_cache.matches == false then
    return -1
  end

  local new_indent = get_indent_for_match(indentexpr_cache.matches, linenr, mode, bufnr)
  local match = indentexpr_cache.matches[linenr]
  if match then
    match.indent = new_indent
  end
  indentexpr_cache.prev_linenr = linenr
  buf_indentexpr_cache[bufnr] = indentexpr_cache
  return new_indent
end

local function foldtext()
  local line = vim.fn.getline(vim.v.foldstart)

  if config:hide_leading_stars(vim.api.nvim_get_current_buf()) then
    line = vim.fn.substitute(line, '\\(^\\*\\+\\)', '\\=repeat(" ", len(submatch(0))-1) . "*"', '') or ''
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

local function setup_virtual_indent()
  if not utils.has_version_10() then
    return
  end

  local virtualIndent = VirtualIndent:new()

  if config.org_startup_indented or vim.b.org_indent_mode then
    return virtualIndent:attach()
  end

  return virtualIndent:start_watch_org_indent()
end

return {
  setup_virtual_indent = setup_virtual_indent,
  foldexpr = foldexpr,
  indentexpr = indentexpr,
  foldtext = foldtext,
}
