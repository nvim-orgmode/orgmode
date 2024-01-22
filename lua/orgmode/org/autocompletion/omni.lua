local org = require('orgmode')
local config = require('orgmode.config')
local Hyperlinks = require('orgmode.org.hyperlinks')
local Url = require('orgmode.objects.url')

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
  line_rgx = vim.regex([[\(\(^\|\s\+\)\[\[\)\@<=\(\*\|#\|file:\)\?\(\(\w\|\/\|\.\|\\\|-\)\+\)\?]]),
  rgx = vim.regex([[\(\*\|#\|file:\)\?\(\(\w\|\/\|\.\|\\\|-\)\+\)\?$]]),
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
    end, org.files:get_tags() or {})
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
    end, org.files:get_tags() or {})
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

local Omni = {}

---@return string: the line before the current cursor position
function Omni.get_line_content_before_cursor()
  return vim.api.nvim_get_current_line():sub(1, vim.api.nvim_call_function('col', { '.' }) - 1)
end

function Omni.is_headline()
  return Omni.get_line_content_before_cursor():match('^%*+%s+')
end

---@return OrgTable
function Omni.get_all_contexts()
  return Omni.is_headline() and headline_contexts or contexts
end

---Determines an URL for link handling. Handles a couple of corner-cases
---@param base string The string to complete
---@return string
function Omni.get_url_str(line, base)
  local line_base = line:match('%[%[(.-)$') or line
  line_base = line_base:gsub(base .. '$', '')
  return (line_base or '') .. (base or '')
end

--- Is true and only true, if all given regex in the context match appropriatly
--- line_rgx and extra_cond are optional, but if the context defines them, they must match.
--- The basic rgx must always match the base, because it is used to determine the start position for
--- the completion.
---@param context table: the context candidate
---@param line string: characters left to the cursor
---@param base string: characters after the trigger (filter)
function Omni.all_ctx_conditions_apply(context, line, base)
  return (not context.line_rgx or context.line_rgx:match_str(line))
    and context.rgx:match_str(base)
    and (not context.extra_cond or context.extra_cond(line, base))
end

---@param base? string
---@return number
function Omni.find_start(base)
  local line = Omni.get_line_content_before_cursor()
  for _, context in ipairs(Omni.get_all_contexts()) do
    local word = context.rgx:match_str(line)
    if word and (not context.extra_cond or context.extra_cond(line, base)) then
      return word
    end
  end
  return -1
end

---@param base string
---@return table
function Omni.get_completions(base)
  -- Workaround for the corner case of matching custom_ids to file paths without file: prefix
  -- Bug is probably in the regex, but hard to fix, because the regex is so hard to read
  base = base:match('^:#') and base:gsub('^:', '') or base

  local line = Omni.get_line_content_before_cursor()
  local url = Url.new(Omni.get_url_str(line, base))
  local results = {}
  for _, context in ipairs(Omni.get_all_contexts()) do
    if Omni.all_ctx_conditions_apply(context, line, base) then
      local items = {}

      -- fetch or just take context specific completion candidates
      if context.fetcher then
        items = context.fetcher(url)
      else
        items = { unpack(context.list) }
      end

      -- incrementally limit candidates to what the user has already been typed
      items = vim.tbl_filter(function(i)
        return i:find('^' .. vim.pesc(base))
      end, items)

      -- craft the actual completion entries and append them to the overall results
      for _, item in ipairs(items) do
        table.insert(results, { word = item, menu = '[Org]' })
      end
    end
  end

  return results
end

function Omni.omnifunc(findstart, base)
  return findstart == 1 and Omni.find_start(base) or Omni.get_completions(base)
end

return Omni
