local ts_utils = require('nvim-treesitter.ts_utils')
local Promise = require('orgmode.utils.promise')
local uv = vim.loop
local utils = {}
local debounce_timers = {}
local query_cache = {}
local tmp_window_augroup = vim.api.nvim_create_augroup('OrgTmpWindow', { clear = true })

function utils.readfile(file, opts)
  opts = opts or {}
  return Promise.new(function(resolve, reject)
    uv.fs_open(file, 'r', 438, function(err1, fd)
      if err1 then
        return reject(err1)
      end
      uv.fs_fstat(fd, function(err2, stat)
        if err2 then
          return reject(err2)
        end
        uv.fs_read(fd, stat.size, 0, function(err3, data)
          if err3 then
            return reject(err3)
          end
          uv.fs_close(fd, function(err4)
            if err4 then
              return reject(err4)
            end
            if opts.raw then
              return resolve(data)
            end
            local lines = vim.split(data, '\n')
            table.remove(lines, #lines)
            return resolve(lines)
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
      uv.fs_fstat(fd, function(err2, stat)
        if err2 then
          return reject(err2)
        end
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
---@return table
function utils.reduce(tbl, callback, acc)
  for i, v in pairs(tbl) do
    acc = callback(acc, v, i)
  end
  return acc
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

---@class KeymapData
---@field mode string|table
---@field lhs string
---@field buffer integer?

---@param data KeymapData
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

---@param query string
---@param node TSNode
---@param file_content string[]
---@param file_content_str string
---@return table[]
function utils.get_ts_matches(query, node, file_content, file_content_str)
  local matches = {}
  local ts_query = query_cache[query]
  if not ts_query then
    ts_query = vim.treesitter.query.parse('org', query)
    query_cache[query] = ts_query
  end
  for _, match, _ in ts_query:iter_matches(node, file_content_str) do
    local items = {}
    for id, matched_node in pairs(match) do
      local name = ts_query.captures[id]
      local node_text = utils.get_node_text(matched_node, file_content)
      items[name] = {
        node = matched_node,
        text_list = node_text,
        text = node_text[1],
      }
    end
    table.insert(matches, items)
  end
  return matches
end

---@param node TSNode
---@param content string[]
---@return string[]
function utils.get_node_text(node, content)
  if not node then
    return {}
  end
  local start_row, start_col, end_row, end_col = node:range()

  if start_row ~= end_row then
    local start_line = start_row + 1
    local end_line = end_row + 1
    if end_col == 0 then
      end_line = end_row
    end
    local range = end_line - start_line + 1
    local lines = {}
    if range < 5000 then
      lines = { unpack(content, start_line, end_line) }
    else
      local chunks = math.floor(range / 5000)
      local leftover = range % 5000
      for i = 1, chunks do
        lines = utils.concat(lines, { unpack(content, (i - 1) * 5000 + 1, i * 5000) })
      end
      if leftover > 0 then
        local s = chunks * 5000
        lines = utils.concat(lines, { unpack(content, s + 1, s + leftover) })
      end
    end

    lines[1] = string.sub(lines[1], start_col + 1)
    if end_col > 0 then
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
    return lines
  else
    local line = content[start_row + 1]
    -- If line is nil then the line is empty
    return line and { string.sub(line, start_col + 1, end_col) } or {}
  end
end

---@param node TSNode
---@param type string
---@return TSNode | nil
function utils.get_closest_parent_of_type(node, type, accept_at_cursor)
  local parent = node

  if not accept_at_cursor then
    parent = node:parent()
  end

  while parent do
    if parent:type() == type then
      return parent
    end
    parent = parent:parent()
  end
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
  local start_time = os.clock()
  return function()
    return print(name, string.format('%.2f', os.clock() - start_time))
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

---@param items table
function utils.choose(items)
  items = items or {}

  local output = {}
  for _, item in ipairs(items) do
    table.insert(output, { '[' })
    table.insert(output, { item.choice_text, item.choice_hl or 'Normal' })
    table.insert(output, { ']' })

    if item.desc_text then
      table.insert(output, { ' ' })
      table.insert(output, { item.desc_text, item.desc_hl or 'Normal' })
    end

    table.insert(output, { '  ' })
  end

  table.insert(output, { '\n' })
  vim.api.nvim_echo(output, true, {})

  local raw = vim.fn.nr2char(vim.fn.getchar())
  local char = string.lower(raw)
  vim.cmd('redraw!')

  for _, item in ipairs(items) do
    if char == string.lower(item.choice_value) then
      return { choice_value = item.choice_value, choice_text = item.choice_text, raw = raw, ctx = item.ctx }
    end
  end
end

---@param file File
---@param parent_node TSNode
---@param children_names table<string, boolean>
---@return table
function utils.get_named_children_nodes(file, parent_node, children_names)
  local child_node_info = {}

  if children_names then
    -- Only grab information for specific named children
    for _, child_name in ipairs(children_names) do
      children_names[child_name] = false
    end
  end

  vim.tbl_map(function(node)
    if not children_names or children_names[node:type()] ~= nil then
      local text
      local text_list = utils.get_node_text(node, file.file_content)

      if #text_list == 0 then
        text = ''
      else
        text = text_list[1]
      end

      child_node_info[node:type()] = {
        node = node,
        text = text,
        text_list = text_list,
      }
    end
  end, ts_utils.get_named_children(parent_node))

  return child_node_info
end

---@param file File
---@param cursor string[]
---@param accept_at_cursor boolean
---@return nil|table
function utils.get_nearest_block_node(file, cursor, accept_at_cursor)
  local current_node = file:get_node_at_cursor(cursor)
  local block_node = utils.get_closest_parent_of_type(current_node, 'block', accept_at_cursor)
  if not block_node then
    return
  end

  -- Block might not have contents yet, which is fine
  local children_nodes = file:get_ts_matches(
    '(block name: (expr) @name parameter: (expr) @parameters contents: (contents)? @contents)',
    block_node
  )[1]
  if not children_nodes or not children_nodes.name or not children_nodes.parameters then
    return
  end

  return {
    node = block_node,
    children = children_nodes,
  }
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
  local winnr = vim.api.nvim_get_current_win()
  utils.open_window(vim.fn.tempname(), height or 16, split_mode, border)
  vim.cmd([[setf org]])
  vim.cmd([[setlocal bufhidden=wipe nobuflisted nolist noswapfile nofoldenable]])
  vim.api.nvim_buf_set_var(0, 'org_prev_window', winnr)

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

  return function()
    vim.api.nvim_create_augroup('OrgTmpWindow', { clear = true })
    local prev_winnr = vim.api.nvim_buf_get_var(0, 'org_prev_window')
    vim.api.nvim_win_close(0, true)
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
  local bufnr = vim.api.nvim_create_buf(false, true)
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
    style = 'minimal',
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

---@param filename string
function utils.edit_file(filename)
  local buf_not_already_loaded = vim.fn.bufexists(filename) ~= 1
  local cur_win = vim.api.nvim_get_current_win()

  return {
    open = function()
      local bufnr = vim.fn.bufadd(filename)
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
      if buf_not_already_loaded then
        vim.cmd('silent! bw!')
      else
        vim.cmd('silent! q!')
      end
      vim.api.nvim_set_current_win(cur_win)
    end,
  }
end

return utils
