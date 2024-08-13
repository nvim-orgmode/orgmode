local utils = require('orgmode.utils')
local Org = require('orgmode')
local Internal = require('orgmode.org.hyperlinks.builtin.internal')
local Id = require('orgmode.org.hyperlinks.builtin.id')

---@class OrgLinkHandlerHeadline:OrgLinkHandlerInternal
local Headline = Internal:new()

function Headline:new(headline)
  ---@class OrgLinkHandlerHeadline
  local this = Internal:new()
  this.headline = headline
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function Headline.parse(input)
  return Headline:new(input)
end

function Headline:__tostring()
  return string.format('*%s', self.headline)
end

function Headline:follow()
  local headlines = Org.files:get_current_file():find_headlines_by_title(self.headline)

  if #headlines == 0 then
    return utils.echo_warning(('Could not find headline "%s".'):format(self.headline))
  end

  self.goto_oneof(headlines)
end

function Headline:resolve()
  local headlines = Org.files:get_current_file():find_headlines_by_title(self.headline)

  if #headlines == 0 then
    return self
  end

  local id = headlines[1]:get_property('id')
  if not id then
    return self
  end

  return Id:new(id):resolve()
end

function Headline:insert_description()
  return self.headline
end

function Headline:complete(lead, context)
  local file = self.get_file_from_context(context)
  local headlines = file:find_headlines_by_title(lead)

  local completions = {}
  for _, headline in pairs(headlines) do
    table.insert(completions, Headline:new(headline:get_title()):__tostring())
  end

  return completions
end

return Headline
