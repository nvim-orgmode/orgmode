local ts = require('vim.treesitter.query')
local ts_utils = require('nvim-treesitter.ts_utils')
local Promise = require('orgmode.utils.promise')
local uv = vim.loop
local utils = {}
local debounce_timers = {}
local query_cache = {}

---@param file string
---@param callback function
---@param as_string boolean
function utils.readfile(file, callback, as_string)
  uv.fs_open(file, 'r', 438, function(err1, fd)
    if err1 then
      return callback(err1)
    end
    uv.fs_fstat(fd, function(err2, stat)
      if err2 then
        return callback(err2)
      end
      uv.fs_read(fd, stat.size, 0, function(err3, data)
        if err3 then
          return callback(err3)
        end
        uv.fs_close(fd, function(err4)
          if err4 then
            return callback(err4)
          end
          local lines = data
          if not as_string then
            lines = vim.split(data, '\n')
            table.remove(lines, #lines)
          end
          return callback(nil, lines)
        end)
      end)
    end)
  end)
end

function utils.open(target)
  if vim.fn.executable('xdg-open') then
    return vim.fn.system(string.format('xdg-open %s', target))
  end

  if vim.fn.executable('open') then
    return vim.fn.system(string.format('open %s', target))
  end

  if vim.fn.has('win32') then
    return vim.fn.system(string.format('start "%s"', target))
  end
end

---@param msg string
---@param additional_msg table
---@param store_in_history boolean
function utils.echo_warning(msg, additional_msg, store_in_history)
  return utils._echo(msg, 'WarningMsg', additional_msg, store_in_history)
end

---@param msg string
---@param additional_msg table
---@param store_in_history boolean
function utils.echo_error(msg, additional_msg, store_in_history)
  return utils._echo(msg, 'ErrorMsg', additional_msg, store_in_history)
end

---@param msg string
---@param additional_msg table
---@param store_in_history boolean
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
---@param unique boolean
---@return table
function utils.concat(first, second, unique)
  for _, v in ipairs(second) do
    if not unique or not vim.tbl_contains(first, v) then
      table.insert(first, v)
    end
  end
  return first
end

function utils.menu(title, items, prompt)
  local content = { title .. ':' }
  local valid_keys = {}
  for _, item in ipairs(items) do
    if item.separator then
      table.insert(content, string.rep(item.separator or '-', item.length or 80))
    else
      valid_keys[item.key] = item
      table.insert(content, string.format('%s %s', item.key, item.label))
    end
  end
  prompt = prompt or 'key'
  table.insert(content, prompt .. ': ')
  vim.cmd(string.format('echon "%s"', table.concat(content, '\\n')))
  local char = vim.fn.nr2char(vim.fn.getchar())
  vim.cmd([[redraw!]])
  local entry = valid_keys[char]
  if not entry or not entry.action then
    return
  end
  return entry.action()
end

function utils.keymap(mode, lhs, rhs, opts)
  return vim.api.nvim_set_keymap(
    mode,
    lhs,
    rhs,
    vim.tbl_extend('keep', opts or {}, {
      nowait = true,
      silent = true,
      noremap = true,
    })
  )
end

function utils.buf_keymap(buf, mode, lhs, rhs, opts)
  return vim.api.nvim_buf_set_keymap(
    buf,
    mode,
    lhs,
    rhs,
    vim.tbl_extend('keep', opts or {}, {
      nowait = true,
      silent = true,
      noremap = true,
    })
  )
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
---@param node table
---@param file_content string[]
---@param file_content_str string
---@return table[]
function utils.get_ts_matches(query, node, file_content, file_content_str)
  local matches = {}
  local ts_query = query_cache[query]
  if not ts_query then
    ts_query = ts.parse_query('org', query)
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

---@param node userdata
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

---@param node table
---@param type string
---@return table
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
---@param split_chars string[]
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

---@param fn function
---@return Promise
function utils.promisify(fn)
  if getmetatable(fn) ~= Promise then
    return Promise.resolve(fn)
  end
  return fn
end

---@param file File
---@param parent_node userdata
---@param children_names string[]
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

return utils
