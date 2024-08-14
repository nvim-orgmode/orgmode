local utils = require('orgmode.utils')
local Link = require('orgmode.org.links.link_handler')

---@class OrgLinkHandlerHttps:OrgLinkHandler
local Https = Link:new('https')

function Https:new(url)
  ---@class OrgLinkHandlerHttps
  local this = Link:new()
  this.url = url
  setmetatable(this, self)
  self.__index = self
  return this
end

function Https:__tostring()
  return string.format('%s://%s', self.protocol, self.url)
end

function Https:follow()
  if vim.ui['open'] then
    return vim.ui.open(tostring(self))
  end
  if not vim.g.loaded_netrwPlugin then
    return utils.echo_warning('Netrw plugin must be loaded in order to open urls.')
  end
  return vim.fn['netrw#BrowseX'](tostring(self), vim.fn['netrw#CheckIfRemote']())
end

local HttpsFactory = {}

function HttpsFactory:new()
  ---@class OrgLinkHandlerId
  local this = {}
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function HttpsFactory.parse(input)
  return HttpsFactory:new(input:gsub('^/*', ''))
end

return HttpsFactory
