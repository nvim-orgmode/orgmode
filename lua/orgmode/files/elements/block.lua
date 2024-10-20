local utils = require('orgmode.utils')
local fs = require('orgmode.utils.fs')
local config = require('orgmode.config')

---@class OrgBlockTangleInfo
---@field name? string
---@field header_args table<string, string>
---@field filename? string
---@field tangle? boolean
---@field content string[]

---@class OrgBlock
---@field node TSNode
---@field file OrgFile
local Block = {}
Block.__index = Block

---@param node TSNode
---@param file OrgFile
---@return OrgBlock
function Block:new(node, file)
  return setmetatable({
    node = node,
    file = file,
  }, self)
end

function Block:is_src_block()
  return self:get_type() == 'src'
end

function Block:get_content()
  local node = self.node:field('contents')[1]
  if not node then
    return {}
  end
  -- If first line is indented, node range does not
  -- take that indentation into account,
  -- so we have to adjust the start column manually
  local range = { node:range() }
  local _, start_col = self.node:start()
  range[2] = start_col
  return self.file:get_node_text_list(node, range)
end

---@return OrgBlockTangleInfo
function Block:get_tangle_info()
  local header_args = self:get_header_args()
  local tangle = header_args[':tangle']
  local content = self:get_content()
  local language = self:get_language()
  local result = {
    header_args = header_args,
    content = content,
    tangle = tangle and tangle ~= 'no' or false,
    name = self:get_name(),
  }

  if tangle == 'yes' then
    local filename = vim.fn.fnamemodify(self.file.filename, ':p:r')
    result.filename = filename .. (language and '.' .. language or '')
  elseif result.tangle then
    local tangle_path = fs.substitute_path(tangle)
    if not tangle_path then
      tangle_path = fs.substitute_path('./' .. tangle)
    end
    assert(tangle_path)
    result.filename = tangle_path
  end

  return result
end

function Block:get_language()
  local language = self.file:get_node_text(self.node:field('parameter')[1])
  if not language or language == '' then
    return nil
  end
  return utils.detect_filetype(language)
end

---@return table<string, string>
function Block:get_header_args()
  local file_header_args = self.file:get_header_args()
  local headline_args = {}
  local headline = self:_get_headline()
  if headline then
    local headline_prop = headline:get_property('header-args', true)
    if headline_prop then
      headline_args = config:parse_header_args(headline_prop)
    end
  end
  local own_args_str = table.concat(
    vim.tbl_map(function(param)
      return self.file:get_node_text(param)
    end, self.node:field('parameter')),
    ' '
  )
  local own_args = config:parse_header_args(own_args_str)
  return vim.tbl_extend('force', file_header_args, headline_args, own_args)
end

---@private
---@return OrgHeadline | nil
function Block:_get_headline()
  local start_line = self.node:start()
  return self.file:get_closest_headline_or_nil({ start_line + 1, 0 })
end

---Get name from the block directive
---@return string | nil
function Block:get_name()
  local directives = self.node:field('directive')
  if not directives or #directives == 0 then
    return nil
  end

  for _, directive in ipairs(directives) do
    local name = directive:field('name')[1]
    local value = directive:field('value')[1]

    if name and value then
      local name_text = self.file:get_node_text(name)
      if name_text:lower() == 'name' then
        return self.file:get_node_text(value)
      end
    end
  end

  return nil
end

---Get block type (src, example, etc)
---@return string | nil
function Block:get_type()
  local name_node = self.node:field('name')[1]
  if name_node then
    return self.file:get_node_text(name_node):lower()
  end
  return nil
end

return Block
