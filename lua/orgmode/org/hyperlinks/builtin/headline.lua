local utils = require('orgmode.utils')
local Org = require('orgmode')
local Internal = require('orgmode.org.hyperlinks.builtin.internal')
local Id = require('orgmode.org.hyperlinks.builtin.id')

---@class OrgLinkHeadline:OrgLinkInternal
local Headline = Internal:new()

function Headline:new(headline)
  ---@class OrgLinkHeadline
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

-- TODO Headline completion for non-local file. How to pass other file cleanly?
--     ^ Should this be done in `OrgLinkFile:autocompletions()`?
function Headline:autocompletions(lead)
  local file = Org.files:get_current_file()
  local headlines = file:find_headlines_by_title(lead)

  local completions = {}
  for _, headline in pairs(headlines) do
    local link = Headline:new(headline:get_title())

    local id = headline:get_property('id')
    if id then
      table.insert(completions, { link = Id:new(id), label = link:__tostring(), desc = headline:get_title() })
    else
      table.insert(completions, { link = link, desc = headline:get_title() })
    end
  end

  return completions
end

return Headline
