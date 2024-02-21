local has_cmp, cmp = pcall(require, 'cmp')
if not has_cmp then
  return
end

local org = require('orgmode')

local Source = {}

Source.new = function()
  local self = setmetatable({}, { __index = Source })
  return self
end

Source.get_debug_name = function()
  return 'orgmode'
end

function Source:is_available()
  return vim.bo.filetype == 'org'
end

function Source:get_trigger_characters(_)
  return { '#', '+', ':', '*', '.', '/' }
end

function Source:complete(params, callback)
  local offset = org.completion:get_start({ line = params.context.cursor_before_line }) + 1
  local base = string.sub(params.context.cursor_before_line, offset)
  local results = org.completion:complete({
    line = params.context.cursor_before_line,
    base = base,
  })
  local items = {}
  for _, item in ipairs(results) do
    table.insert(items, {
      label = item.word,
      labelDetails = {
        description = item.menu,
      },
    })
  end

  callback({
    items = items,
    isIncomplete = true,
  })
end

cmp.register_source('orgmode', Source.new())
