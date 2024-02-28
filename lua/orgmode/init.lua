_G.orgmode = _G.orgmode or {}
local ts_revision = 'f8c6b1e72f82f17e41004e04e15f62a83ecc27b0'
local setup_ts_grammar_used = false
---@type Org | nil
local instance = nil

local auto_instance_keys = {
  files = true,
  agenda = true,
  capture = true,
  clock = true,
  org_mappings = true,
  notifications = true,
  completion = true,
}

---@class Org
---@field initialized boolean
---@field files OrgFiles
---@field highlighter OrgHighlighter
---@field agenda OrgAgenda
---@field capture OrgCapture
---@field clock OrgClock
---@field completion OrgCompletion
---@field org_mappings OrgMappings
---@field notifications OrgNotifications
local Org = {}
setmetatable(Org, {
  __index = function(tbl, key)
    if auto_instance_keys[key] then
      Org.instance()
    end
    return rawget(tbl, key)
  end,
})

function Org:new()
  self.initialized = false
  self:setup_autocmds()
  require('orgmode.config'):setup_ts_predicates()
  return self
end

function Org:init()
  if self.initialized then
    return
  end
  require('orgmode.events').init()
  self.highlighter = require('orgmode.colors.highlighter'):new()
  require('orgmode.colors.highlights').define_highlights()
  self.files = require('orgmode.files'):new({
    paths = require('orgmode.config').org_agenda_files,
  })
  self.agenda = require('orgmode.agenda'):new({
    files = self.files,
  })
  self.capture = require('orgmode.capture'):new({
    files = self.files,
  })
  self.org_mappings = require('orgmode.org.mappings'):new({
    capture = self.capture,
    agenda = self.agenda,
    files = self.files,
  })
  self.clock = require('orgmode.clock'):new({
    files = self.files,
  })
  self.completion = require('orgmode.org.autocompletion'):new({ files = self.files })
  self.statusline_debounced = require('orgmode.utils').debounce('statusline', function()
    return self.clock:get_statusline()
  end, 300)
  self.initialized = true
end

---@param file? string
function Org:reload(file)
  self:init()
  return self.files:reload(file)
end

function Org:setup_autocmds()
  local org_augroup = vim.api.nvim_create_augroup('orgmode_nvim', { clear = true })
  vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = { '*.org', '*.org_archive' },
    group = org_augroup,
    callback = function(event)
      self:reload(vim.fn.fnamemodify(event.file, ':p'))
    end,
  })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'org',
    group = org_augroup,
    callback = function()
      return self:reload(vim.fn.expand('<afile>:p'))
    end,
  })
end

--- @param revision string?
function Org.setup_ts_grammar(revision)
  setup_ts_grammar_used = true
  local parser_config = require('nvim-treesitter.parsers').get_parser_configs()
  ---@diagnostic disable-next-line: inject-field
  parser_config.org = {
    install_info = {
      url = 'https://github.com/nvim-orgmode/tree-sitter-org',
      revision = revision or ts_revision,
      files = { 'src/parser.c', 'src/scanner.c' },
    },
    filetype = 'org',
  }
end

---@private
function Org._check_ts_grammar()
  vim.defer_fn(function()
    if setup_ts_grammar_used then
      return
    end
    local parser_config = require('nvim-treesitter.parsers').get_parser_configs()
    if parser_config and parser_config.org and parser_config.org.install_info.revision then
      if parser_config.org.install_info.revision ~= ts_revision then
        require('orgmode.utils').echo_error({
          'You are using outdated version of tree-sitter grammar for Orgmode.',
          'To use latest version, replace current grammar installation with "require(\'orgmode\').setup_ts_grammar()" and run :TSUpdate org.',
          'More info in setup section of readme: https://github.com/nvim-orgmode/orgmode#setup',
        })
      end
    else
      require('orgmode.utils').echo_error({
        'Cannot detect parser revision.',
        "Please check your org grammar's install info.",
        'Maybe you forgot to call "require(\'orgmode\').setup_ts_grammar()" before setup.',
      })
    end
  end, 200)
end

---@param opts? OrgDefaultConfig
---@return Org
function Org.setup(opts)
  opts = opts or {}
  Org._check_ts_grammar()
  local config = require('orgmode.config'):extend(opts)
  instance = Org:new()
  vim.defer_fn(function()
    if config.notifications.enabled and #vim.api.nvim_list_uis() > 0 then
      Org.files:load():next(vim.schedule_wrap(function()
        instance.notifications = require('orgmode.notifications')
          :new({
            files = Org.files,
          })
          :start_timer()
      end))
    end
    config:setup_mappings('global')
  end, 1)
  return instance
end

---@private
---@param cmd string
---@param opts string
function Org._set_dot_repeat(cmd, opts)
  local repeat_action = { string.format("'%s'", cmd) }
  if opts then
    table.insert(repeat_action, string.format("'%s'", opts))
  end
  vim.cmd(
    string.format(
      [[silent! call repeat#set("\<cmd>lua require('orgmode').action(%s)\<CR>")]],
      table.concat(repeat_action, ',')
    )
  )
end

---@param cmd string
---@param opts? any
function Org.action(cmd, opts)
  local parts = vim.split(cmd, '.', { plain = true })
  if #parts < 2 then
    return
  end
  local org = Org.instance()
  local item = nil
  for i = 1, #parts - 1 do
    local part = parts[i]
    if not item then
      item = org[part]
    else
      item = item[part]
    end
  end
  if item and item[parts[#parts]] then
    local method = item[parts[#parts]]
    local success, result = pcall(method, item, opts)
    if not success then
      if result.message then
        return require('orgmode.utils').echo_error(result.message)
      end
      if type(result) == 'string' then
        return require('orgmode.utils').echo_error(result)
      end
    end
    Org._set_dot_repeat(cmd, opts)
    return result
  end
end

function Org.cron(opts)
  local ok, result = pcall(function()
    local config = require('orgmode.config'):extend(opts or {})
    if not config.notifications.cron_enabled then
      return vim.cmd([[qa!]])
    end
    Org.files:load_sync(true, 20000)
    instance.notifications = require('orgmode.notifications')
      :new({
        files = Org.files,
      })
      :cron()
  end)

  if not ok then
    require('orgmode.utils').system_notification('Orgmode failed to run cron: ' .. tostring(result))
    return vim.cmd([[qa!]])
  end
end

function Org.instance()
  if not instance then
    instance = Org:new()
  end
  instance:init()
  return instance
end

function Org.destroy()
  if instance then
    instance = nil
    collectgarbage()
  end
end

function _G.orgmode.statusline()
  if not instance or not instance.initialized then
    return ''
  end
  return instance.statusline_debounced() or ''
end

return Org
