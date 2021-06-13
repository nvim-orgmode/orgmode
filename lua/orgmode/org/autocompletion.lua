local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local utils = require('orgmode.utils')

local data = {
  directives = {'TITLE', 'AUTHOR', 'EMAIL', 'NAME', 'BEGIN_SRC', 'END_SRC', 'BEGIN_EXAMPLE', 'END_EXAMPLE', 'FILETAGS', 'ARCHIVE'},
  properties = {'PROPERTIES:', 'END:', 'LOGBOOK:', 'STYLE:', 'REPEAT_TO_STATE:', 'CUSTOM_ID:', 'CATEGORY:'},
  metadata = {'DEADLINE:', 'SCHEDULED:', 'CLOSED:'},
}

local all = {}
utils.concat(all, vim.tbl_map(function(i) return '#+'..i end, data.directives))
utils.concat(all, vim.tbl_map(function(i) return ':'..i end, data.properties))
utils.concat(all, data.metadata)

local Autocompletion = {}

local contexts = {
  { rgx = '^#%+(%w*)$', list = data.directives },
  { rgx = '^%s*:(%w*)$', list = data.properties },
  { rgx = '^%*+%s+(%w*)$', list = {}, fetcher = function() return config:get_todo_keywords().ALL end },
  { rgx = '^%s*%[%[[%*#]?(%w*)?', list = {} },
  { rgx = ':([%w_%%@#]*):?$', list = {}, fetcher = Files.get_tags },
  { rgx = '^%w+$', list = data.metadata },
  { rgx = '^%s*$', list = all }
}

function Autocompletion.omni(findstart, base)
  local line = vim.fn.getline('.'):sub(1, vim.fn.col('.'))
  if findstart == 1 then
    local word = line:find('%w*$')
    return word and word - 1 or 0
  end

  local whole_line = line..base
  local results = {}
  for _, context in ipairs(contexts) do
    if whole_line:find(context.rgx) then
      local items = {unpack(context.list)}
      if context.fetcher then
        items = context.fetcher()
      end

      items = vim.tbl_filter(function(i)
        return i:find('^'..vim.pesc(base))
      end, items)

      for _, item in ipairs(items) do
        table.insert(results, { word = item, menu = '[Org]'})
      end
    end
  end

  return results
end

return Autocompletion
