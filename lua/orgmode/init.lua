vim.g.orgmode_logs = {}
local Config = require('orgmode.config')
local utils = require('orgmode.utils')
local parser = require('orgmode.parser')
local instance = nil
local Org = {}

function Org:new()
  local data = { agendas = {}, files = {} }
  setmetatable(data, self)
  self.__index = self
  data:setup_autocmds()
  data:load()
  return data
end

function Org:load(file)
  if file then
    local filename = vim.fn.fnamemodify(file, ':t:r')
    return utils.readfile(file, function(err, result)
      if err then return end
      self.agendas[file] = parser.parse(result, filename)
    end)
  end

  self.files = Config:get_agenda_files()
  for _, item in ipairs(self.files) do
    local filename = vim.fn.fnamemodify(item, ':t:r')
    utils.readfile(item, function(err, result)
      if err then return end
      self.agendas[item] = parser.parse(result, filename)
    end)
  end
  return self
end

function Org:reload()
  self.files = {}
  self.agendas = {}
  return self:load()
end

function Org:setup_autocmds()
  vim.cmd[[augroup orgmode_nvim]]
  vim.cmd[[autocmd!]]
  vim.cmd[[autocmd BufWritePost *.org call add(g:orgmode_logs, 'TU SAM')]]
  vim.cmd[[augroup END]]
end

local function setup(opts)
  Config = Config:extend(opts)
  instance = Org:new()
  return instance
end

local function reload(opts)
  if not instance then
    Config = Config:extend(opts)
    instance = Org:new()
  end
  return instance:reload()
end

return {
  setup = setup,
  reload = reload,
}
