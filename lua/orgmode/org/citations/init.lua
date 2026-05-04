local ts_utils = require('orgmode.utils.treesitter')

---@class OrgCitations
---@field private sources OrgCitationSource[]
---@field private sources_by_name table<string, OrgCitationSource>
---@field private files OrgFiles | nil
local OrgCitations = {}
OrgCitations.__index = OrgCitations

---@param opts? { files?: OrgFiles }
function OrgCitations:new(opts)
  opts = opts or {}
  local this = setmetatable({
    sources = {},
    sources_by_name = {},
    files = opts.files,
  }, OrgCitations)
  this:_setup_builtin_sources()
  this:_add_custom_sources()
  return this
end

---@param source OrgCitationSource
function OrgCitations:add_source(source)
  if self.sources_by_name[source:get_name()] then
    error('Citation source ' .. source:get_name() .. ' already exists', 0)
  end
  self.sources_by_name[source:get_name()] = source
  table.insert(self.sources, source)
end

---@return OrgCitationItem[]
function OrgCitations:get_items()
  local items = {}
  for _, source in ipairs(self.sources) do
    vim.list_extend(items, source:get_items())
  end
  return items
end

---@param key string
---@return boolean
function OrgCitations:follow(key)
  for _, source in ipairs(self.sources) do
    if source.follow and source:follow(key) then
      return true
    end
  end
  return false
end

---@return string | nil
function OrgCitations:at_cursor()
  local node = ts_utils.closest_node(ts_utils.get_node(), { 'citation_reference' })
  if not node then
    return nil
  end
  local key_node = node:field('key')[1]
  if not key_node then
    return nil
  end
  return vim.treesitter.get_node_text(key_node, 0)
end

---@private
function OrgCitations:_setup_builtin_sources()
  self:add_source(require('orgmode.org.citations.bibtex'):new({ files = self.files }))
end

---@private
function OrgCitations:_add_custom_sources()
  local config = require('orgmode.config')
  for i, source in ipairs(config.citations.sources) do
    if type(source.get_name) == 'function' then
      self:add_source(source)
    else
      vim.notify(('Citation source at index %d must have a get_name method'):format(i), vim.log.levels.ERROR)
    end
  end
end

return OrgCitations
