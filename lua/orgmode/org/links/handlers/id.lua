local utils = require('orgmode.utils')
local Link = require('orgmode.org.links.link_handler')
local Internal = require('orgmode.org.links.handlers.internal')

---@class OrgLinkHandlerId:OrgLinkHandler
local Id = Link:new('id')

function Id:new(id, target, files)
  ---@class OrgLinkHandlerId
  local this = Link:new()
  this.id = id
  this.target = target
  this.files = files
  setmetatable(this, self)
  self.__index = self
  return this
end

function Id:follow()
  local files = self.files:find_files_with_property('id', self.id)
  if #files > 0 then
    if #files > 1 then
      utils.echo_warning(string.format('Multiple files found with id: %s, jumping to first one found', self.id))
    end
    vim.cmd(('edit %s'):format(files[1].filename))
    return
  end

  local headlines = Org.files:find_headlines_with_property('id', self.id)
  if #headlines == 0 then
    return utils.echo_warning(string.format('No id "%s" found.', self.id))
  end
  if #headlines > 1 then
    return utils.echo_warning(
      string.format('Multiple headlines found with id: %s, jumping to first one found', self.id)
    )
  end
  utils.goto_headline(headlines[1])

  if self.target then
    self.target:follow()
  end
end

function Id:__tostring()
  local v = string.format('%s:%s', self.protocol, self.id)

  if self.target then
    v = string.format('%s::%s', v, self.target)
  end

  return v
end

function Id:_autocompletions_ids(lead)
  local headlines = self.files:find_headlines_with_property_matching('id', lead)

  local matches = {}
  for _, headline in ipairs(headlines) do
    local id = headline:get_property('id')
    if id and id:find('^' .. lead) then
      table.insert(matches, id)
    end
  end

  local files = self.files:find_files_with_property_matching('id', lead)
  for _, file in ipairs(files) do
    local id = file:get_property('id')
    if id and id:find('^' .. lead) then
      table.insert(matches, id)
    end
  end

  return matches
end

local IdFactory = {}

function IdFactory:init(files)
  self.files = files
end

function IdFactory:new(id, target)
  return Id:new(id, target, self.files)
end

---@param input string
function IdFactory:parse(input)
  if input == nil or #input == 0 then
    return nil
  end
  local deliniator_start, deliniator_stop = input:find('::')

  ---@type OrgLinkHandlerInternal | nil
  local target = nil
  local path = input

  if not deliniator_start == nil then
    ---@class OrgLinkHandlerInternal | nil
    target = Internal.parse(input:sub(deliniator_stop + 1), true)
    path = input:sub(0, deliniator_start - 1)
  end

  return Id:new(path, target, self.files)
end

function IdFactory:complete(lead)
  local deliniator_start, deliniator_stop = lead:find('::')

  if not deliniator_start then
    return self:_complete(lead)
  else
    local id = lead:sub(0, deliniator_start - 1)
    local target_lead = lead:sub(deliniator_stop + 1)
    return self:_complete_targets(id, target_lead)
  end
end

function IdFactory:_complete(lead)
  return vim.tbl_map(function(f)
    return tostring(self:new(f))
  end, self:_autocompletions_ids(lead))
end

function IdFactory:_complete_targets(id, target_lead)
  return vim.tbl_map(function(t)
    return tostring(self:new(id, t))
  end, Internal:complete(target_lead, { id = id, only_internal = true }))
end

return IdFactory
