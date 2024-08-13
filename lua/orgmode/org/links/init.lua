local utils = require('orgmode.utils')
local Link = require('orgmode.org.links.link_handler')

---@class OrgLinkHandlerRegistry
---@field private internal OrgLinkHandler
---@field private handlers OrgLinkHandler[]
---@field private handlers_by_name table<string, OrgLinkHandler>
---@field private stored_links OrgLinkHandler[]
local OrgLinkHandlerRegistry = {}
OrgLinkHandlerRegistry.__index = OrgLinkHandlerRegistry

-- Using `linkword` definition as defined in https://orgmode.org/org.pdf#Link%20Abbreviations
local protocol_deliniator_pattern = '^[a-z][a-z0-9-_]+:'

function OrgLinkHandlerRegistry:new(opts)
  local this = setmetatable({
    internal = nil,
    handlers = {},
    handlers_by_name = {},
    stored_links = {},
  }, self)
  self.__index = self
  this:setup_builtin_handlers()
end

function OrgLinkHandlerRegistry:setup_builtin_handlers()
  self:add_handler(require('orgmode.org.links.handlers.file'))
  self:add_handler(require('orgmode.org.links.handlers.http'))
  self:add_handler(require('orgmode.org.links.handlers.https'))
  self:add_handler(require('orgmode.org.links.handlers.id'))
  self.internal = require('orgmode.org.links.handlers.internal')
end

---@param handler OrgLinkHandler
function OrgLinkHandlerRegistry:add_handler(handler)
  if self.handlers_by_name[handler.protocol] then
    error('Completion handler ' .. handler.protocol .. ' already exists')
  end

  -- Ensure that all handlers have defaults for the methods we rely on.
  for k, v in pairs(Link) do
    handler[k] = handler[k] or v
  end

  self.handlers_by_name[handler.protocol] = handler
  table.insert(self.handlers, handler)
end

function OrgLinkHandlerRegistry:parse(input)
  -- Finds protocol_deliniator
  local _, protocol_deliniator = input:find(protocol_deliniator_pattern)

  -- If no protocol is specified, fall back to internal links
  if protocol_deliniator == nil then
    return self.internal.parse(input)
  end

  local protocol = input:sub(1, protocol_deliniator - 1)
  local handler = self.handlers_by_name[protocol]

  -- No handler is registered for this protocol, so we don't support it
  if not handler then
    return nil
  end

  local target = input:sub(protocol_deliniator + 1)
  return handler.parse(target)
end

local function filter_by_prefix(lead)
  return function(needle)
    if lead == '' or needle:find('^' .. lead) then
      return true
    end
    return false
  end
end

function OrgLinkHandlerRegistry:complete(lead)
  if not lead then
    return {}
  end

  local _, protocol_deliniator = lead:find(protocol_deliniator_pattern)
  local completions = {}

  if not protocol_deliniator_pattern then
    completions = self:_complete_no_protocol(lead)
  else
    local protocol = lead:sub(1, protocol_deliniator - 1)
    lead = lead:sub(protocol_deliniator + 1)
    completions = self:_complete_protocol(protocol, lead)
  end

  return utils.concat(completions, self:_complete_stored_links(lead))
end

function OrgLinkHandlerRegistry:_complete_stored_links(lead)
  local stored_strings = vim.tbl_map(function(link)
    return link:__tostring()
  end, self.stored_links)

  return vim.tbl_filter(filter_by_prefix(lead), stored_strings)
end

function OrgLinkHandlerRegistry:_complete_protocol(protocol, lead)
  local handler = self.handlers_by_name[protocol]

  if handler then
    return handler:complete(lead)
  end

  return {}
end

function OrgLinkHandlerRegistry:_complete_no_protocol(lead)
  local completions = {}

  -- Completions for the different protocols
  completions = utils.concat(completions, vim.tbl_filter(filter_by_prefix(lead), vim.tbl_keys(self.handlers_by_name)))

  return utils.concat(completions, self.internal:complete(lead))
end

---@param link OrgLinkHandler
function OrgLinkHandlerRegistry:store_link(link)
  table.insert(self.stored_links, link)
end

return OrgLinkHandlerRegistry
