local ts = require('vim.treesitter.query')
local uv = vim.loop
local utils = {}

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
function utils.echo_warning(msg, additional_msg)
  return utils._echo(msg, 'WarningMsg', additional_msg)
end

---@param msg string
---@param additional_msg table
function utils.echo_error(msg, additional_msg)
  return utils._echo(msg, 'ErrorMsg', additional_msg)
end

---@param msg string
---@param additional_msg table
function utils.echo_info(msg, additional_msg)
  return utils._echo(msg, nil, additional_msg)
end

---@private
function utils._echo(msg, hl, additional_msg)
  vim.cmd([[redraw!]])
  local msg_item = { string.format('[orgmode] %s', msg) }
  if hl then
    table.insert(msg_item, hl)
  end
  local msg_list = { msg_item }
  if additional_msg then
    msg_list = utils.concat(msg_list, additional_msg)
  end
  return vim.api.nvim_echo(msg_list, true, {})
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
---@param file_content string
---@return table[]
function utils.get_ts_matches(query, node, file_content)
  local matches = {}
  local ts_query = ts.parse_query('org', query)
  for _, match, _ in ts_query:iter_matches(node, file_content) do
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

function utils.get_node_text(node, content)
  if not node then
    return {}
  end
  local all_lines = vim.split(content, '\n', true)
  local start_row, start_col, end_row, end_col = node:range()

  if start_row ~= end_row then
    local start_line = start_row + 1
    local end_line = end_row + 1
    if end_col == 0 then
      end_line = end_row
    end
    local lines = { unpack(all_lines, start_line, end_line) }
    lines[1] = string.sub(lines[1], start_col + 1)
    if end_col > 0 then
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
    return lines
  else
    local line = all_lines[start_row + 1]
    -- If line is nil then the line is empty
    return line and { string.sub(line, start_col + 1, end_col) } or {}
  end
end

return utils
