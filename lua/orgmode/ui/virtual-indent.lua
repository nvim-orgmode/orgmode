local Headline = require('orgmode.treesitter.headline')

local VirtualIndent = {}

function VirtualIndent:new(data)
  data = data or {}

  local default_name = 'orgmode.ui.indent'

  local opts = {}
  opts.ns_id = vim.api.nvim_create_namespace(data.namespace or default_name)
  opts.augroup = vim.api.nvim_create_augroup(data.augroup_name or default_name, {})

  setmetatable(opts, self)
  self.__index = self
  return opts
end

function VirtualIndent:_delete_old_extmarks(start_line, end_line)
  local old_extmarks = vim.api.nvim_buf_get_extmarks(
    0,
    self.ns_id,
    { start_line, 0 },
    { end_line, 0 },
    { type = 'virt_text' }
  )
  for _, ext in ipairs(old_extmarks) do
    vim.api.nvim_buf_del_extmark(0, self.ns_id, ext[1])
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

function VirtualIndent:set_indent(start_line, end_line)
  end_line = math.min(end_line, vim.fn.line('$') - 1)

  self:_delete_old_extmarks(start_line, end_line)

  for line = start_line, end_line do
    local indent = self:_get_indent_size(line)

    if indent and indent > 0 then
      vim.api.nvim_buf_set_extmark(0, self.ns_id, line, 0, {
        virt_text = { { string.rep(' ', indent) } },
        virt_text_pos = 'inline',
        right_gravity = false,
      })
    end
  end
end

function VirtualIndent:attach()
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
    pattern = { '*.org' },
    group = self.augroup,
    callback = function()
      self:set_indent(0, vim.fn.line('$') - 1)

      vim.api.nvim_buf_attach(0, true, {
        on_lines = function(_, _, _, start_line, old_last_line, new_last_line)
          vim.schedule(function()
            self:set_indent(start_line, math.max(old_last_line, new_last_line))
          end)
        end,
      })
    end,
  })
end

return VirtualIndent
