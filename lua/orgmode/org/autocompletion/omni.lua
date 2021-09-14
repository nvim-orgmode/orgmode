local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local Hyperlinks = require('orgmode.org.hyperlinks')

local data = {
  directives = { '#+title', '#+author', '#+email', '#+name', '#+filetags', '#+archive', '#+options'  },
  begin_blocks = { '#+begin_src', '#+end_src', '#+begin_example', '#+end_example' },
  properties = { ':PROPERTIES:', ':END:', ':LOGBOOK:', ':STYLE:', ':REPEAT_TO_STATE:', ':CUSTOM_ID:', ':CATEGORY:' },
  metadata = { 'DEADLINE:', 'SCHEDULED:', 'CLOSED:' },
}

local directives = { rgx = vim.regex([[^\#+\?\w*$]]), line_rgx = vim.regex([[^\#\?+\?\w*$]]), list = data.directives }
local begin_blocks = {
  rgx = vim.regex([[\(^\s*\)\@<=\#+\?\w*$]]),
  line_rgx = vim.regex([[^\s*\#\?+\?\w*$]]),
  list = data.begin_blocks,
}
local properties = {
  line_rgx = vim.regex([[\(^\s\+\|^\s*:\?$\)]]),
  rgx = vim.regex([[\(^\|^\s\+\)\@<=:\w*$]]),
  list = data.properties,
}
local links = {
  line_rgx = vim.regex([[\(\(^\|\s\+\)\[\[\)\@<=\(\*\|\#\)\?\(\w\+\)\?]]),
  rgx = vim.regex([[\(\*\|\#\)\?\(\w\+\)\?$]]),
  fetcher = Hyperlinks.find_matching_links,
}
local metadata = { rgx = vim.regex([[\(\s*\)\@<=\w\+$]]), list = data.metadata }
local tags = {
  rgx = vim.regex([[:\([0-9A-Za-z_%@\#]*\)$]]),
  fetcher = function()
    return vim.tbl_map(function(tag)
      return ':' .. tag .. ':'
    end, Files.get_tags())
  end,
}

local filetags = {
  line_rgx = vim.regex([[\c^\#+FILETAGS:\s\+]]),
  rgx = vim.regex([[:\([0-9A-Za-z_%@\#]*\)$]]),
  fetcher = function()
    return vim.tbl_map(function(tag)
      return ':' .. tag .. ':'
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

local function omni(findstart, base)
  local line = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_call_function('col', { '.' }) - 1)
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
