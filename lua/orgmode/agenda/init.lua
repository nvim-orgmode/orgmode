local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local colors = require('orgmode.colors')
local Calendar = require('orgmode.objects.calendar')
local AgendaFilter = require('orgmode.agenda.filter')
local Menu = require('orgmode.ui.menu')
local Promise = require('orgmode.utils.promise')
local AgendaTypes = require('orgmode.agenda.types')

---@class OrgAgenda
---@field highlights table[]
---@field views OrgAgendaViewType[]
---@field filters OrgAgendaFilter
---@field files OrgFiles
local Agenda = {}

---@param opts? table
function Agenda:new(opts)
  opts = opts or {}
  local data = {
    filters = AgendaFilter:new(),
    views = {},
    content = {},
    highlights = {},
    files = opts.files,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param type OrgAgendaTypes
---@param opts? table
function Agenda:open_view(type, opts)
  self.filters:reset()
  local view_opts = vim.tbl_extend('force', opts or {}, {
    files = self.files,
    agenda_filter = self.filters,
  })

  local view = AgendaTypes[type]:new(view_opts)
  if not view then
    return
  end
  self.views = { view }
  return self:render()
end

function Agenda:render()
  local line = vim.fn.line('.')
  local bufnr = self:_open_window()
  for i, view in ipairs(self.views) do
    view:render(bufnr, line)
    if #self.views > 1 and i < #self.views then
      colors.add_hr(bufnr, vim.fn.line('$'))
    end
  end
  vim.bo[bufnr].modifiable = false

  if vim.w.org_window_split_mode == 'horizontal' then
    local win_height = math.max(math.min(34, vim.api.nvim_buf_line_count(bufnr)), config.org_agenda_min_height)
    if vim.w.org_window_pos and vim.deep_equal(vim.fn.win_screenpos(0), vim.w.org_window_pos) then
      vim.cmd(string.format('resize %d', win_height))
      vim.w.org_window_pos = vim.fn.win_screenpos(0)
    else
      vim.w.org_window_pos = nil
    end
  end
end

function Agenda:agenda(opts)
  return self:open_view('agenda', opts)
end

-- TODO: Introduce searching ALL/DONE
function Agenda:todos(opts)
  return self:open_view('todo', opts)
end

function Agenda:search()
  return self:open_view('search')
end

function Agenda:tags(opts)
  return self:open_view('tags', opts)
end

function Agenda:tags_todo(opts)
  return self:open_view('tags_todo', opts)
end

---@private
---@return number buffer number
function Agenda:_open_window()
  -- if an agenda window is already open, return it
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_get_option_value('filetype', {
      buf = buf,
    })
    if ft == 'orgagenda' then
      vim.bo[buf].modifiable = true
      colors.highlight({}, true, buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, true, {})
      return buf
    end
  end

  utils.open_window('orgagenda', math.max(34, config.org_agenda_min_height), config.win_split_mode, config.win_border)

  vim.cmd([[setf orgagenda]])
  vim.cmd([[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]])
  vim.w.org_window_pos = vim.fn.win_screenpos(0)
  config:setup_mappings('agenda', vim.api.nvim_get_current_buf())
  return vim.fn.bufnr()
end

function Agenda:prompt()
  local menu = Menu:new({
    title = 'Press key for an agenda command',
    prompt = 'Press key for an agenda command',
  })

  menu:add_option({
    label = 'Agenda for current week or day',
    key = 'a',
    action = function()
      return self:agenda()
    end,
  })
  menu:add_option({
    label = 'List of all TODO entries',
    key = 't',
    action = function()
      return self:todos()
    end,
  })
  menu:add_option({
    label = 'Match a TAGS/PROP/TODO query',
    key = 'm',
    action = function()
      return self:tags()
    end,
  })
  menu:add_option({
    label = 'Like m, but only TODO entries',
    key = 'M',
    action = function()
      return self:tags_todo()
    end,
  })
  menu:add_option({
    label = 'Search for keywords',
    key = 's',
    action = function()
      return self:search()
    end,
  })
  menu:add_option({ label = 'Quit', key = 'q' })
  menu:add_separator({ icon = ' ', length = 1 })

  return menu:open()
end

function Agenda:reset()
  return self:_call_view_and_render('reset')
end

---@param source? string
function Agenda:redo(source, preserve_cursor_pos)
  return self.files:load(true):next(vim.schedule_wrap(function()
    local save_view = preserve_cursor_pos and vim.fn.winsaveview()
    if source == 'mapping' then
      self:_call_view_and_render('redo')
    end
    self:render()
    if save_view then
      vim.fn.winrestview(save_view)
    end
  end))
end

function Agenda:advance_span(direction)
  return self:_call_view_and_render('advance_span', direction, vim.v.count1)
end

function Agenda:change_span(span)
  return self:_call_view_and_render('change_span', span)
end

function Agenda:open_day(day)
  return self:open_view('agenda', {
    span = 'day',
    from = day,
  })
end

function Agenda:goto_date()
  local views = {}
  for _, view in ipairs(self.views) do
    ---@diagnostic disable-next-line: undefined-field
    if view.goto_date and view.view:is_in_range() then
      table.insert(views, view)
    end
  end

  if #views == 0 then
    return utils.echo_error('No available views to jump to date.')
  end

  return Calendar.new({ date = Date.now(), title = 'Go to agenda date' }):open():next(function(date)
    if not date then
      return nil
    end
    for _, view in ipairs(views) do
      view:goto_date(date)
    end
    return self:render()
  end)
end

function Agenda:switch_to_item()
  local item = self:_get_headline()
  if not item then
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(item.file.filename))
  vim.fn.cursor({ item:get_range().start_line, 1 })
  vim.cmd([[normal! zv]])
end

function Agenda:change_todo_state()
  return self:_remote_edit({
    action = 'org_mappings.todo_next_state',
    update_in_place = true,
  })
end

function Agenda:clock_in()
  return self:_remote_edit({
    action = 'clock.org_clock_in',
    redo = true,
  })
end

function Agenda:add_note()
  return self:_remote_edit({
    action = 'org_mappings.add_note',
    redo = true,
  })
end

function Agenda:refile()
  return self:_remote_edit({
    action = 'capture.refile_headline_to_destination',
    redo = true,
  })
end

function Agenda:clock_out()
  return self:_remote_edit({
    action = 'clock.org_clock_out',
    redo = true,
    getter = function()
      local last_clocked = self.files:get_clocked_headline()
      if last_clocked and last_clocked:is_clocked_in() then
        return last_clocked
      end
    end,
  })
end

function Agenda:clock_cancel()
  return self:_remote_edit({
    action = 'clock.org_clock_cancel',
    redo = true,
    getter = function()
      local last_clocked = self.files:get_clocked_headline()
      if last_clocked and last_clocked:is_clocked_in() then
        return last_clocked
      end
    end,
  })
end

function Agenda:set_effort()
  return self:_remote_edit({ action = 'clock.org_set_effort' })
end

function Agenda:set_priority()
  return self:_remote_edit({
    action = 'org_mappings.set_priority',
    update_in_place = true,
  })
end

function Agenda:priority_up()
  return self:_remote_edit({
    action = 'org_mappings.priority_up',
    update_in_place = true,
  })
end

function Agenda:priority_down()
  return self:_remote_edit({
    action = 'org_mappings.priority_down',
    update_in_place = true,
  })
end

function Agenda:archive()
  return self:_remote_edit({
    action = 'org_mappings.archive',
    redo = true,
  })
end

function Agenda:toggle_archive_tag()
  return self:_remote_edit({
    action = 'org_mappings.toggle_archive_tag',
    update_in_place = true,
  })
end

function Agenda:set_tags()
  return self:_remote_edit({
    action = 'org_mappings.set_tags',
    update_in_place = true,
  })
end

function Agenda:set_deadline()
  return self:_remote_edit({
    action = 'org_mappings.org_deadline',
    redo = true,
  })
end

function Agenda:set_schedule()
  return self:_remote_edit({
    action = 'org_mappings.org_schedule',
    redo = true,
  })
end

function Agenda:toggle_clock_report()
  self:_call_view('toggle_clock_report')
  return self:redo('agenda', true)
end

---@private
---@return OrgHeadline | nil, OrgAgendaLine | nil, OrgAgendaViewType | nil
function Agenda:_get_headline()
  local line = vim.fn.line('.')
  for _, view in ipairs(self.views) do
    local agenda_line = view:get_line(line)
    if agenda_line and agenda_line.headline then
      return agenda_line.headline, agenda_line, view
    end
  end
end

function Agenda:goto_item()
  local item = self:_get_headline()
  if not item then
    return
  end
  local target_window = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ft = vim.api.nvim_get_option_value('filetype', {
      buf = vim.api.nvim_win_get_buf(win),
    })
    if ft == 'org' then
      target_window = win
    end
  end

  if not target_window then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.api.nvim_get_option_value('filetype', { buf = buf })
      local modifiable = vim.api.nvim_get_option_value('modifiable', { buf = buf })
      if ft == '' and modifiable then
        target_window = win
      end
    end
  end

  if target_window then
    vim.cmd(vim.fn.win_id2win(target_window) .. 'wincmd w')
  else
    vim.cmd([[aboveleft split]])
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(item.file.filename))
  vim.fn.cursor({ item:get_range().start_line, 1 })
  vim.cmd([[normal! zv]])
end

function Agenda:filter()
  local this = self
  self.filters:parse_available_filters(self.views)
  local filter_term = vim.fn.OrgmodeInput('Filter [+cat-tag/regexp/]: ', self.filters.value, function(arg_lead)
    return utils.prompt_autocomplete(arg_lead, this.filters:get_completion_list(), { '+', '-' })
  end)
  if filter_term == self.filters.value then
    return
  end
  self.filters:parse(filter_term)
  return self:redo('filter', true)
end

---@param opts table
function Agenda:_remote_edit(opts)
  opts = opts or {}
  local action = opts.action
  if not action then
    return
  end
  local getter = opts.getter
    or function()
      local item, agenda_line, view = self:_get_headline()
      if not item then
        return
      end
      return item, agenda_line, view
    end
  local item, agenda_line, view = getter()
  if not item then
    return
  end
  local update = item.file:update(function(_)
    vim.fn.cursor({ item:get_range().start_line, 1 })
    return Promise.resolve(require('orgmode').action(action)):next(function()
      return self.files:get_closest_headline_or_nil()
    end)
  end)

  update:next(function(headline)
    ---@cast headline OrgHeadline
    if opts.redo then
      return self:redo('remote_edit', true)
    end
    if not opts.update_in_place or not headline then
      return
    end
    local line_range_same = headline:get_range():is_same_line_range(item:get_range())

    local update_item_inline = function()
      if not agenda_line or not view then
        return
      end
      return view:rerender_agenda_line(agenda_line, headline)
    end

    if line_range_same then
      return update_item_inline()
    end

    return self:redo('remote_edit', true)
  end)
end

function Agenda:quit()
  vim.api.nvim_win_close(0, true)
end

function Agenda:_call_view(method, ...)
  local executed = false
  for _, view in ipairs(self.views) do
    if view[method] and view.view:is_in_range() then
      view[method](view, ...)
      executed = true
    end
  end

  return executed
end

function Agenda:_call_view_and_render(method, ...)
  local executed = self:_call_view(method, ...)
  if executed then
    return self:render()
  end
end

return Agenda
