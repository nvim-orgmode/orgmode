local colors = require('orgmode.colors')

---@class OrgAgendaView
---@field bufnr number
---@field highlighter OrgHighlighter
---@field start_line number
---@field line_counter number
---@field lines OrgAgendaLine[]
local OrgAgendaView = {}
OrgAgendaView.__index = OrgAgendaView

---@param opts { bufnr: number, highlighter: OrgHighlighter }
---@return OrgAgendaView
function OrgAgendaView:new(opts)
  local line_nr = vim.api.nvim_buf_line_count(opts.bufnr)
  -- Increase the line if the view is not the first one
  -- Since nvim_buf_set_lines overrides line from the previous view
  if line_nr > 1 then
    line_nr = line_nr + 1
  end
  return setmetatable({
    bufnr = opts.bufnr,
    highlighter = opts.highlighter,
    start_line = line_nr,
    end_line = line_nr,
    lines = {},
  }, OrgAgendaView)
end

---@param line OrgAgendaLine
function OrgAgendaView:add_line(line)
  line.line_nr = self.end_line
  line.view = self
  line.highlighter = self.highlighter
  table.insert(self.lines, line)
  self.end_line = self.end_line + 1
end

---@param line_nr? number
---@return boolean
function OrgAgendaView:is_in_range(line_nr)
  line_nr = line_nr or vim.fn.line('.')
  return line_nr >= self.start_line and line_nr <= self.end_line
end

---@param old_line OrgAgendaLine
---@param new_line OrgAgendaLine
function OrgAgendaView:replace_line(old_line, new_line)
  new_line.line_nr = old_line.line_nr
  new_line.view = self
  new_line.highlighter = self.highlighter
  for i, line in ipairs(self.lines) do
    if line.line_nr == old_line.line_nr then
      self.lines[i] = new_line
      new_line:render()
      return
    end
  end
end

function OrgAgendaView:render()
  local lines = {}
  local highlights = {}
  local virt_texts = {}
  for _, line in ipairs(self.lines) do
    local compiled = line:compile()
    table.insert(lines, compiled.content)
    vim.list_extend(highlights, compiled.highlights)
    vim.list_extend(virt_texts, compiled.virt_texts)
  end
  vim.api.nvim_buf_set_lines(self.bufnr, self.start_line - 1, self.end_line - 1, false, lines)
  colors.apply_highlights(highlights, false, self.bufnr)
  colors.virtual_text(virt_texts, self.bufnr)

  return self
end

return OrgAgendaView
