local fs = require('orgmode.utils.fs')
local Link = require('orgmode.org.links.link_handler')
local Id = require('orgmode.org.links.handlers.id')
local Internal = require('orgmode.org.links.handlers.internal')

---@class OrgLinkHandlerFile:OrgLinkHandler
---@field new fun(self: OrgLinkHandlerFile, path: string, target: OrgLinkHandlerInternal | nil, prefix: boolean | nil, files: OrgFile[]): OrgLinkHandlerFile
---@field parse fun(link: string, prefix: boolean | nil): OrgLinkHandlerFile | nil
---@field path string
---@field skip_prefix boolean
---@field target OrgLinkHandlerInternal | nil
local File = Link:new('file')

function File:new(path, target, skip_prefix, files)
  ---@class OrgLinkHandlerFile
  local this = Link:new()
  this.skip_prefix = skip_prefix or false
  this.path = path
  this.target = target
  this.files = files
  setmetatable(this, self)
  self.__index = self
  return this
end

-- TODO make protocol prefix optional. Based on what?
function File:__tostring()
  local v = ''
  if self.skip_prefix then
    v = ('%s'):format(self.path)
  else
    v = ('%s:%s'):format(self.protocol, self.path)
  end

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

function File:_autocompletions_filenames(lead)
  local filenames = self.files:filenames()

  local matches = {}
  for _, f in ipairs(filenames) do
    local realpath = fs.substitute_path(lead) or lead
    if f:find('^' .. realpath) then
      local path = f:gsub('^' .. realpath, lead)
      table.insert(matches, { real = f, path = path })
    end
  end

  print(vim.inspect(matches))
  return matches
end

function File:insert_description()
  local Org = require('orgmode')
  if self.target then
    return self.target:insert_description()
  end

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

local FileFactory = {}

function FileFactory:init(files)
  self.files = files
end

function FileFactory:new(path, target, skip_prefix)
  return File:new(path, target, skip_prefix, self.files)
end

function FileFactory:parse(input, skip_prefix)
  if input == nil or #input == 0 then
    return nil
  end
  local deliniator_start, deliniator_stop = input:find('::')

  ---@type OrgLinkHandlerInternal | nil
  local target = nil
  local path = input

  if deliniator_start then
    ---@class OrgLinkHandlerInternal | nil
    target = Internal.parse(input:sub(deliniator_stop + 1), true)
    path = input:sub(0, deliniator_start - 1)
  end

  self:new(path, target, skip_prefix)
end

function FileFactory:complete(lead, context)
  context = context or {}
  local deliniator_start, deliniator_stop = lead:find('::')

  if not deliniator_start then
    return self:_complete(lead, context)
  else
    local path = lead:sub(0, deliniator_start - 1)
    local target_lead = lead:sub(deliniator_stop + 1)
    return self:_complete_targets(path, target_lead, context)
  end
end

function FileFactory:_complete(lead, context)
  return vim.tbl_map(function(f)
    return tostring(self:new(f, nil, context.skip_prefix))
  end, self:_autocompletions_filenames(lead))
end

function FileFactory:_complete_targets(path, target_lead, context)
  return vim.tbl_map(
    function(t)
      return tostring(self:new(path, t, context.skip_prefix))
    end,
    Internal:complete(target_lead, {
      filename = fs.get_real_path(path),
      only_internal = true,
    })
  )
end

return FileFactory
