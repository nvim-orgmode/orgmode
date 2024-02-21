---@class OrgCompletion
---@field files OrgFiles
---@field private sources OrgCompletionSource[]
---@field private sources_by_name table<string, OrgCompletionSource>
---@field menu string
local OrgCompletion = {
  menu = '[Org]',
}
OrgCompletion.__index = OrgCompletion

---@param opts { files: OrgFiles }
function OrgCompletion:new(opts)
  local this = setmetatable({
    files = opts.files,
    sources = {},
    sources_by_name = {},
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
    error('Completion source ' .. source:get_name() .. ' already exists')
  end
  self.sources_by_name[source:get_name()] = source
  table.insert(self.sources, source)
end

---@param context OrgCompletionContext
---@return OrgCompletionItem
function OrgCompletion:complete(context)
  local results = {}
  for _, source in ipairs(self.sources) do
    if source:get_start(context) then
      vim.list_extend(results, self:_get_valid_results(source:get_results(context), context))
    end
  end

  return results
end

function OrgCompletion:_get_valid_results(results, context)
  local base = context.base or ''

  local valid_results = {}
  for _, item in ipairs(results) do
    if base == '' or item:find('^' .. vim.pesc(base)) then
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
  return self:complete(self._context)
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

return OrgCompletion
