---@class OrgDatesHighlighter : OrgMarkupHighlighter
---@field private markup OrgMarkupHighlighter
local OrgDates = {
  valid_capture_names = {
    ['date_active.start'] = true,
    ['date_active.end'] = true,
    ['date_inactive.start'] = true,
    ['date_inactive.end'] = true,
  },
}

---@param opts { markup: OrgMarkupHighlighter }
function OrgDates:new(opts)
  local data = {
    markup = opts.markup,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param node TSNode
---@param name string
---@return OrgMarkupNode | false
function OrgDates:parse_node(node, name)
  if not self.valid_capture_names[name] then
    return false
  end
  local type = node:type()
  if type == '[' or type == '<' then
    return self:_parse_start_node(node)
  end

  if type == ']' or type == '>' then
    return self:_parse_end_node(node)
  end

  return false
end

---@private
---@param node TSNode
---@return OrgMarkupNode | false
function OrgDates:_parse_start_node(node)
  local node_type = node:type()
  local prev_sibling = node:prev_sibling()
  -- Ignore links
  if prev_sibling and (node_type == '[' and prev_sibling:type() == '[') then
    return false
  end
  local expected_next_siblings = {
    {
      type = 'num',
      length = 4,
    },
    {
      type = '-',
      length = 1,
    },
    {
      type = 'num',
      length = 2,
    },
    {
      type = '-',
      length = 1,
    },
    {
      type = 'num',
      length = 2,
    },
  }
  local next_sibling = node:next_sibling()

  for _, sibling in ipairs(expected_next_siblings) do
    if not next_sibling or next_sibling:type() ~= sibling.type then
      return false
    end
    local _, sc, _, ec = next_sibling:range()
    if (ec - sc) ~= sibling.length then
      return false
    end
    next_sibling = next_sibling:next_sibling()
  end
  local id = table.concat({ 'date', node_type }, '_')
  local seek_id = table.concat({ 'date', node_type == '[' and ']' or '>' }, '_')

  return {
    type = 'date',
    id = id,
    char = node_type,
    seek_id = seek_id,
    nestable = false,
    range = self.markup:node_to_range(node),
    node = node,
  }
end

---@private
---@param node TSNode
---@return OrgMarkupNode | false
function OrgDates:_parse_end_node(node)
  local node_type = node:type()
  local prev_sibling = node:prev_sibling()
  local next_sibling = node:next_sibling()
  local is_prev_sibling_valid = not prev_sibling or prev_sibling:type() == 'str' or prev_sibling:type() == 'num'
  -- Ensure it's not a link or a link alias
  local is_next_sibling_valid = not next_sibling
    or (node_type == ']' and next_sibling:type() ~= ']' and next_sibling:type() ~= '[')
  if is_prev_sibling_valid and is_next_sibling_valid then
    local id = table.concat({ 'date', node_type }, '_')
    local seek_id = table.concat({ 'date', node_type == ']' and '[' or '<' }, '_')

    return {
      type = 'date',
      id = id,
      seek_id = seek_id,
      char = node_type,
      nestable = false,
      range = self.markup:node_to_range(node),
      node = node,
    }
  end

  return false
end

---@param entry OrgMarkupNode
---@return boolean
function OrgDates:is_valid_start_node(entry)
  return entry.type == 'date' and (entry.id == 'date_[' or entry.id == 'date_<')
end

---@param entry OrgMarkupNode
---@return boolean
function OrgDates:is_valid_end_node(entry)
  return entry.type == 'date' and (entry.id == 'date_]' or entry.id == 'date_>')
end

---@param highlights OrgMarkupHighlight[]
---@param bufnr number
function OrgDates:highlight(highlights, bufnr)
  local namespace = self.markup.highlighter.namespace
  local ephemeral = self.markup:use_ephemeral()

  for _, entry in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      hl_group = entry.char == '>' and '@org.timestamp.active' or '@org.timestamp.inactive',
      priority = 110,
    })
  end
end

---@param highlights OrgMarkupHighlight[]
---@return OrgMarkupPreparedHighlight[]
function OrgDates:prepare_highlights(highlights)
  local ephemeral = self.markup:use_ephemeral()
  local extmarks = {}
  for _, entry in ipairs(highlights) do
    table.insert(extmarks, {
      start_line = entry.from.line,
      start_col = entry.from.start_col,
      end_col = entry.to.end_col,
      ephemeral = ephemeral,
      hl_group = entry.char == '>' and '@org.timestamp.active' or '@org.timestamp.inactive',
      priority = 110,
    })
  end
  return extmarks
end

return OrgDates
