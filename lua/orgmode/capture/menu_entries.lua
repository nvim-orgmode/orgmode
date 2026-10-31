local config = require('orgmode.config')
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
      elseif vim.tbl_count(template.subtemplates or {}) > 0 then
        table.insert(entries, { key = key, label = template.description, subtemplates = template.subtemplates })
      else
        table.insert(entries, { key = key, label = template.description, template = template })
      end
    end
  end
  return entries
end

--- Template reached by typing keys in the menu and its submenus
---@param templates table<string, OrgCaptureTemplate>
---@param keys string
---@return OrgCaptureTemplate?
function MenuEntries.find(templates, keys)
  local key, rest = keys:sub(1, 1), keys:sub(2)
  for _, entry in ipairs(MenuEntries.entries(templates)) do
    if entry.key == key then
      if rest == '' then
        return entry.template
      end
      return entry.subtemplates and MenuEntries.find(entry.subtemplates, rest)
    end
  end
end

--- Capture templates of the menu and its submenus, with the keys of each level joined.
--- Groups get a label without an action.
---@return OrgMenuKeymap[]
function MenuEntries.keymaps()
  local keymaps = {}
  ---@param templates table<string, OrgCaptureTemplate>
  ---@param prefix string
  local function collect(templates, prefix)
    for _, entry in ipairs(MenuEntries.entries(templates)) do
      local keys = prefix .. entry.key
      if entry.subtemplates then
        table.insert(keymaps, { key = keys, desc = entry.label })
        collect(entry.subtemplates, keys)
      else
        table.insert(keymaps, {
          key = keys,
          desc = entry.label,
          action = function()
            local capture = require('orgmode').capture
            local template = MenuEntries.find(capture.templates:get_list(), keys)
            if not template then
              return utils.echo_error('No capture template with keys ' .. keys)
            end
            return capture:open_template(template)
          end,
        })
      end
    end
  end
  -- Only keys and labels are read, which the config entries share with OrgCaptureTemplate
  collect(config.org_capture_templates --[[@as table<string, OrgCaptureTemplate>]], '')
  return keymaps
end

return MenuEntries
