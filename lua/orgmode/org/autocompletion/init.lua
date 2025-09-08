---@class OrgCompletion
---@field files OrgFiles
---@field links OrgLinks
---@field private sources OrgCompletionSource[]
---@field private sources_by_name table<string, OrgCompletionSource>
---@field private fuzzy_match? boolean does completeopt has fuzzy option
---@field menu string
local OrgCompletion = {
  menu = '[Org]',
}
OrgCompletion.__index = OrgCompletion

---@param opts { files: OrgFiles, links: OrgLinks }
function OrgCompletion:new(opts)
  local this = setmetatable({
    files = opts.files,
    links = opts.links,
    sources = {},
    sources_by_name = {},
    fuzzy_match = vim.tbl_contains(vim.opt_local.completeopt:get(), 'fuzzy'),
  }, OrgCompletion)
  this:setup_builtin_sources()
  this:register_frameworks()
  return this
end

function OrgCompletion:setup_builtin_sources()
  self:add_source(require('orgmode.org.autocompletion.sources.todo_keywords'):new())
  self:add_source(require('orgmode.org.autocompletion.sources.tags'):new({ completion = self }))
  self:add_source(require('orgmode.org.autocompletion.sources.plan'):new({ completion = self }))
  self:add_source(require('orgmode.org.autocompletion.sources.directives'):new())
  self:add_source(require('orgmode.org.autocompletion.sources.properties'):new({ completion = self }))
  self:add_source(require('orgmode.org.autocompletion.sources.hyperlinks'):new({ completion = self }))
end

---@param source OrgCompletionSource
function OrgCompletion:add_source(source)
  if self.sources_by_name[source:get_name()] then
    error('Completion source ' .. source:get_name() .. ' already exists', 0)
  end
  self.sources_by_name[source:get_name()] = source
  table.insert(self.sources, source)
end

---@param context OrgCompletionContext
---@return OrgCompletionItem
function OrgCompletion:complete(context)
  local results = {}
  context.base = context.base or ''
  if not context.matcher then
    context.matcher = self:_build_matcher(context)
  end
  for _, source in ipairs(self.sources) do
    if source:get_start(context) then
      vim.list_extend(results, self:_get_valid_results(source:get_results(context), context))
    end
  end

  return results
end

---@param results string[]
---@param context OrgCompletionContext
---@return OrgCompletionItem[]
function OrgCompletion:_get_valid_results(results, context)
  local valid_results = {}
  for _, item in ipairs(results) do
    if context.matcher(item, context.base) then
      table.insert(valid_results, {
        word = item,
        menu = self.menu,
      })
    end
  end

  return valid_results
end

---@param context OrgCompletionContext
function OrgCompletion:get_start(context)
  for _, source in ipairs(self.sources) do
    local start = source:get_start(context)
    if start then
      return start
    end
  end

  return -1
end

function OrgCompletion:omnifunc(findstart, base)
  if findstart == 1 then
    self._context = { line = self:get_line() }
    return self:get_start(self._context)
  end

  self._context = self._context or { line = self:get_line() }
  self._context.base = base
  self._context.fuzzy = self.fuzzy_match
  return self:complete(self._context)
end

---@private
---@param context OrgCompletionContext
---@return fun(value: string, pattern: string):boolean
function OrgCompletion:_build_matcher(context)
  return function(value, pattern)
    pattern = pattern or ''
    if pattern == '' then
      return true
    end
    if context.fuzzy then
      return #vim.fn.matchfuzzy({ value }, pattern) > 0
    end
    return value:find('^' .. vim.pesc(pattern)) ~= nil
  end
end

function OrgCompletion:get_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return vim.api.nvim_get_current_line():sub(1, cursor[2])
end

---@param line string
function OrgCompletion:is_headline_line(line)
  return line:find([[^%*+%s+]]) ~= nil
end

function OrgCompletion:register_frameworks()
  require('orgmode.org.autocompletion.cmp')
end

---@param arg_lead string
---@return string[]
function OrgCompletion:complete_links_from_input(arg_lead)
  local context = {
    base = arg_lead,
    fuzzy = self.fuzzy_match,
  }
  context.matcher = self:_build_matcher(context)

  return self.links:autocomplete(context)
end

return OrgCompletion
