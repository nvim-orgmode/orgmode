local Headline = require('orgmode.treesitter.headline')

---@alias VirtualIndentHandler fun(buffer:number, start_line: number, end_line: number) function that sets the indentation

---@class VirtualIndent
---@field private _ns_id number extmarks namespace id
---@field private _handler VirtualIndentHandler? function that sets the indentation
local VirtualIndent = {}

---@class VirtualIndentData
---@field handler VirtualIndentHandler? function that sets the indentation

---@param data VirtualIndentData
function VirtualIndent:new(data)
  data = data or {}

  vim.validate({
    handler = { data.handler, 'function', true },
  })

  local opts = {}
  opts._ns_id = vim.api.nvim_create_namespace('orgmode.ui.indent')
  opts._handler = data.handler

  setmetatable(opts, self)
  self.__index = self
  return opts
end

function VirtualIndent:_delete_old_extmarks(buffer, start_line, end_line)
  local old_extmarks = vim.api.nvim_buf_get_extmarks(
    buffer,
    self._ns_id,
    { start_line, 0 },
    { end_line, 0 },
    { type = 'virt_text' }
  )
  for _, ext in ipairs(old_extmarks) do
    vim.api.nvim_buf_del_extmark(0, self._ns_id, ext[1])
  end
end

function VirtualIndent:_get_indent_size(line)
  local headline = Headline.from_cursor({ line + 1, 1 })

  if headline then
    local level = headline:level()
    local headline_line, _, _ = headline.headline:start()

    if headline_line == line then
      return level - 1
    else
      return level * 2
    end
  end

  return 0
end

---@param buffer number buffer id
---@param start_line number start line number, 0-based inclusive
---@param end_line number end line number, 0-based inclusive
function VirtualIndent:set_indent(buffer, start_line, end_line)
  if self._handler then
    return self._handler(buffer, start_line, end_line)
  end

  self:_delete_old_extmarks(buffer, start_line, end_line)
  for line = start_line, end_line do
    local indent = self:_get_indent_size(line)

    if indent > 0 then
      vim.api.nvim_buf_set_extmark(buffer, self._ns_id, line, 0, {
        virt_text = { { string.rep(' ', indent), 'OrgIndent' } },
        virt_text_pos = 'inline',
        right_gravity = false,
      })
    end
  end
end

---@param buffer number buffer id
function VirtualIndent:attach(buffer)
  vim.validate({
    buffer = { buffer, 'number', true },
  })

  buffer = buffer or 0

  self:set_indent(buffer, 0, vim.api.nvim_buf_line_count(buffer) - 1)

  vim.api.nvim_buf_attach(buffer, true, {
    on_lines = function(_, _, _, start_line, _, end_line)
      vim.schedule(function()
        self:set_indent(buffer, start_line, end_line)
      end)
    end,
  })
end

return VirtualIndent
