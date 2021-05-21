local uv = vim.loop
local utils = {}

---@param file string
---@param callback function
function utils.readfile(file, callback)
  uv.fs_open(file, 'r', 438, function(err1, fd)
    if err1 then return callback(err1) end
    uv.fs_fstat(fd, function(err2, stat)
    if err2 then return callback(err2) end
      uv.fs_read(fd, stat.size, 0, function(err3, data)
        if err3 then return callback(err3) end
        uv.fs_close(fd, function(err4)
          if err4 then return callback(err4) end
          local lines = vim.split(data, '\n')
          table.remove(lines, #lines)
          return callback(nil, lines)
        end)
      end)
    end)
  end)
end

---@param msg string
function utils.echo_warning(msg)
  vim.cmd[[echohl WarningMsg]]
  vim.cmd('echom '..msg)
  vim.cmd[[echohl None]]
end

---@param word string
---@return string
function utils.capitalize(word)
  return (word:gsub('^%l', string.upper))
end

---@param isoweekday number
---@return number
function utils.convert_from_isoweekday(isoweekday)
  if isoweekday == 7 then return 1 end
  return isoweekday + 1
end

---@param weekday number
---@return number
function utils.convert_to_isoweekday(weekday)
  if weekday == 1 then return 7 end
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

---@param highlights table[]
---@return string
function utils.highlight(highlights)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(0, 0, hl.hlgroup, hl.line, hl.from, hl.to)
  end
end

-- Temporary test
function utils.capture_menu()
  return utils.menu('Select template:', {
    { label = 'Da', key = 'd' },
    { label = 'Ne', key = 'n' },
    { label = '', key = '', separator = true },
    { label = 'Abort', key = 'q', action = false },
  })
end

function utils.menu(title, items)
  local content = { title, vim.fn['repeat']('=', title:len()) }
  local valid_keys = {}
  for _, item in ipairs(items) do
    if item.separator then
      table.insert(content, vim.fn['repeat']('-', 80))
    else
      valid_keys[item.key] = item
      table.insert(content, string.format('%s) %s', item.key, item.label))
    end
  end
  table.insert(content ,'key: \n')
  vim.api.nvim_out_write(table.concat(content, '\n'))
  local char = vim.fn.nr2char(vim.fn.getchar())
  vim.cmd[[redraw!]]
  local entry = valid_keys[char]
  if not entry or not entry.action then return end
  return entry.action()
end

return utils
