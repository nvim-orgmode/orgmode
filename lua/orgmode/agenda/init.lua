local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local colors = require('orgmode.colors')
local Calendar = require('orgmode.objects.calendar')
local Files = require('orgmode.parser.files')
local AgendaFilter = require('orgmode.agenda.filter')
local AgendaSearchView = require('orgmode.agenda.views.search')
local AgendaTodosView = require('orgmode.agenda.views.todos')
local AgendaTagsView = require('orgmode.agenda.views.tags')
local AgendaView = require('orgmode.agenda.views.agenda')

---@class Agenda
---@field content table[]
---@field highlights table[]
---@field views table[]
---@field filters AgendaFilter
local Agenda = {}

---@param opts? table
function Agenda:new(opts)
  opts = opts or {}
  local data = {
    filters = AgendaFilter:new(),
    views = {},
    content = {},
    highlights = {},
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Agenda:agenda()
  self:open_window()
  local view = AgendaView:new({ filters = self.filters }):build()
  self.views = { view }
  return self:_render()
end

-- TODO: Introduce searching ALL/DONE
function Agenda:todos()
  self:open_window()
  local view = AgendaTodosView:new({ filters = self.filters }):build()
  self.views = { view }
  return self:_render()
end

function Agenda:search()
  self:open_window()
  local view = AgendaSearchView:new({ filters = self.filters }):build()
  self.views = { view }
  return self:_render()
end

function Agenda:tags()
  self:open_window()
  local view = AgendaTagsView:new({ filters = self.filters }):build()
  self.views = { view }
  return self:_render()
end

function Agenda:tags_todo()
  self:open_window()
  local view = AgendaTagsView:new({ todo_only = true, filters = self.filters }):build()
  self.views = { view }
  return self:_render()
end

function Agenda:open_window()
  local opened = self:is_opened()
  if opened then
    return
  end

  utils.open_window('orgagenda', math.max(34, config.org_agenda_min_height), config.win_split_mode)

  vim.cmd([[setf orgagenda]])
  vim.cmd([[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]])
  vim.w.org_window_pos = vim.fn.win_screenpos(0)
  config:setup_mappings('agenda')
end

function Agenda:prompt()
  self.filters:reset()
  return utils.menu('Press key for an agenda command', {
    {
      label = 'Agenda for current week or day',
      key = 'a',
      action = function()
        return self:agenda()
      end,
    },
    {
      label = 'List of all TODO entries',
      key = 't',
      action = function()
        return self:todos()
      end,
    },
    {
      label = 'Match a TAGS/PROP/TODO query',
      key = 'm',
      action = function()
        return self:tags()
      end,
    },
    {
      label = 'Like m, but only TODO entries',
      key = 'M',
      action = function()
        return self:tags_todo()
      end,
    },
    {
      label = 'Search for keywords',
      key = 's',
      action = function()
        return self:search()
      end,
    },
    { label = 'Quit', key = 'q' },
    { label = '', separator = ' ', length = 1 },
  }, 'Press key for an agenda command')
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
  local opened = self:is_opened()
  if not opened then
    self:open_window()
  end
  vim.cmd(vim.fn.win_id2win(opened) .. 'wincmd w')
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
  vim.bo.modifiable = true
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.bo.modifiable = false
  vim.bo.modified = false
  colors.highlight(self.highlights, true)
  vim.tbl_map(function(item)
    if item.highlights then
      return colors.highlight(item.highlights)
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
  Files.load(vim.schedule_wrap(function()
    local cursor_view = nil
    if preserve_cursor_pos then
      cursor_view = vim.fn.winsaveview()
    end
    self:_call_view_and_render('build')
    if preserve_cursor_pos then
      vim.fn.winrestview(cursor_view)
    end
  end))
end

function Agenda:is_opened()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_buf_get_option(vim.api.nvim_win_get_buf(win), 'filetype') == 'orgagenda' then
      return win
    end
  end
  return false
end

function Agenda:advance_span(direction)
  return self:_call_view_and_render('advance_span', direction)
end

function Agenda:change_span(span)
  return self:_call_view_and_render('change_span', span)
end

function Agenda:open_day(day)
  local view = AgendaView:new({ span = 'day', from = day }):build()
  self.views = { view }
  return self:_render()
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
  vim.fn.cursor({ item.file_position, 0 })
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

function Agenda:clock_out()
  return self:_remote_edit({
    action = 'clock.org_clock_out',
    redo = true,
    getter = function()
      local last_clocked = Files.get_clocked_headline()
      if last_clocked and last_clocked:is_clocked_in() then
        return { file = last_clocked.file, file_position = last_clocked.range.start_line }
      end
    end,
  })
end

function Agenda:clock_cancel()
  return self:_remote_edit({
    action = 'clock.org_clock_cancel',
    redo = true,
    getter = function()
      local last_clocked = Files.get_clocked_headline()
      if last_clocked and last_clocked:is_clocked_in() then
        return { file = last_clocked.file, file_position = last_clocked.range.start_line }
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
    if vim.api.nvim_buf_get_option(vim.api.nvim_win_get_buf(win), 'filetype') == 'org' then
      target_window = win
    end
  end

  if not target_window then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_get_option(buf, 'buftype') == '' and vim.api.nvim_buf_get_option(buf, 'modifiable') then
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
  vim.fn.cursor({ item.file_position, 0 })
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
  local line = vim.fn.line('.')
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
  local update = Files.update_file(item.file, function(_)
    vim.fn.cursor({ item.file_position, 0 })
    return utils.promisify(require('orgmode').action(action)):next(function()
      return Files.get_closest_headline()
    end)
  end)

  update:next(function(headline)
    if opts.redo then
      return self:redo(true)
    end
    if not opts.update_in_place or not headline then
      return
    end
    if item.agenda_item then
      item.agenda_item:set_headline(headline)
      self.content[line] =
        AgendaView.build_agenda_item_content(item.agenda_item, item.longest_category, item.longest_date, item.line)
    else
      self.content[line] = AgendaTodosView.generate_todo_item(headline, item.longest_category, item.line)
    end
    return self:_render(true)
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
