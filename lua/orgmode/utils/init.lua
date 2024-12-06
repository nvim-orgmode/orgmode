local Promise = require('orgmode.utils.promise')
local uv = vim.loop
local utils = {}
local debounce_timers = {}
local tmp_window_augroup = vim.api.nvim_create_augroup('OrgTmpWindow', { clear = true })

---@param file string full path to filename
---@param opts? { raw: boolean, schedule: boolean } raw: Return raw results, schedule: wrap results in vim.schedule
function utils.readfile(file, opts)
  opts = opts or {}
  return Promise.new(function(resolve, reject)
    uv.fs_open(file, 'r', 438, function(err1, fd)
      if err1 then
        return reject(err1)
      end
      assert(fd)
      uv.fs_fstat(fd, function(err2, stat)
        if err2 then
          return reject(err2)
        end
        assert(stat)
        uv.fs_read(fd, stat.size, 0, function(err3, data)
          if err3 then
            return reject(err3)
          end
          uv.fs_close(fd, function(err4)
            if err4 then
              return reject(err4)
            end
            assert(data)
            local result = nil
            if opts.raw then
              result = data
            else
              local lines = vim.split(data, '\n')
              if lines[#lines] == '' then
                table.remove(lines, #lines)
              end
              result = lines
            end

            if not opts.schedule then
              return resolve(result)
            end

            vim.schedule(function()
              return resolve(result)
            end)
          end)
        end)
      end)
    end)
  end)
end

function utils.writefile(file, data)
  return Promise.new(function(resolve, reject)
    uv.fs_open(file, 'w', 438, function(err1, fd)
      if err1 then
        return reject(err1)
      end
      assert(fd)
      uv.fs_fstat(fd, function(err2, stat)
        if err2 then
          return reject(err2)
        end
        assert(stat)
        uv.fs_write(fd, data, nil, function(err3, bytes)
          if err3 then
            return reject(err3)
          end
          uv.fs_close(fd, function(err4)
            if err4 then
              return reject(err4)
            end
            return resolve(bytes)
          end)
        end)
      end)
    end)
  end)
end

function utils.system_notification(message)
  if vim.fn.executable('notify-send') == 1 then
    vim.loop.spawn('notify-send', { args = { message } })
  end

  if vim.fn.executable('terminal-notifier') == 1 then
    vim.loop.spawn('terminal-notifier', { args = { '-message', message } })
  end
end

function utils.open(target)
  if vim.fn.executable('xdg-open') == 1 then
    return vim.fn.system(string.format('xdg-open %s', target))
  end

  if vim.fn.executable('open') == 1 then
    return vim.fn.system(string.format('open %s', target))
  end

  if vim.fn.has('win32') == 1 then
    return vim.fn.system(string.format('start "%s"', target))
  end
end

---@param msg string|table
---@param additional_msg? table
---@param store_in_history? boolean
---@return nil
function utils.echo_warning(msg, additional_msg, store_in_history)
  return utils._echo(msg, 'WarningMsg', additional_msg, store_in_history)
end

---@param msg string|table
---@param additional_msg? table
---@param store_in_history? boolean
function utils.echo_error(msg, additional_msg, store_in_history)
  return utils._echo(msg, 'ErrorMsg', additional_msg, store_in_history)
end

---@param msg string|table
---@param additional_msg? table
---@param store_in_history? boolean
function utils.echo_info(msg, additional_msg, store_in_history)
  return utils._echo(msg, nil, additional_msg, store_in_history)
end

---@private
---@return nil
function utils._echo(msg, hl, additional_msg, store_in_history)
  vim.cmd([[redraw!]])
  if type(msg) == 'table' then
    msg = table.concat(msg, '\n')
  end
  local msg_item = { string.format('[orgmode] %s', msg) }
  if hl then
    table.insert(msg_item, hl)
  end
  local msg_list = { msg_item }
  if additional_msg then
    msg_list = utils.concat(msg_list, additional_msg)
  end
  local store = true
  if type(store_in_history) == 'boolean' then
    store = store_in_history
  end
  return vim.api.nvim_echo(msg_list, store, {})
end

---@param word string
---@return string
function utils.capitalize(word)
  return (word:gsub('^%l', string.upper))
end

---@param isoweekday number
---@return number
function utils.convert_from_isoweekday(isoweekday)
  if isoweekday == 7 then
    return 1
  end
  return isoweekday + 1
end

---@param weekday number
---@return number
function utils.convert_to_isoweekday(weekday)
  if weekday == 1 then
    return 7
  end
  return weekday - 1
end

---@param tbl table
---@param callback function
---@param acc any
---@return unknown
function utils.reduce(tbl, callback, acc)
  for i, v in pairs(tbl) do
    acc = callback(acc, v, i)
  end
  return acc
end

---Reverse order in table
---@param tbl table
---@return table
function utils.reverse(tbl)
  local reversed = {}
  for i = #tbl, 1, -1 do
    table.insert(reversed, tbl[i])
  end
  return reversed
end

--- Concat one table at the end of another table
---@param first table
---@param second table
---@param unique? boolean
---@return table
function utils.concat(first, second, unique)
  for _, v in ipairs(second) do
    if not unique or not vim.tbl_contains(first, v) then
      table.insert(first, v)
    end
  end
  return first
end

---@class OrgKeymapData
---@field mode string
---@field lhs string
---@field buffer integer?

---@param data OrgKeymapData
---@return table? map Mapping definition
function utils.get_keymap(data)
  local find_keymap = function(list)
    for _, map in ipairs(list) do
      if map.lhs == data.lhs then
        return map
      end
    end
  end

  local keymap = nil

  if data.buffer then
    keymap = find_keymap(vim.api.nvim_buf_get_keymap(data.buffer, data.mode))
  end

  if not keymap then
    keymap = find_keymap(vim.api.nvim_get_keymap(data.mode))
  end

  return keymap
end

function utils.esc(cmd)
  return vim.api.nvim_replace_termcodes(cmd, true, false, true)
end

function utils.parse_tags_string(tags)
  local parsed_tags = {}
  for _, tag in ipairs(vim.split(tags or '', ':')) do
    if tag:find('^[%w_%%@#]+$') then
      table.insert(parsed_tags, tag)
    end
  end
  return parsed_tags
end

function utils.tags_to_string(taglist)
  local tags = ''
  if #taglist > 0 then
    tags = ':' .. table.concat(taglist, ':') .. ':'
  end
  return tags
end

function utils.ensure_array(val)
  if type(val) ~= 'table' then
    return { val }
  end
  return val
end

function utils.humanize_minutes(minutes)
  if minutes == 0 then
    return 'Now'
  end
  local is_past = minutes < 0
  local minutes_abs = math.abs(minutes)
  if minutes_abs < 60 then
    if is_past then
      return string.format('%d min ago', minutes_abs)
    end
    return string.format('in %d min', minutes_abs)
  end

  local hours = math.floor(minutes_abs / 60)
  local remaining_minutes = minutes_abs - (hours * 60)

  if remaining_minutes == 0 then
    if is_past then
      return string.format('%d hr ago', hours)
    end
    return string.format('in %d hr', hours)
  end

  if is_past then
    return string.format('%d hr and %d min ago', hours, remaining_minutes)
  end
  return string.format('in %d hr and %d min', hours, remaining_minutes)
end

function utils.debounce(name, fn, ms)
  local result = nil
  return function(...)
    local argv = { ... }
    if debounce_timers[name] then
      debounce_timers[name]:stop()
      debounce_timers[name]:close()
      debounce_timers[name] = nil
    end
    local timer = uv.new_timer()
    debounce_timers[name] = timer
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        result = fn(unpack(argv))
      end)
    )
    return result
  end
end

---@param name string
---@return function
function utils.profile(name)
  local start_time = vim.loop.hrtime()
  return function()
    return print(name, string.format('%.2f', (vim.loop.hrtime() - start_time) / 1000000))
  end
end

---@param arg_lead string
---@param list string[]
---@param split_chars? string[]
---@return string[]
function utils.prompt_autocomplete(arg_lead, list, split_chars)
  split_chars = split_chars or { '+', '-', ':', '&', '|' }
  local split_chars_str = vim.pesc(table.concat(split_chars, ''))
  local split_rgx = string.format('[%s]', split_chars_str)
  local match_rgx = string.format('[^%s]*$', split_chars_str)
  local parts = vim.split(arg_lead, split_rgx)
  local base = arg_lead:gsub(match_rgx, '')
  local last = arg_lead:match(match_rgx)
  local matches = vim.tbl_filter(function(tag)
    return tag:match('^' .. vim.pesc(last)) and not vim.tbl_contains(parts, tag)
  end, list)

  return vim.tbl_map(function(tag)
    return base .. tag
  end, matches)
end

function utils.current_file_path()
  return vim.api.nvim_buf_get_name(0)
end

---@param winnr? number
function utils.winwidth(winnr)
  winnr = winnr or 0
  local winwidth = vim.api.nvim_win_get_width(winnr)

  local win_id
  if winnr == 0 then -- use current window
    win_id = vim.fn.win_getid()
  else
    win_id = vim.fn.win_getid(winnr)
  end

  local wininfo = vim.fn.getwininfo(win_id)[1]
  -- this encapsulates both signcolumn & numbercolumn (:h wininfo)
  local gutter_width = wininfo and wininfo.textoff or 0

  return winwidth - gutter_width
end

---@param name string
---@param height number
---@param split_mode string|function|table
---@param border string|table
function utils.open_window(name, height, split_mode, border)
  local cmd_by_split_mode = {
    horizontal = string.format('%dsplit %s', height, name),
    vertical = string.format('vsplit %s', name),
  }

  if cmd_by_split_mode[split_mode] then
    vim.cmd(cmd_by_split_mode[split_mode])
    vim.w.org_window_split_mode = split_mode
    return
  end

  if split_mode == 'auto' then
    local winwidth = utils.winwidth()
    if (winwidth / 2) >= 80 then
      vim.cmd(cmd_by_split_mode.vertical)
      vim.w.org_window_split_mode = 'vertical'
    else
      vim.cmd(cmd_by_split_mode.horizontal)
      vim.w.org_window_split_mode = 'horizontal'
    end
    return
  end

  if type(split_mode) == 'function' then
    return split_mode(name)
  end

  if split_mode == 'float' then
    return utils.open_float(name, { border = border })
  end

  if type(split_mode) == 'table' and split_mode[1] == 'float' then
    return utils.open_float(name, { scale = split_mode[2], border = border })
  end

  return vim.cmd(string.format('%s %s', split_mode, name))
end

function utils.open_tmp_org_window(height, split_mode, border, on_close)
  local prev_winnr = vim.api.nvim_get_current_win()
  utils.open_window(vim.fn.tempname() .. '.org', height or 16, split_mode, border)
  vim.cmd([[setlocal filetype=org bufhidden=wipe nobuflisted nolist noswapfile nofoldenable]])
  local bufnr = vim.api.nvim_get_current_buf()

  if on_close then
    vim.api.nvim_create_autocmd('BufWipeout', {
      buffer = 0,
      group = tmp_window_augroup,
      callback = on_close,
      once = true,
    })
    vim.api.nvim_create_autocmd('VimLeavePre', {
      buffer = 0,
      group = tmp_window_augroup,
      callback = on_close,
      once = true,
    })
  end

  local close_win = function()
    if vim.api.nvim_get_current_buf() ~= bufnr then
      return
    end
    if #vim.api.nvim_list_wins() == 1 then
      return vim.cmd('q!')
    end
    return pcall(vim.api.nvim_win_close, 0, true)
  end

  return function()
    vim.api.nvim_create_augroup('OrgTmpWindow', { clear = true })
    close_win()
    if prev_winnr and vim.api.nvim_win_is_valid(prev_winnr) then
      vim.api.nvim_set_current_win(prev_winnr)
    end
  end
end

---@param name string
---@param opts? table
function utils.open_float(name, opts)
  opts = opts or { scale = nil, border = nil }
  opts.scale = opts.scale or 0.7
  opts.border = opts.border or 'single'
  -- Make sure number is between 0 and 1
  local scale = math.min(math.max(0, opts.scale), 1)
  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, name)

  local width = math.floor((vim.o.columns * scale))
  local height = math.floor((vim.o.lines * scale))
  local row = math.floor((((vim.o.lines - height) / 2) - 1))
  local col = math.floor(((vim.o.columns - width) / 2))

  vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = opts.border,
  })
end

---@param str string
---@param amount number
function utils.pad_right(str, amount)
  local spaces = math.max(0, amount - vim.api.nvim_strwidth(str))
  if spaces == 0 then
    return str
  end
  return string.format('%s%s', str, string.rep(' ', spaces))
end

function utils.is_list(value)
  if vim.islist then
    return vim.islist(value)
  end
  return vim.tbl_islist(value)
end

---@param t table List-like table
---@return table Flattened copy of the given list-like table
function utils.flatten(t)
  local result = {}
  local function _tbl_flatten(_t)
    local n = #_t
    for i = 1, n do
      local v = _t[i]
      if type(v) == 'table' and utils.is_list(v) then
        _tbl_flatten(v)
      elseif v then
        table.insert(result, v)
      end
    end
  end
  _tbl_flatten(t)
  return result
end

---@param filename string
function utils.edit_file(filename)
  local buf_not_already_loaded = vim.fn.bufexists(filename) ~= 1
  local cur_win = vim.api.nvim_get_current_win()

  return {
    open = function()
      local bufnr = vim.fn.bufadd(filename) or -1
      vim.api.nvim_buf_set_var(bufnr, 'org_tmp_edit_window', true)
      vim.api.nvim_open_win(bufnr, true, {
        relative = 'editor',
        width = 1,
        -- TODO: Revert to 1 once the https://github.com/neovim/neovim/issues/19464 is fixed
        height = 2,
        row = 99999,
        col = 99999,
        zindex = 1,
        style = 'minimal',
      })
    end,
    close = function()
      vim.cmd('silent! w')
      vim.b.org_tmp_edit_window = nil
      if buf_not_already_loaded then
        vim.cmd('silent! bw!')
      else
        vim.cmd('silent! q!')
      end
      vim.api.nvim_set_current_win(cur_win)
    end,
  }
end

function utils.has_version_10()
  local v = vim.version()
  return not vim.version.lt({ v.major, v.minor, v.patch }, { 0, 10, 0 })
end

---@generic EntryType : any
---@param entries EntryType[]
---@param check_fn fun(entry: EntryType, index: number): boolean
---@return EntryType | nil
function utils.find(entries, check_fn)
  for i, entry in ipairs(entries) do
    if check_fn(entry, i) then
      return entry
    end
  end
  return nil
end

---@param name string
---@param skip_ftmatch? boolean
---@return string
function utils.detect_filetype(name, skip_ftmatch)
  local map = {
    ['emacs-lisp'] = 'lisp',
    js = 'javascript',
    ts = 'typescript',
    md = 'markdown',
    ex = 'elixir',
    pl = 'perl',
    sh = 'bash',
    uxn = 'uxntal',
  }
  if not skip_ftmatch then
    local filename = '__org__detect_filetype__.' .. (map[name] or name)
    local ft = vim.filetype.match({ filename = filename })
    if ft then
      return ft
    end
  end
  if map[name] then
    return map[name]
  end
  return name:lower()
end

---@param filename string
---@return boolean
function utils.is_org_file(filename)
  local ext = vim.fn.fnamemodify(filename, ':e')
  return ext == 'org' or ext == 'org_archive'
end

return utils
