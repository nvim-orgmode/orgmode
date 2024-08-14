local utils = require('orgmode.utils')
local Link = require('orgmode.org.links.link_handler')

---@class OrgLinkHandlerHttp:OrgLinkHandler
local Http = Link:new('http')

function Http:new(url)
  ---@class OrgLinkHandlerHttp
  local this = Link:new()
  this.url = url
  setmetatable(this, self)
  self.__index = self
  return this
end

function Http:__tostring()
  return string.format('%s://%s', self.protocol, self.url)
end

function Http:follow()
  if vim.ui['open'] then
    return vim.ui.open(tostring(self))
  end
  if not vim.g.loaded_netrwPlugin then
    return utils.echo_warning('Netrw plugin must be loaded in order to open urls.')
  end
  return vim.fn['netrw#BrowseX'](tostring(self), vim.fn['netrw#CheckIfRemote']())
end

local HttpFactory = {}

function HttpFactory:new()
  ---@class OrgLinkHandlerId
  local this = {}
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function HttpFactory.parse(input)
  return HttpFactory:new(input:gsub('^/*', ''))
end

return Http
