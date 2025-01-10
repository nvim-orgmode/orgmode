---@class OrgAgendaLineTokenOpts
---@field content string
---@field range? OrgRange
---@field virt_text_pos? string
---@field hl_group? string
---@field trim_for_hl? boolean

---@class OrgAgendaLineToken: OrgAgendaLineTokenOpts
local OrgAgendaLineToken = {}
OrgAgendaLineToken.__index = OrgAgendaLineToken

---@param opts OrgAgendaLineTokenOpts
---@return OrgAgendaLineToken
function OrgAgendaLineToken:new(opts)
  local data = {
    content = opts.content,
    range = opts.range,
    hl_group = opts.hl_group,
    virt_text_pos = opts.virt_text_pos,
    trim_for_hl = opts.trim_for_hl,
  }
  return setmetatable(data, OrgAgendaLineToken)
end

function OrgAgendaLineToken:get_highlights()
  if not self.hl_group or self.virt_text_pos then
    return nil
  end
  local range = self.range
  if self.trim_for_hl then
    range = self.range:clone()
    local start_offset = self.content:match('^%s*')
    local end_offset = self.content:match('%s*$')
    range.start_col = range.start_col + (start_offset and #start_offset or 0)
    range.end_col = range.end_col - (end_offset and #end_offset or 0)
  end

  return {
    hlgroup = self.hl_group,
    range = range,
  }
end

return OrgAgendaLineToken
