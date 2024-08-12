local Org = require('orgmode')
local Internal = require('orgmode.org.hyperlinks.builtin.internal')

---@class OrgLinkCustomId:OrgLinkInternal
local CustomId = Internal:new()

function CustomId:new(custom_id)
  ---@class OrgLinkCustomId
  local this = Internal:new()
  this.custom_id = custom_id
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function CustomId.parse(input)
  return CustomId:new(input)
end

function CustomId:__tostring()
  return '#' .. self.custom_id
end

function CustomId:follow()
  local headlines = Org.files:get_current_file():find_headlines_with_property_matching('custom_id', self.custom_id)

  if #headlines == 0 then
    return utils.echo_warning(('Could not find custom ID "%s".'):format(self.custom_id))
  end

  self.goto_oneof(headlines)
end

function CustomId:insert_description()
  return self.custom_id
end

-- TODO Custom ID completion for non-local file. How to pass other file cleanly?
--     ^ Should this be done in `OrgLinkFile:autocompletions()`?
function CustomId:complete(lead)
  local file = Org.files:get_current_file()
  local headlines = file:find_headlines_with_property_matching('CUSTOM_ID', lead)

  local completions = {}
  for _, headline in pairs(headlines) do
    local id = headline:get_property('CUSTOM_ID')
    table.insert(completions, self:new(id))
  end

  return completions
end

return CustomId
