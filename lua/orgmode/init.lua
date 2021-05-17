vim.g.orgmode_logs = {}
local Config = require('orgmode.config')
local Agenda = require('orgmode.agenda')
local utils = require('orgmode.utils')
local parser = require('orgmode.parser')
local instance = nil
local Org = {}

function Org:new()
  local data = { files = {} }
  setmetatable(data, self)
  self.__index = self
  data:setup_autocmds()
  data:load()
  data.agenda = Agenda:new({ files = data.files })
  return data
end

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
    local filename = vim.fn.fnamemodify(item, ':t:r')
    utils.readfile(item, function(err, result)
      if err then return end
      self.files[item] = parser.parse(result, filename)
    end)
  end
  return self
end

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

local function setup(opts)
  Config = Config:extend(opts)
  instance = Org:new()
  return instance
end

local function reload(file)
  if not instance then return end
  return instance:reload(file)
end

local function action(cmd)
  if instance and cmd == 'agenda_open' then
    instance.agenda:open()
  end
end

return {
  setup = setup,
  reload = reload,
  action = action,
}
