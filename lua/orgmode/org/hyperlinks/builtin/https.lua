local utils = require('orgmode.utils')
local Link = require('orgmode.org.hyperlinks.link')

---@class OrgLinkHttps:OrgLink
local Https = Link:new('https')

function Https:new(url)
  ---@class OrgLinkHttps
  local this = Link:new()
  this.url = url
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function Https.parse(input)
  return Https:new(input:gsub('^/*', ''))
end

function Https:__tostring()
  return string.format('%s://%s', self.protocol, self.url)
end

function Https:follow()
  if vim.ui['open'] then
    return vim.ui.open(self:__tostring())
  end
  if not vim.g.loaded_netrwPlugin then
    return utils.echo_warning('Netrw plugin must be loaded in order to open urls.')
  end
  return vim.fn['netrw#BrowseX'](self:__tostring(), vim.fn['netrw#CheckIfRemote']())
end

return Https
