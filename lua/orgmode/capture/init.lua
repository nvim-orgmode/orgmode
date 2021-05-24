local utils = require('orgmode.utils')
local config = require('orgmode.config')

local Capture = {}

function Capture:new(opts)
  opts = opts or {}
  local data = {}
  data.templates = {
    task = {'* TODO '}
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Capture:prompt()
  return utils.menu('Select a capture template:', {
    { label = 'Task', key = 't', action = function() return self:open_template('task') end },
    { label = '', key = '', separator = true },
    { label = 'Quit', key = 'q' }
  })
end

function Capture:open_template(template)
  if not self.templates[template] then return end
  vim.cmd[[16split orgagenda]]
  vim.cmd[[setf orgcapture]]
  vim.cmd[[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]]
  vim.api.nvim_buf_set_lines(0, 0, -1, true, self.templates[template])
  vim.cmd[[norm!$]]
  vim.cmd[[startinsert!]]
  vim.cmd[[autocmd BufWipeout <buffer> ++once lua require('orgmode').action('capture.refile')]]
end

function Capture:refile()
  if not config.org_default_notes_file or config.org_default_notes_file == '' then
    return utils.warning('Missing default notes file setting.')
  end
  local lines = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), '\n')
  local file = vim.fn.fnamemodify(config.org_default_notes_file, ':p')
  utils.writefile(file, lines, 'a')
end

return Capture
