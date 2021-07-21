_G.orgmode = _G.orgmode or {}
local instance = nil

---@class Org
---@field initialized boolean
---@field files Files
---@field agenda Agenda
---@field capture Capture
---@field notifications Notifications
local Org = {}

function Org:new()
  local data = { initialized = false }
  setmetatable(data, self)
  self.__index = self
  data:setup_autocmds()
  return data
end

function Org:init()
  if self.initialized then
    return
  end
  self.files = require('orgmode.parser.files').new()
  self.agenda = require('orgmode.agenda'):new()
  self.capture = require('orgmode.capture'):new()
  self.org_mappings = require('orgmode.org.mappings'):new({
    capture = self.capture,
    agenda = self.agenda,
  })
  require('orgmode.colors.todo_highlighter').add_todo_keyword_highlights()
  require('orgmode.org.autocompletion').register()
  self.initialized = true
end

---@param file? string
---@return string
function Org:reload(file)
  self:init()
  return self.files.reload(file)
end

function Org:setup_autocmds()
  vim.cmd([[augroup orgmode_nvim]])
  vim.cmd([[autocmd!]])
  vim.cmd([[autocmd BufWritePost *.org call luaeval('require("orgmode").reload(_A)', expand('<afile>:p'))]])
  vim.cmd([[autocmd FileType org call luaeval('require("orgmode").reload(_A)', expand('<afile>:p'))]])
  vim.cmd([[augroup END]])
end

---@param opts? table
---@return Org
local function setup(opts)
  instance = Org:new()
  local config = require('orgmode.config'):extend(opts)
  vim.defer_fn(function()
    if config.notifications.enabled and #vim.api.nvim_list_uis() > 0 then
      require('orgmode.parser.files').load(vim.schedule_wrap(function()
        instance.notifications = require('orgmode.notifications'):new():start_timer()
      end))
    end
    config:setup_mappings()
  end, 1)
  return instance
end

---@param file? string
---@return Org
local function reload(file)
  if not instance then
    return
  end
  return instance:reload(file)
end

---@param opts table
local function action(cmd, opts)
  local parts = vim.split(cmd, '.', true)
  if not instance or #parts < 2 then
    return
  end
  instance:init()
  if instance[parts[1]] and instance[parts[1]][parts[2]] then
    local item = instance[parts[1]]
    local method = item[parts[2]]
    return method(item, opts)
  end
end

local function cron(opts)
  local config = require('orgmode.config'):extend(opts or {})
  if not config.notifications.cron_enabled then
    return vim.cmd([[qa!]])
  end
  require('orgmode.parser.files').load(vim.schedule_wrap(function()
    instance.notifications = require('orgmode.notifications'):new():cron()
  end))
end

return {
  setup = setup,
  reload = reload,
  action = action,
  cron = cron,
}
