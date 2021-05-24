_G.org = _G.org or {}
local Config = require('orgmode.config')
local Agenda = require('orgmode.agenda')
local Capture = require('orgmode.capture')
local utils = require('orgmode.utils')
local parser = require('orgmode.parser')
local instance = nil
local Org = {}

---@class Org
function Org:new()
  local data = { files = {} }
  setmetatable(data, self)
  self.__index = self
  data:setup_autocmds()
  data:load()
  data.agenda = Agenda:new({ files = data.files, org = data })
  data.capture = Capture:new({ agenda = data.agenda })
  return data
end

---@param file? string
---@return string
function Org:load(file)
  if file then
    local filename = vim.fn.fnamemodify(file, ':t:r')
    return utils.readfile(file, function(err, result)
      if err then return end
      self.files[file] = parser.parse(result, filename)
    end)
  end

  local files = Config:get_all_files()
  for _, item in ipairs(files) do
    local category = vim.fn.fnamemodify(item, ':t:r')
    utils.readfile(item, function(err, result)
      if err then return end
      self.files[item] = parser.parse(result, category, item)
      self.agenda.files[item] = self.files[item]
    end)
  end
  return self
end

---@param file? string
---@return string
function Org:reload(file)
  if not file then
    self.files = {}
  end
  return self:load(file)
end

function Org:setup_autocmds()
  vim.cmd[[augroup orgmode_nvim]]
  vim.cmd[[autocmd!]]
  vim.cmd[[autocmd BufWritePost *.org call luaeval('require("orgmode").reload(_A)', expand('<afile>:p'))]]
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
