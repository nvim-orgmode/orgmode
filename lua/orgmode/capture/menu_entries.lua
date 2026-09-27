local utils = require('orgmode.utils')

---@class OrgCaptureMenuEntry
---@field key string
---@field label string
---@field template? OrgCaptureTemplate Set for a template that opens directly
---@field subtemplates? table<string, OrgCaptureTemplate> Set for a group, the templates of the next menu level

local MenuEntries = {}

--- Templates whose key starts with base_key, keyed by the rest of their key
---@param base_key string
---@param templates table<string, OrgCaptureTemplate>
---@return table<string, OrgCaptureTemplate>
function MenuEntries.subtemplates(base_key, templates)
  local subtemplates = {}
  for key, template in utils.sorted_pairs(templates) do
    if string.len(key) > 1 and string.sub(key, 1, 1) == base_key then
      subtemplates[string.sub(key, 2, string.len(key))] = template
    end
  end
  return subtemplates
end

--- Entries of one menu level, one per single-key template or group
---@param templates table<string, OrgCaptureTemplate>
---@return OrgCaptureMenuEntry[]
function MenuEntries.entries(templates)
  local entries = {}
  for key, template in utils.sorted_pairs(templates) do
    if string.len(key) == 1 then
      if type(template) == 'string' then
        table.insert(entries, { key = key, label = template, subtemplates = MenuEntries.subtemplates(key, templates) })
      elseif vim.tbl_count(template.subtemplates) > 0 then
        table.insert(entries, { key = key, label = template.description, subtemplates = template.subtemplates })
      else
        table.insert(entries, { key = key, label = template.description, template = template })
      end
    end
  end
  return entries
end

return MenuEntries
