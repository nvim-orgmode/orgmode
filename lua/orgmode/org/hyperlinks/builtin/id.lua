local Org = require('orgmode')
local utils = require('orgmode.utils')
local Link = require('orgmode.org.hyperlinks.link')
local Internal = require('orgmode.org.hyperlinks.builtin.internal')

---@class OrgLinkId:OrgLink
local Id = Link:new('id')

function Id:new(id, target)
  ---@class OrgLinkId
  local this = Link:new()
  this.id = id
  this.target = target
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function Id.parse(input)
  if input == nil or #input == 0 then
    return nil
  end
  local deliniator_start, deliniator_stop = input:find('::')

  ---@type OrgLinkInternal | nil
  local target = nil
  local path = input

  if not deliniator_start == nil then
    ---@class OrgLinkInternal | nil
    target = Internal.parse(input:sub(deliniator_stop + 1), true)
    path = input:sub(0, deliniator_start - 1)
  end

  return Id:new(path, target)
end

function Id:follow()
  local files = Org.files:find_files_with_property('id', self.id)
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

-- TODO Completion for targets
function Id:complete(lead)
  local headlines = Org.files:find_headlines_with_property_matching('id', lead)

  local completions = {}
  for _, headline in ipairs(headlines) do
    local id = headline:get_property('id')
    if id and id:find('^' .. lead) then
      table.insert(completions, self:new(id))
    end
  end

  local files = Org.files:find_files_with_property_matching('id', lead)
  for _, file in ipairs(files) do
    local id = file:get_property('id')
    if id and id:find('^' .. lead) then
      table.insert(completions, self:new(id))
    end
  end

  return completions
end

return Id
