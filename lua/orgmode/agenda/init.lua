local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local colors = require('orgmode.colors')
local Calendar = require('orgmode.objects.calendar')
local AgendaFilter = require('orgmode.agenda.filter')
local Menu = require('orgmode.ui.menu')
local Promise = require('orgmode.utils.promise')
local AgendaTypes = require('orgmode.agenda.types')
local Input = require('orgmode.ui.input')
local OrgHyperlink = require('orgmode.org.links.hyperlink')
local MenuEntries = require('orgmode.agenda.menu_entries')

---@class OrgAgenda
---@field highlights table[]
---@field views OrgAgendaViewType[]
---@field filters OrgAgendaFilter
---@field files OrgFiles
---@field highlighter OrgHighlighter
---@field links OrgLinks
local Agenda = {}

---@param opts? { highlighter: OrgHighlighter, files: OrgFiles, links: OrgLinks }
---@return OrgAgenda
function Agenda:new(opts)
  opts = opts or {}
  local data = {
    filters = AgendaFilter:new(),
    views = {},
    content = {},
    highlights = {},
    files = opts.files,
    highlighter = opts.highlighter,
    links = opts.links,
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
    highlighter = self.highlighter,
  })

  local view = AgendaTypes[type]:new(view_opts)
  if not view then
    return
  end
  self.views = { view }
  return self:prepare_and_render()
end

function Agenda:prepare_and_render()
  return Promise.map(function(view)
    return view:prepare()
  end, self.views):next(function(views)
    local valid_views = vim.tbl_filter(function(view)
      return view ~= false
    end, views)

    -- Some of the views returned false, abort render
    if #valid_views ~= #self.views then
      return
    end

    self.views = views
    return self:render()
  end)
end

function Agenda:render()
  local line = vim.fn.line('.')
  local fold_state = self:_get_fold_state()
  local bufnr = self:_open_window()
  for i, view in ipairs(self.views) do
    view:render(bufnr, line)
    if #self.views > 1 and i < #self.views and #view:get_lines() > 0 then
      colors.add_hr(bufnr, vim.api.nvim_buf_line_count(bufnr), config.org_agenda_block_separator)
    end
  end
  vim.bo[bufnr].modifiable = false
  self:_restore_fold_state(bufnr, fold_state)

  if vim.w.org_window_split_mode == 'horizontal' then
    local win_height = math.max(math.min(34, vim.api.nvim_buf_line_count(bufnr)), config.org_agenda_min_height)
    local untouched = vim.w.org_window_pos
      and vim.deep_equal(vim.fn.win_screenpos(0), vim.w.org_window_pos)
      and vim.fn.winheight(0) == vim.w.org_window_height
    if untouched then
      vim.cmd(string.format('resize %d', win_height))
      vim.w.org_window_pos = vim.fn.win_screenpos(0)
      vim.w.org_window_height = vim.fn.winheight(0)
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

function Agenda:_build_custom_commands()
  local custom_commands = {}
  ---@param opts OrgAgendaCustomCommandType
  local get_type_opts = function(opts, id)
    local opts_by_type = {
      agenda = {
        span = opts.org_agenda_span,
        start_day = opts.org_agenda_start_day,
        start_on_weekday = opts.org_agenda_start_on_weekday,
      },
      tags = {
        match_query = opts.match,
        todo_ignore_scheduled = opts.org_agenda_todo_ignore_scheduled,
        todo_ignore_deadlines = opts.org_agenda_todo_ignore_deadlines,
      },
      tags_todo = {
        match_query = opts.match,
        todo_ignore_scheduled = opts.org_agenda_todo_ignore_scheduled,
        todo_ignore_deadlines = opts.org_agenda_todo_ignore_deadlines,
      },
    }

    if not opts_by_type[opts.type] then
      return
    end

    opts_by_type[opts.type].sorting_strategy = opts.org_agenda_sorting_strategy
    opts_by_type[opts.type].agenda_filter = self.filters
    opts_by_type[opts.type].files = self.files
    opts_by_type[opts.type].header = opts.org_agenda_overriding_header
    opts_by_type[opts.type].agenda_files = opts.org_agenda_files
    opts_by_type[opts.type].tag_filter = opts.org_agenda_tag_filter_preset
    opts_by_type[opts.type].category_filter = opts.org_agenda_category_filter_preset
    opts_by_type[opts.type].highlighter = self.highlighter
    opts_by_type[opts.type].remove_tags = opts.org_agenda_remove_tags
    opts_by_type[opts.type].id = id

    return opts_by_type[opts.type]
  end
  for _, entry in ipairs(MenuEntries.custom_commands()) do
    local shortcut, command = entry.key, entry.command --[[@as OrgAgendaCustomCommand]]
    table.insert(custom_commands, {
      label = entry.label,
      key = shortcut,
      action = function()
        local views = {}
        for i, agenda_type in ipairs(command.types) do
          local opts = get_type_opts(agenda_type, ('%s_%s_%d'):format(shortcut, agenda_type.type, i))
          if not opts then
            utils.echo_error('Invalid custom agenda command type ' .. agenda_type.type)
            break
          end
          table.insert(views, AgendaTypes[agenda_type.type]:new(opts))
        end
        self.views = views
        return self:prepare_and_render():next(function()
          if #self.views > 1 then
            vim.fn.cursor({ 1, 0 })
          end
        end)
      end,
    })
  end
  return custom_commands
end

---@private
---@return OrgMenu
function Agenda:_build_menu()
  local menu = Menu:new({
    title = 'Press key for an agenda command',
    prompt = 'Press key for an agenda command',
  })

  for _, entry in ipairs(MenuEntries.builtin) do
    menu:add_option({
      label = entry.label,
      key = entry.key,
      action = function()
        return self[entry.method](self)
      end,
    })
  end

  local custom_commands = self:_build_custom_commands()
  if #custom_commands > 0 then
    for _, command in ipairs(custom_commands) do
      menu:add_option({
        label = command.label,
        key = command.key,
        action = command.action,
      })
    end
  end

  menu:add_option({ label = 'Quit', key = 'q' })
  menu:add_separator({ icon = ' ', length = 1 })

  return menu
end

---@private
---@return number | nil window id of the open agenda window
function Agenda:_get_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_get_option_value('filetype', {
      buf = buf,
    })
    if ft == 'orgagenda' then
      return win
    end
  end
end

---@private
---@return number buffer number
function Agenda:_open_window()
  -- if an agenda window is already open, return it
  local win = self:_get_window()
  if win then
    local buf = vim.api.nvim_win_get_buf(win)
    vim.bo[buf].modifiable = true
    colors.apply_highlights({}, true, buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, {})
    return buf
  end

  utils.open_window('orgagenda', math.max(34, config.org_agenda_min_height), config.win_split_mode, config.win_border)

  -- Set before the filetype so FileType autocommands can override them
  vim.cmd([[setlocal foldmethod=expr foldexpr=v:lua.orgmode.agenda_foldexpr(v:lnum) foldlevel=1]])
  vim.cmd([[setf orgagenda]])
  vim.cmd([[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]])
  vim.w.org_window_pos = vim.fn.win_screenpos(0)
  vim.w.org_window_height = vim.fn.winheight(0)
  config:setup_mappings('agenda', vim.api.nvim_get_current_buf())
  return vim.fn.bufnr()
end

---@param key string
function Agenda:open_by_key(key)
  local menu = self:_build_menu()
  local item = menu:get_entry_by_key(key)
  if not item then
    return utils.echo_error('No agenda view with key ' .. key)
  end
  return item.action()
end

function Agenda:prompt()
  local menu = self:_build_menu()
  return menu:open()
end

function Agenda:reset()
  return self:_call_view_and_render('reset')
end

---@param source? string
---@param preserve_cursor_pos? boolean
function Agenda:redo(source, preserve_cursor_pos)
  self:_call_all_views('redo')
  local restore_view = preserve_cursor_pos and self:_save_view()
  return self.files
    :load(true)
    :next(function()
      if source == 'mapping' then
        return self:_call_view_async('redraw')
      end
      return true
    end)
    :next(function()
      local win = self:_get_window()
      if win then
        vim.api.nvim_win_call(win, function()
          self:render()
        end)
      else
        self:render()
      end
      if restore_view then
        restore_view()
      end
    end)
end

---@param a OrgAgendaLineHeadlineRef
---@param b OrgAgendaLineHeadlineRef
---@return boolean
local function same_headline(a, b)
  if a.filename ~= b.filename then
    return false
  end
  if a.id then
    return a.id == b.id
  end
  return a.title == b.title
end

---Redo can run while an org buffer is current (remote edits, user
---autocommands on write), so the view is taken from the agenda window,
---not from the current one.
---@private
---@return fun() | nil
function Agenda:_save_view()
  local win = self:_get_window()
  if not win then
    return nil
  end
  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local agenda_line = vim.api.nvim_win_call(win, function()
    return select(2, self:_get_headline())
  end)
  local ref = agenda_line and agenda_line.headline_ref
  local row = view.lnum - view.topline

  return function()
    local target_win = self:_get_window()
    if not target_win then
      return
    end
    local line_nr = ref and self:_find_line_nr(ref, view.lnum)
    if line_nr then
      view.lnum = line_nr
      local height = vim.api.nvim_win_get_height(target_win)
      if line_nr < view.topline or line_nr >= view.topline + height then
        view.topline = math.max(1, line_nr - row)
      end
    end
    vim.api.nvim_win_call(target_win, function()
      vim.fn.winrestview(view)
    end)
  end
end

---A headline can occupy several agenda lines (scheduled and deadline,
---repeats), so the one nearest the previous cursor line wins. Headlines
---without an ID that share a title are told apart by their line in the
---file, as long as it is unchanged.
---@private
---@param ref OrgAgendaLineHeadlineRef
---@param lnum number
---@return number | nil
function Agenda:_find_line_nr(ref, lnum)
  local nearest = nil
  local nearest_same_start = nil
  local function closer(line_nr, current)
    return not current or math.abs(line_nr - lnum) < math.abs(current - lnum)
  end
  for _, view in ipairs(self.views) do
    for _, line in ipairs(view:get_lines()) do
      local line_ref = line.headline_ref
      if line_ref and same_headline(ref, line_ref) then
        if closer(line.line_nr, nearest) then
          nearest = line.line_nr
        end
        if line_ref.start_line == ref.start_line and closer(line.line_nr, nearest_same_start) then
          nearest_same_start = line.line_nr
        end
      end
    end
  end
  return nearest_same_start or nearest
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
  utils.goto_headline(item)
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

function Agenda:preview_item()
  local headline = self:get_headline_at_cursor()
  if not headline then
    return
  end

  local lines = headline:get_lines()
  local offset = 4
  local width = lines[1]:len() + offset

  vim.tbl_map(function(line)
    width = math.max(width, line:len() + offset)
  end, lines)

  local win_opts = vim.tbl_deep_extend('force', {
    width = width,
  }, config.ui.agenda.preview_window or {})

  local buf = vim.lsp.util.open_floating_preview(lines, '', win_opts)
  vim.api.nvim_set_option_value('filetype', 'org', { buf = buf })
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
  if self:_is_block_header(vim.fn.line('.')) then
    return vim.cmd([[normal! za]])
  end
  local item = self:_get_headline()
  if not item then
    return
  end
  local target_window = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local ft = vim.api.nvim_get_option_value('filetype', {
      buf = vim.api.nvim_win_get_buf(win),
    })
    if ft == 'org' then
      target_window = win
    end
  end

  if not target_window then
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
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

  utils.goto_headline(item)
end

function Agenda:filter()
  local this = self
  self.filters:parse_available_filters(self.views)
  return Input.open('Filter [+cat-tag/regexp/]: ', self.filters.value, function(arg_lead)
    return utils.prompt_autocomplete(arg_lead, this.filters:get_completion_list(), { '+', '-' })
  end):next(function(value)
    if not value or value == self.filters.value then
      return false
    end
    self.filters:parse(value)
    return self:redo('filter', true)
  end)
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
      local headline, agenda_line, view = self:_get_headline()
      if not headline then
        return
      end
      return headline, agenda_line, view
    end
  local headline, agenda_line, view = getter()
  if not headline then
    return
  end
  local old_range = headline:get_range()

  local update = headline.file:update(function(_)
    vim.fn.cursor({ headline:get_range().start_line, 1 })
    return Promise.resolve(require('orgmode').action(action)):next(function()
      return self.files:get_closest_headline_or_nil()
    end)
  end)

  update:next(function(updated_headline)
    ---@cast updated_headline OrgHeadline
    if opts.redo then
      return self:redo('remote_edit', true)
    end
    if not opts.update_in_place or not updated_headline then
      return
    end
    local line_range_same = updated_headline:get_range():is_same_line_range(old_range)

    local update_item_inline = function()
      if not agenda_line or not view then
        return
      end
      return view:rerender_agenda_line(agenda_line, updated_headline)
    end

    if line_range_same then
      return update_item_inline()
    end

    return self:redo('remote_edit', true)
  end)
end

---@return OrgHeadline | nil
function Agenda:get_headline_at_cursor()
  local line_nr = vim.fn.line('.')

  for _, view in ipairs(self.views) do
    local agenda_line = view:get_line(line_nr)
    if agenda_line and agenda_line.headline then
      return agenda_line.headline
    end
  end
end

function Agenda:open_at_point()
  local link = OrgHyperlink.from_extmarks_at_cursor()

  if link then
    return self.links:follow(link.url:to_string())
  end

  utils.echo_error('No link found under cursor')
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

function Agenda:_call_view_async(method, ...)
  local args = { ... }
  return Promise.map(function(view)
    if view[method] and view.view:is_in_range() then
      return view[method](view, unpack(args))
    end
  end, self.views):next(function(views)
    for _, view in ipairs(views) do
      if view then
        return true
      end
    end
    return false
  end)
end

function Agenda:_call_all_views(method, ...)
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
    return self:render()
  end
end

--- Blocks exist only in custom agenda commands with more than one view.
--- A block spans the rendered lines of its view plus the separator line after it.
---@private
---@param lnum number
---@return OrgAgendaViewType | nil
function Agenda:_get_block_at(lnum)
  if #self.views < 2 then
    return nil
  end
  for _, view in ipairs(self.views) do
    if view.view and #view.view.lines > 0 and view.view:is_in_range(lnum) then
      return view
    end
  end
  return nil
end

---@private
---@param lnum number
---@return boolean
function Agenda:_is_block_header(lnum)
  local block = self:_get_block_at(lnum)
  return block ~= nil and block.view.start_line == lnum
end

---@param lnum number
---@return string | number
function Agenda:foldexpr(lnum)
  local block = self:_get_block_at(lnum)
  if not block then
    return 0
  end
  if block.view.start_line == lnum then
    return '>1'
  end
  return 1
end

--- Closed state of each rendered block, keyed by view index.
--- Folds are lost when the buffer is rewritten, so this is taken before render and applied after.
---@private
---@return table<number, boolean>
function Agenda:_get_fold_state()
  local state = {}
  if #self.views < 2 then
    return state
  end
  for i, view in ipairs(self.views) do
    local rendered = view.view
    if rendered and #rendered.lines > 0 and vim.api.nvim_buf_is_valid(rendered.bufnr) then
      local winid = vim.fn.bufwinid(rendered.bufnr)
      if winid ~= -1 then
        state[i] = vim.api.nvim_win_call(winid, function()
          return vim.fn.foldclosed(rendered.start_line) ~= -1
        end)
      end
    end
  end
  return state
end

--- Vim evaluates the foldexpr while the views are still being written, so the
--- levels it cached are stale. zX recomputes them from the final layout.
---@private
---@param bufnr number
---@param state table<number, boolean>
function Agenda:_restore_fold_state(bufnr, state)
  local winid = vim.fn.bufwinid(bufnr)
  if winid == -1 then
    return
  end
  vim.api.nvim_win_call(winid, function()
    vim.cmd([[normal! zX]])
    for i, closed in pairs(state) do
      local rendered = self.views[i] and self.views[i].view
      if rendered and #rendered.lines > 0 then
        vim.cmd(('%d%s'):format(rendered.start_line, closed and 'foldclose' or 'foldopen'))
      end
    end
  end)
end

function _G.orgmode.agenda_foldexpr(lnum)
  return require('orgmode').agenda:foldexpr(lnum)
end

return Agenda
