local utils = require('orgmode.utils')
local Link = require('orgmode.org.hyperlinks.link')

---@class OrgLinkHttp:OrgLink
local Http = Link:new('http')

function Http:new(url)
  ---@class OrgLinkHttp
  local this = Link:new()
  this.url = url
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function Http.parse(input)
  return Http:new(input:gsub('^/*', ''))
end

function Http:__tostring()
  return string.format('%s://%s', self.protocol, self.url)
end

function Http:follow()
  if vim.ui['open'] then
    return vim.ui.open(self:__tostring())
  end
  if not vim.g.loaded_netrwPlugin then
    return utils.echo_warning('Netrw plugin must be loaded in order to open urls.')
  end
  return vim.fn['netrw#BrowseX'](self:__tostring(), vim.fn['netrw#CheckIfRemote']())
end

return Http
