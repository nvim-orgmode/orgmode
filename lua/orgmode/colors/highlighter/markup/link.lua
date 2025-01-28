---@class OrgLinkHighlighter : OrgMarkupHighlighter
---@field private markup OrgMarkupHighlighter
---@field private has_extmark_url_support boolean
---@field private last_start_node_id? string
local OrgLink = {
  valid_capture_names = {
    ['link.start'] = true,
    ['link.end'] = true,
  },
}

---@param opts { markup: OrgMarkupHighlighter }
function OrgLink:new(opts)
  local data = {
    markup = opts.markup,
    has_extmark_url_support = vim.fn.has('nvim-0.10.2') == 1,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param node TSNode
---@param name string
---@return OrgMarkupNode | false
function OrgLink:parse_node(node, name)
  if not self.valid_capture_names[name] then
    return false
  end
  local type = node:type()
  if type == '[' then
    return self:_parse_start_node(node)
  end

  if type == ']' then
    return self:_parse_end_node(node)
  end

  return false
end

---@private
---@param node TSNode
---@return OrgMarkupNode | false
function OrgLink:_parse_start_node(node)
  local node_type = node:type()
  local next_sibling = node:next_sibling()
  local prev_sibling = node:prev_sibling()

  -- Start of link
  if next_sibling and next_sibling:type() == '[' then
    local id = table.concat({ 'link', '[' }, '_')
    local seek_id = table.concat({ 'link', ']' }, '_')
    self.last_start_node_id = node:id()
    return {
      type = 'link',
      id = id,
      char = node_type,
      seek_id = seek_id,
      nestable = false,
      range = self.markup:node_to_range(node),
      metadata = {
        type = 'link_start',
      },
      node = node,
    }
  end

  -- Start of link alias
  if prev_sibling and prev_sibling:type() == ']' then
    local id = table.concat({ 'link', '[' }, '_')
    local seek_id = table.concat({ 'link', ']' }, '_')
    return {
      type = 'link',
      id = id,
      char = node_type,
      seek_id = seek_id,
      nestable = true,
      range = self.markup:node_to_range(node),
      metadata = {
        type = 'link_alias_start',
        start_node_id = self.last_start_node_id,
      },
      node = node,
    }
  end

  return false
end

---@private
---@param node TSNode
---@return OrgMarkupNode | false
function OrgLink:_parse_end_node(node)
  local node_type = node:type()
  local prev_sibling = node:prev_sibling()
  local next_sibling = node:next_sibling()

  -- End of link, start of alias
  if next_sibling and next_sibling:type() == '[' then
    local id = table.concat({ 'link', ']' }, '_')
    local seek_id = table.concat({ 'link', '[' }, '_')
    return {
      type = 'link',
      id = id,
      char = node_type,
      seek_id = seek_id,
      range = self.markup:node_to_range(node),
      nestable = false,
      node = node,
      metadata = {
        type = 'link_end_alias_start',
        start_node_id = self.last_start_node_id,
      },
    }
  end

  -- End of link
  if prev_sibling and prev_sibling:type() == ']' then
    local id = table.concat({ 'link', ']' }, '_')
    local seek_id = table.concat({ 'link', '[' }, '_')
    local result = {
      type = 'link',
      id = id,
      char = node_type,
      seek_id = seek_id,
      range = self.markup:node_to_range(node),
      nestable = false,
      metadata = {
        type = 'link_end',
      },
      node = node,
    }
    result.metadata.start_node_id = self.last_start_node_id
    self.last_start_node_id = nil
    return result
  end

  return false
end

---@param entry OrgMarkupNode
---@return boolean
function OrgLink:is_valid_start_node(entry)
  return entry.type == 'link' and entry.id == 'link_['
end

---@param entry OrgMarkupNode
---@return boolean
function OrgLink:is_valid_end_node(entry)
  return entry.type == 'link' and entry.id == 'link_]'
end

function OrgLink:_get_url(bufnr, line, start_col, end_col)
  if not self.has_extmark_url_support then
    return nil
  end

  return vim.api.nvim_buf_get_text(bufnr, line, start_col, line, end_col, {})[1]
end

---@param highlights OrgMarkupHighlight[]
---@param bufnr number
function OrgLink:highlight(highlights, bufnr)
  local namespace = self.markup.highlighter.namespace
  local ephemeral = self.markup:use_ephemeral()

  for i, entry in ipairs(highlights) do
    local prev_entry = highlights[i - 1]
    local next_entry = highlights[i + 1]
    if not entry.metadata.start_node_id then
      goto continue
    end

    -- Alias without the valid end link
    if
      entry.metadata.type == 'link_end_alias_start'
      and (
        not next_entry
        or next_entry.metadata.type ~= 'link_end'
        or entry.metadata.start_node_id ~= next_entry.metadata.start_node_id
      )
    then
      goto continue
    end

    -- End node without the valid alias
    if
      entry.metadata.type == 'link_end'
      and (
        prev_entry
        and prev_entry.metadata.type == 'link_end_alias_start'
        and prev_entry.metadata.start_node_id ~= entry.metadata.start_node_id
      )
    then
      goto continue
    end

    local link_opts = {
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      hl_group = '@org.hyperlink',
      priority = 110,
    }

    if entry.metadata.type == 'link_end_alias_start' then
      link_opts.url = self:_get_url(bufnr, entry.from.line, entry.from.start_col + 2, entry.to.end_col - 1)
      link_opts.spell = false
      entry.url = link_opts.url
      -- Conceal the whole target (marked with << and >>)
      -- <<[[https://neovim.io][>>Neovim]]
      vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
        ephemeral = ephemeral,
        end_col = entry.to.end_col + 1,
        conceal = '',
      })
    end

    if entry.metadata.type == 'link_end' then
      if prev_entry and prev_entry.metadata.type == 'link_end_alias_start' then
        link_opts.url = prev_entry.url
      else
        link_opts.url = self:_get_url(bufnr, entry.from.line, entry.from.start_col + 2, entry.to.end_col - 2)
        -- Conceal the start marker (marked with << and >>)
        -- <<[[>>https://neovim.io][Neovim]]
        vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
          ephemeral = ephemeral,
          end_col = entry.from.start_col + 2,
          conceal = '',
        })
      end
      -- Conceal the end marker (marked with << and >>)
      -- [[https://neovim.io][Neovim<<]]>>
      vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.to.end_col - 2, {
        ephemeral = ephemeral,
        end_col = entry.to.end_col,
        conceal = '',
      })
    end

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, link_opts)
    ::continue::
  end
end

---@param highlights OrgMarkupHighlight[]
---@param source_getter_fn fun(start_col: number, end_col: number): string
---@return OrgMarkupPreparedHighlight[]
function OrgLink:prepare_highlights(highlights, source_getter_fn)
  local ephemeral = self.markup:use_ephemeral()
  local extmarks = {}

  for i, entry in ipairs(highlights) do
    local prev_entry = highlights[i - 1]
    local next_entry = highlights[i + 1]
    if not entry.metadata.start_node_id then
      goto continue
    end

    -- Alias without the valid end link
    if
      entry.metadata.type == 'link_end_alias_start'
      and (
        not next_entry
        or next_entry.metadata.type ~= 'link_end'
        or entry.metadata.start_node_id ~= next_entry.metadata.start_node_id
      )
    then
      goto continue
    end

    -- End node without the valid alias
    if
      entry.metadata.type == 'link_end'
      and (
        prev_entry
        and prev_entry.metadata.type == 'link_end_alias_start'
        and prev_entry.metadata.start_node_id ~= entry.metadata.start_node_id
      )
    then
      goto continue
    end

    local link_opts = {
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      hl_group = '@org.hyperlink',
      priority = 110,
    }

    if entry.metadata.type == 'link_end_alias_start' then
      link_opts.url = source_getter_fn(entry.from.end_col + 2, entry.to.end_col - 1)
      link_opts.spell = false
      entry.url = link_opts.url
      -- Conceal the whole target (marked with << and >>)
      -- <<[[https://neovim.io][>>Neovim]]
      table.insert(extmarks, {
        start_line = entry.from.line,
        start_col = entry.from.start_col,
        end_col = entry.to.end_col + 1,
        ephemeral = ephemeral,
        conceal = '',
      })
    end

    if entry.metadata.type == 'link_end' then
      if prev_entry and prev_entry.metadata.type == 'link_end_alias_start' then
        link_opts.url = prev_entry.url
      else
        link_opts.url = source_getter_fn(entry.from.end_col + 2, entry.to.end_col - 2)
        -- Conceal the start marker (marked with << and >>)
        -- <<[[>>https://neovim.io][Neovim]]
        table.insert(extmarks, {
          start_line = entry.from.line,
          start_col = entry.from.start_col,
          end_col = entry.from.start_col + 2,
          ephemeral = ephemeral,
          conceal = '',
        })
      end
      -- Conceal the end marker (marked with << and >>)
      -- [[https://neovim.io][Neovim<<]]>>
      table.insert(extmarks, {
        start_line = entry.from.line,
        start_col = entry.to.end_col - 2,
        end_col = entry.to.end_col,
        ephemeral = ephemeral,
        conceal = '',
      })
    end

    table.insert(extmarks, {
      start_line = entry.from.line,
      start_col = entry.from.start_col,
      end_col = link_opts.end_col,
      ephemeral = link_opts.ephemeral,
      hl_group = link_opts.hl_group,
      priority = link_opts.priority,
      url = link_opts.url,
    })
    ::continue::
  end

  return extmarks
end

return OrgLink
