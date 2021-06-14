local compe = require('compe')
local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local utils = require('orgmode.utils')

local data = {
  directives = {'#+TITLE', '#+AUTHOR', '#+EMAIL', '#+NAME', '#+BEGIN_SRC', '#+END_SRC', '#+BEGIN_EXAMPLE', '#+END_EXAMPLE', '#+FILETAGS', '#+ARCHIVE'},
  properties = {':PROPERTIES:', ':END:', ':LOGBOOK:', ':STYLE:', ':REPEAT_TO_STATE:', ':CUSTOM_ID:', ':CATEGORY:'},
  metadata = {'DEADLINE:', 'SCHEDULED:', 'CLOSED:'},
}

local all = {}
utils.concat(all, data.directives)
utils.concat(all, data.properties)
utils.concat(all, data.metadata)

local indentable = {}
utils.concat(indentable, data.properties)
utils.concat(indentable, data.metadata)

local Autocompletion = {}

local directives = { rgx = vim.regex([[^\#+\?\w*$]]), list = data.directives }
local properties = { rgx = vim.regex([[\(^\s*\)\@<=:\w*$]]), list = data.properties }
local links = { rgx = vim.regex([[\(\(^\|\s+\)\[\[\)\@<=\(\(\*\|\#\)\?\(\w+\)\)?]]), list = {} }
local tags = {
  rgx = vim.regex([[:\([\w_%@\#]*\)$]]),
  only_headline = true,
  fetcher = function()
    return vim.tbl_map(function(tag)
      return ':'..tag..':'
    end, Files.get_tags())
  end,
}
local todo_keywords = { rgx = vim.regex([[\(^\(\*\+\s\+\)\?\)\@<=\w*$]]), fetcher = function() return config:get_todo_keywords().ALL end }
local all_items = { rgx = vim.regex([[^$]]), list = all }

local contexts = {
  directives,
  properties,
  links,
  all_items
}

local headline_contexts = {
  tags,
  links,
  todo_keywords,
}

function Autocompletion.omni(findstart, base)
  local line = vim.fn.getline('.'):sub(1, vim.fn.col('.'))
  local is_headline = line:match('^%*+%s+')
  local ctx = is_headline and headline_contexts or contexts
  if findstart == 1 then
    for _, context in ipairs(ctx) do
      local word = context.rgx:match_str(line)
      if word then
        return word
      end
    end
    return -1
  end

  local results = {}
  for _, context in ipairs(ctx) do
    if context.rgx:match_str(base) then
      local items = {}
      if context.fetcher then
        items = context.fetcher()
      else
        items = {unpack(context.list)}
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

local Source = {}

function Source.new()
  return setmetatable({}, { __index = Source })
end

function Source.get_metadata()
  return {
    priority = 999;
    menu = '[Org]',
  }
end

function Source.determine(_, context)
  local offset = Autocompletion.omni(1, '') + 1
  if offset > 0 then
    return {
      keyword_pattern_offset = offset,
      trigger_character_offset = vim.tbl_contains({'#', '+', ':', '*'}, context.before_char) and context.col or 0
    }
  end
end

function Source.complete(_, context)
  local items = Autocompletion.omni(0, context.input)
  context.callback({
    items = items,
    incomplete = true
  })
end

-- Register your custom source.
compe.register_source('orgmode', Source)

return Autocompletion
