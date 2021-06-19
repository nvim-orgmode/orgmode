local compe = require('compe')
local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local utils = require('orgmode.utils')

local data = {
  directives = {'#+TITLE', '#+AUTHOR', '#+EMAIL', '#+NAME', '#+BEGIN_SRC', '#+END_SRC', '#+BEGIN_EXAMPLE', '#+END_EXAMPLE', '#+FILETAGS', '#+ARCHIVE'},
  properties = {':PROPERTIES:', ':END:', ':LOGBOOK:', ':STYLE:', ':REPEAT_TO_STATE:', ':CUSTOM_ID:', ':CATEGORY:'},
  metadata = {'DEADLINE:', 'SCHEDULED:', 'CLOSED:'},
}

local function find_by_custom_id_property(base)
  local headlines = Files.find_headlines_with_property_matching('CUSTOM_ID', base:sub(2))
  return vim.tbl_map(function(headline)
    return '#'..headline.properties.items.CUSTOM_ID
  end, headlines)
end

local function find_by_title_pointer(base)
  local headlines = Files.find_headlines_by_title(base:sub(2))
  return vim.tbl_map(function(headline)
    return '*'..headline.title
  end, headlines)
end

local function find_by_dedicated_target(base)
  if not base or base == '' then return {} end
  local term = string.format('<<(%s[^>]*)>>', base):lower()
  local headlines = Files.find_headlines_matching_search_term(term, true)
  local targets = {}
  for _, headline in ipairs(headlines) do
    for m in headline.title:lower():gmatch(term) do
      table.insert(targets, m)
    end
    for _, content in ipairs(headline.content) do
    for m in content.line:lower():gmatch(term) do
      table.insert(targets, m)
    end
    end
  end
  return targets
end

local function find_by_title(base)
  if not base or base == '' then return {} end
  local headlines = Files.find_headlines_by_title(base:sub(1, 1))
  return vim.tbl_map(function(headline)
    return headline.title
  end, headlines)
end

local function find_matching_links(base)
  base = vim.trim(base)
  local prefix = base:sub(1, 1)
  if prefix == '#' then
    return find_by_custom_id_property(base)
  end

  if prefix == '*' then
    return find_by_title_pointer(base)
  end

  local results = find_by_dedicated_target(base)
  local all = utils.concat(results, find_by_title(base))
  return all
end

local Autocompletion = {}

local directives = { rgx = vim.regex([[^\#+\?\w*$]]), line_rgx = vim.regex([[^\#\?+\?\w*$]]), list = data.directives }
local properties = { rgx = vim.regex([[\(^\s*\)\@<=:\w*$]]), list = data.properties }
local links = {
  line_rgx = vim.regex([[\(\(^\|\s\+\)\[\[\)\@<=\(\*\|\#\)\?\(\w\+\)\?]]),
  rgx = vim.regex([[\(\*\|\#\)\?\(\w\+\)\?$]]),
  fetcher = find_matching_links,
}
local metadata = { rgx = vim.regex([[\(\s*\)\@<=\w\+$]]), list = data.metadata }
local tags = {
  rgx = vim.regex([[:\([0-9A-Za-z_%@\#]*\)$]]),
  fetcher = function()
    return vim.tbl_map(function(tag)
      return ':'..tag..':'
    end, Files.get_tags())
  end,
}
local todo_keywords = {
  rgx = vim.regex([[\(^\(\*\+\s\+\)\?\)\@<=\w*$]]),
  line_rgx = vim.regex([[^\*\+\s\+\w*$]]),
  fetcher = function()
    return config:get_todo_keywords().ALL
  end,
}

local contexts = {
  directives,
  properties,
  links,
  metadata,
}

local headline_contexts = {
  tags,
  links,
  todo_keywords,
}

function Autocompletion.omni(findstart, base)
  local line = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_call_function('col', {'.'}) - 1)
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
    if (not context.line_rgx or context.line_rgx:match_str(line)) and context.rgx:match_str(base) then
      local items = {}
      if context.fetcher then
        items = context.fetcher(base)
      else
        items = {unpack(context.list)}
      end

      items = vim.tbl_filter(function(i)
        return i:find('^'..vim.pesc(base))
      end, items)

      for _, item in ipairs(items) do
        table.insert(results, { word = item, menu = '[Org]' })
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
    priority = 999,
    sort = false,
    dup = 0,
    filetypes = {'org'},
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
