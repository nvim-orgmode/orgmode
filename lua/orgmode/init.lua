_G.org = _G.org or {}
local Config = require('orgmode.config')
local Agenda = require('orgmode.agenda')
local Capture = require('orgmode.capture')
local OrgMappings = require('orgmode.org.mappings')
local OrgFiles = require('orgmode.parser.files')
local instance = nil

---@class Org
---@field initialized boolean
---@field files OrgFiles
---@field agenda Agenda
---@field capture Capture
local Org = {}

function Org:new()
  local data = { initialized = false }
  setmetatable(data, self)
  self.__index = self
  data:setup_autocmds()
  return data
end

function Org:init()
  if self.initialized then return end
  self.files = OrgFiles.new()
  self.agenda = Agenda:new()
  self.capture = Capture:new()
  self.org_mappings = OrgMappings:new()
  self.initialized = true
end

---@param file? string
---@return string
function Org:reload(file)
  self:init()
  return self.files.reload(file)
end

function Org:setup_autocmds()
  vim.cmd[[augroup orgmode_nvim]]
  vim.cmd[[autocmd!]]
  vim.cmd[[autocmd BufWritePost *.org call luaeval('require("orgmode").reload(_A)', expand('<afile>:p'))]]
  vim.cmd[[autocmd FileType org call luaeval('require("orgmode").reload(_A)', expand('<afile>:p'))]]
  vim.cmd[[augroup END]]
end

---@param opts? table
---@return Org
local function setup(opts)
  Config = Config:extend(opts)
  instance = Org:new()
  Config:setup_mappings()
  return instance
end

---@param file? string
---@return Org
local function reload(file)
  if not instance then return end
  return instance:reload(file)
end

---@param opts table
local function action(cmd, opts)
  local parts = vim.split(cmd, '.', true)
  if not instance or #parts < 2 then return end
  instance:init()
  if instance[parts[1]] and instance[parts[1]][parts[2]] then
    local item = instance[parts[1]]
    local method = item[parts[2]]
    return method(item, opts)
  end
end

return {
  setup = setup,
  reload = reload,
  action = action,
}
