local utils = require('orgmode.utils')
local Org = require('orgmode')
local Internal = require('orgmode.org.hyperlinks.builtin.internal')

---@class OrgLinkPlain:OrgLinkInternal
local Plain = Internal:new()

function Plain:new(text)
  ---@class OrgLinkPlain
  local this = Internal:new()
  this.text = text
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function Plain.parse(input)
  return Plain:new(input)
end

function Plain:__tostring()
  return self.text
end

function Plain:follow()
  local anchors = vim.fn.matchbufline(0, ('<<<?%s[^>]*>>>?'):format(self.text), 0, '$')

  if #anchors >= 1 then
    vim.fn.cursor(anchors[1].lnum, anchors[1].byteidx)
    return
  end

  -- TODO from here, behaviour should depend on org-link-search-must-match-exact-headline
  -- TODO #+NAME tag support should be added, but it didn't exists yet

  local plain_text_matches = vim.fn.matchbufline(0, self.text, 0, '$')

  if #plain_text_matches >= 1 then
    vim.fn.cursor(plain_text_matches[1].lnum, plain_text_matches[1].byteidx)
    return
  end

  return utils.echo_warning(('No matches found for "%s".'):format(self.text))
end

function Plain:insert_description()
  return self.text
end

-- TODO #+NAME tag support should be added, but it didn't exists yet
function Plain:complete(lead, context)
  local file = self.get_file_from_context(context)
  local completions = {}

  local anchors = file.content:gmatch(('<<<?%s[^>]*>>>?'):format(lead))
  for anchor in anchors do
    table.insert(completions, Plain:new(anchor))
  end

  local headlines = file:find_headlines_by_title(lead)
  for _, headline in pairs(headlines) do
    table.insert(completions, Plain:new(headline:get_title()))
  end

  return completions
end

return Plain
