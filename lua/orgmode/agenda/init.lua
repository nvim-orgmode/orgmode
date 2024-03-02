local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local colors = require('orgmode.colors')
local Calendar = require('orgmode.objects.calendar')
local AgendaFilter = require('orgmode.agenda.filter')
local AgendaSearchView = require('orgmode.agenda.views.search')
local AgendaTodosView = require('orgmode.agenda.views.todos')
local AgendaTagsView = require('orgmode.agenda.views.tags')
local AgendaView = require('orgmode.agenda.views.agenda')
local Menu = require('orgmode.ui.menu')
local Promise = require('orgmode.utils.promise')

---@class OrgAgenda
---@field content table[]
---@field highlights table[]
---@field views table[]
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

---@param View table
---@param type string
---@param opts? table
function Agenda:open_agenda_view(View, type, opts)
  self:open_window()
  local view = View:new(vim.tbl_deep_extend('force', opts or {}, {
    filters = self.filters,
    files = self.files,
  })):build()
  self.views = { view }
  vim.b.org_agenda_type = type
  return self:_render()
end

function Agenda:agenda(opts)
  self:open_agenda_view(AgendaView, 'agenda', opts)
end

-- TODO: Introduce searching ALL/DONE
function Agenda:todos()
  self:open_agenda_view(AgendaTodosView, 'todos')
end

function Agenda:search()
  self:open_agenda_view(AgendaSearchView, 'search')
end

function Agenda:tags(opts)
  self:open_agenda_view(AgendaTagsView, 'tags', opts)
end

function Agenda:tags_todo()
  return self:tags({ todo_only = true })
end

---@return number buffer number
function Agenda:open_window()
  -- if an agenda window is already open, return it
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_get_option_value('filetype', {
      buf = buf,
    })
    if ft == 'orgagenda' then
      return buf
    end
  end

  utils.open_window('orgagenda', math.max(34, config.org_agenda_min_height), config.win_split_mode, config.win_border)

  vim.cmd([[setf orgagenda]])
  vim.cmd([[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]])
  vim.w.org_window_pos = vim.fn.win_screenpos(0)
  config:setup_mappings('agenda')
  return vim.fn.bufnr()
end

function Agenda:prompt()
  self.filters:reset()
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
      return self:tags({ todo_only = true })
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

function Agenda:_render(skip_rebuild)
  if not skip_rebuild then
    self.content = {}
    self.highlights = {}
    for _, view in ipairs(self.views) do
      utils.concat(self.content, view.content)
      utils.concat(self.highlights, view.highlights)
    end
  end
  local bufnr = self:open_window()
  if vim.w.org_window_split_mode == 'horizontal' then
    local win_height = math.max(math.min(34, #self.content), config.org_agenda_min_height)
    if vim.w.org_window_pos and vim.deep_equal(vim.fn.win_screenpos(0), vim.w.org_window_pos) then
      vim.cmd(string.format('resize %d', win_height))
      vim.w.org_window_pos = vim.fn.win_screenpos(0)
    else
      vim.w.org_window_pos = nil
    end
  end
  local lines = vim.tbl_map(function(item)
    return item.line_content
  end, self.content)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false
  colors.highlight(self.highlights, true, bufnr)
  vim.tbl_map(function(item)
    if item.highlights then
      return colors.highlight(item.highlights, false, bufnr)
    end
  end, self.content)
  if not skip_rebuild then
    self:_call_view('after_print', self.content)
  end
end

function Agenda:reset()
  return self:_call_view_and_render('reset')
end

function Agenda:redo(preserve_cursor_pos)
  return self.files:load(true):next(vim.schedule_wrap(function()
    local cursor_view = nil
    if preserve_cursor_pos then
      cursor_view = vim.fn.winsaveview() or {}
    end
    self:_call_view_and_render('build')
    if cursor_view then
      vim.fn.winrestview(cursor_view)
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
  return self:open_agenda_view(AgendaView, 'agenda', {
    span = 'day',
    from = day,
  })
end

function Agenda:goto_date()
  local views = {}
  for _, view in ipairs(self.views) do
    if view.goto_date then
      table.insert(views, view)
    end
  end

  if #views == 0 then
    return utils.echo_error('No available views to jump to date.')
  end

  return Calendar.new({ date = Date.now() }).open():next(function(date)
    if not date then
      return
    end
    for _, view in ipairs(views) do
      view:goto_date(date)
    end
    self:_render()
  end)
end

function Agenda:switch_to_item()
  local item = self:_get_jumpable_item()
  if not item then
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
  vim.fn.cursor({ item.file_position, 1 })
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
        return { file = last_clocked.file.filename, file_position = last_clocked:get_range().start_line }
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
        return { file = last_clocked.file.filename, file_position = last_clocked:get_range().start_line }
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
  return self:redo(true)
end

function Agenda:goto_item()
  local item = self:_get_jumpable_item()
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

  vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
  vim.fn.cursor({ item.file_position, 1 })
  vim.cmd([[normal! zv]])
end

function Agenda:filter()
  local this = self
  self.filters:parse_tags_and_categories(self.content)
  local filter_term = vim.fn.OrgmodeInput('Filter [+cat-tag/regexp/]: ', self.filters.value, function(arg_lead)
    return utils.prompt_autocomplete(arg_lead:lower(), this.filters:get_completion_list(), { '+', '-' })
  end)
  self.filters:parse(filter_term)
  return self:redo()
end

---@param opts table
function Agenda:_remote_edit(opts)
  opts = opts or {}
  local line = vim.fn.line('.') or 0
  local action = opts.action
  if not action then
    return
  end
  local getter = opts.getter
    or function()
      local item = self.content[line]
      if not item or not item.jumpable then
        return
      end
      return item
    end
  local item = getter()
  if not item then
    return
  end
  local update = self.files:update_file(item.file, function(_)
    vim.fn.cursor({ item.file_position, 1 })
    return Promise.resolve(require('orgmode').action(action)):next(function()
      return self.files:get_closest_headline_or_nil()
    end)
  end)

  update:next(function(headline)
    ---@cast headline OrgHeadline
    if opts.redo then
      return self:redo(true)
    end
    if not opts.update_in_place or not headline then
      return
    end
    local line_range_same = headline:get_range():is_same_line_range(item.headline:get_range())

    local update_item_inline = function()
      if item.agenda_item then
        item.agenda_item:set_headline(headline)
        self.content[line] =
          AgendaView.build_agenda_item_content(item.agenda_item, item.longest_category, item.longest_date, item.line)
      else
        self.content[line] = AgendaTodosView.generate_todo_item(headline, item.longest_category, item.line)
      end
      return self:_render(true)
    end

    if line_range_same then
      return update_item_inline()
    end

    -- If line range was changed, some other agenda items might have outdated position
    -- In that case, we need to reload the agenda and try to find the same headline to update it in place
    return self:redo(true):next(function()
      for content_line, content_item in pairs(self.content) do
        if content_item.headline and content_item.headline:is_same(headline) then
          item = self.content[content_line]
          return update_item_inline()
        end
      end
    end)
  end)
end

---@return table|nil
function Agenda:_get_jumpable_item()
  local item = self.content[vim.fn.line('.')]
  if not item then
    return nil
  end
  if item.is_table and item.table_row then
    for _, view in ipairs(self.views) do
      if view.clock_report then
        item = view.clock_report:find_agenda_item(item)
        break
      end
    end
  end
  if not item.jumpable then
    return nil
  end
  return item
end

function Agenda:quit()
  vim.api.nvim_win_close(0, true)
end

function Agenda:_call_view(method, ...)
  local executed = false
  for _, view in ipairs(self.views) do
    if view[method] then
      view[method](view, ...)
      executed = true
    end
  end

  return executed
end

function Agenda:_call_view_and_render(method, ...)
  local executed = self:_call_view(method, ...)
  if executed then
    return self:_render()
  end
end

return Agenda
