local Range = require('orgmode.files.elements.range')
---@class OrgAgendaLineTokenOpts
---@field content string
---@field highlighter? OrgHighlighter
---@field range? OrgRange
---@field virt_text_pos? string
---@field hl_group? string
---@field trim_for_hl? boolean
---@field add_markup_to_headline? OrgHeadline

---@class OrgAgendaLineToken: OrgAgendaLineTokenOpts
local OrgAgendaLineToken = {}
OrgAgendaLineToken.__index = OrgAgendaLineToken

---@param opts OrgAgendaLineTokenOpts
---@return OrgAgendaLineToken
function OrgAgendaLineToken:new(opts)
  local data = {
    content = opts.content,
    range = opts.range,
    highlighter = opts.highlighter,
    hl_group = opts.hl_group,
    virt_text_pos = opts.virt_text_pos,
    trim_for_hl = opts.trim_for_hl,
    add_markup_to_headline = opts.add_markup_to_headline,
  }
  return setmetatable(data, OrgAgendaLineToken)
end

function OrgAgendaLineToken:get_highlights()
  local highlights = {}
  if self.hl_group and not self.virt_text_pos then
    local range = self.range
    if self.trim_for_hl then
      range = self.range:clone()
      local start_offset = self.content:match('^%s*')
      local end_offset = self.content:match('%s*$')
      range.start_col = range.start_col + (start_offset and #start_offset or 0)
      range.end_col = range.end_col - (end_offset and #end_offset or 0)
    end

    table.insert(highlights, {
      hlgroup = self.hl_group,
      range = range,
    })
  end

  if self.add_markup_to_headline and self.highlighter then
    local markup_highlights = self.highlighter.markup:get_prepared_headline_highlights(self.add_markup_to_headline)
    local _, offset = self.add_markup_to_headline:get_title()

    for _, hl in ipairs(markup_highlights) do
      table.insert(highlights, {
        hlgroup = hl.hl_group,
        extmark = true,
        range = Range:new({
          start_line = self.range.start_line,
          end_line = self.range.end_line,
          start_col = self.range.start_col + hl.start_col - offset,
          end_col = self.range.start_col + hl.end_col - offset,
        }),
        priority = hl.priority,
        conceal = hl.conceal,
        spell = hl.spell,
        url = hl.url,
      })
    end
  end
  return highlights
end

return OrgAgendaLineToken
