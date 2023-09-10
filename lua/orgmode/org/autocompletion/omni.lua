local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local Hyperlinks = require('orgmode.org.hyperlinks')
local Url = require('orgmode.objects.url')
local Link = require('orgmode.objects.link')

local data = {
  directives = { '#+title', '#+author', '#+email', '#+name', '#+filetags', '#+archive', '#+options', '#+category' },
  begin_blocks = { '#+begin_src', '#+end_src', '#+begin_example', '#+end_example' },
  properties = { ':PROPERTIES:', ':END:', ':LOGBOOK:', ':STYLE:', ':REPEAT_TO_STATE:', ':CUSTOM_ID:', ':CATEGORY:' },
  metadata = { 'DEADLINE:', 'SCHEDULED:', 'CLOSED:' },
}

local directives = {
  line_rgx = vim.regex([[^\#\?+\?\w*$]]),
  rgx = vim.regex([[^\#+\?\w*$]]),
  list = data.directives,
}

local begin_blocks = {
  line_rgx = vim.regex([[^\s*\#\?+\?\w*$]]),
  rgx = vim.regex([[\(^\s*\)\@<=\#+\?\w*$]]),
  list = data.begin_blocks,
}

local properties = {
  line_rgx = vim.regex([[\(^\s\+\|^\s*:\?$\)]]),
  rgx = vim.regex([[\(^\|^\s\+\)\@<=:\w*$]]),
  extra_cond = function(line, _)
    return not string.find(line, 'file:.*$')
  end,
  list = data.properties,
}

local links = {
  line_rgx = vim.regex([[\(\(^\|\s\+\)\[\[\)\@<=\(\*\|\#\|file:\)\?\(\(\w\|\/\|\.\|\\\|-\|_\|\d\)\+\)\?]]),
  rgx = vim.regex([[\(\*\|\#\|file:\)\?\(\(\w\|\/\|\.\|\\\|-\|_\|\d\)\+\)\?$]]),
  fetcher = function(url)
    local hyperlinks, mapper = Hyperlinks.find_matching_links(url)
    return mapper(hyperlinks)
  end,
}

local metadata = {
  rgx = vim.regex([[\(\s*\)\@<=\w\+$]]),
  list = data.metadata,
}

local tags = {
  rgx = vim.regex([[:\([0-9A-Za-z_%@\#]*\)$]]),
  fetcher = function()
    return vim.tbl_map(function(tag)
      return ':' .. tag .. ':'
    end, Files.get_tags())
  end,
}

local filetags = {
  line_rgx = vim.regex([[\c^\#+filetags:\s\+]]),
  rgx = vim.regex([[:\([0-9A-Za-z_%@\#]*\)$]]),
  extra_cond = function(line, _)
    return not string.find(line, 'file:.*$')
  end,
  fetcher = function()
    return vim.tbl_map(function(tag)
      return ':' .. tag .. ':'
    end, Files.get_tags())
  end,
}

local todo_keywords = {
  line_rgx = vim.regex([[^\*\+\s\+\w*$]]),
  rgx = vim.regex([[\(^\(\*\+\s\+\)\?\)\@<=\w*$]]),
  fetcher = function()
    return config:get_todo_keywords().ALL
  end,
}

local contexts = {
  directives,
  begin_blocks,
  filetags,
  properties,
  links,
  metadata,
}

local headline_contexts = {
  tags,
  links,
  todo_keywords,
}

--- This function is registered to omnicompletion in ftplugin/org.vim.
---
--- If the user want to use it in his completion plugin (like cmp) he has to do
--- that in the configuration of that plugin.
---@return table
local function omni(findstart, base)
  local line = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_call_function('col', { '.' }) - 1)
  local is_headline = line:match('^%*+%s+')
  local ctx = is_headline and headline_contexts or contexts
  if findstart == 1 then
    for _, context in ipairs(ctx) do
      local word = context.rgx:match_str(line)
      if word and (not context.extra_cond or context.extra_cond(line, base)) then
        return word
      end
    end
    return -1
  end

  -- The function omni gets called twice when used by omnicompletion but when
  -- used by cmp it is called differently.
  -- TODO Refactoring is actually needed to make this more reliable
  local line_base = line:match('%[%[(.-)$')
  local url_str
  if base:match('^file:') then
    -- when linking to another file the prefix is also part of base, when called
    -- from cmp because when called from omnifunc it is already cut out, we need
    -- to clean it up
    url_str = base:gsub('^file:', '')
  elseif line_base == base then
    -- when linking to an internal anchor and called by cmp plugin
    url_str = base
  else
    -- typically when linking to a headline within another file the information
    -- we need for completion is split between line_base and base
    url_str = (line_base or '') .. (base or '')
  end

  local url = Url.new(url_str)
  local results = {}

  for _, context in ipairs(ctx) do
    if
      (not context.line_rgx or context.line_rgx:match_str(line))
      and context.rgx:match_str(base)
      and (not context.extra_cond or context.extra_cond(line, base))
    then
      local items = {}
      if context.fetcher then
        items = context.fetcher(url)
      else
        items = { unpack(context.list) }
      end

      items = vim.tbl_filter(function(i)
        return i:find('^' .. vim.pesc(base))
      end, items)

      for _, item in ipairs(items) do
        table.insert(results, { word = item, menu = '[Org]' })
      end
    end
  end

  return results
end

return omni
