local Org = require('orgmode')
local fs = require('orgmode.utils.fs')
local Link = require('orgmode.org.hyperlinks.link')
local Internal = require('orgmode.org.hyperlinks.builtin.internal')
local Id = require('orgmode.org.hyperlinks.builtin.id')

---@class OrgLinkFile:OrgLink
---@field new fun(self: OrgLinkFile, path: string, target: OrgLinkInternal | nil): OrgLinkFile
---@field parse fun(link: string): OrgLinkFile | nil
---@field path string
---@field target OrgLinkInternal | nil
local File = Link:new('file')

function File:new(path, target)
  ---@class OrgLinkFile
  local this = Link:new()
  this.path = path
  this.target = target
  setmetatable(this, self)
  self.__index = self
  return this
end

function File.parse(input)
  if input == nil or #input == 0 then
    return nil
  end
  local deliniator_start, deliniator_stop = input:find('::')

  ---@type OrgLinkInternal | nil
  local target = nil
  local path = input

  if deliniator_start then
    ---@class OrgLinkInternal | nil
    target = Internal.parse(input:sub(deliniator_stop + 1), true)
    path = input:sub(0, deliniator_start - 1)
  end

  return File:new(path, target)
end

-- TODO make protocol prefix optional. Based on what?
function File:__tostring()
  local v = string.format('%s:%s', self.protocol, self.path)

  if self.target then
    v = string.format('%s::%s', v, self.target)
  end

  return v
end

function File:follow()
  vim.cmd('edit ' .. fs.get_real_path(self.path))

  if self.target then
    self.target:follow()
  end
end

local function autocompletions_filenames(lead)
  local filenames = Org.files:filenames()

  local matches = {}
  for _, f in ipairs(filenames) do
    local realpath = fs.get_real_path(lead) or lead
    if f:find('^' .. realpath) then
      local path = f:gsub('^' .. realpath, lead)
      table.insert(matches, path)
    end
  end

  return matches
end

function File:resolve()
  local path = fs.get_real_path(self.path)
  if not path then
    return self
  end
  local file = Org.files:get(path)
  if not file then
    return self
  end
  local id = file:get_property('id')
  if not id then
    return self
  end

  return Id:new(id, self.target):resolve()
end

function File:insert_description()
  local path = fs.get_real_path(self.path)
  if not path then
    return nil
  end
  local file = Org.files:get(path)
  if not file then
    return nil
  end

  return file:get_title()
end

-- TODO Completion for targets
function File:complete(lead)
  local deliniator_start, deliniator_stop = lead:find('::')

  if not deliniator_start then
    return vim.tbl_map(function(f)
      return self:new(f)
    end, autocompletions_filenames(lead))
  end

  return {}
end

return File
