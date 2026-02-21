local config = require('orgmode.config')
local fs = require('orgmode.utils.fs')
local utils = require('orgmode.utils')
local Menu = require('orgmode.ui.menu')
local State = require('orgmode.state.state')
local Promise = require('orgmode.utils.promise')

local M = {}

---Return true if the URI should be fetched.
---@param uri string
---@return OrgPromise<boolean> safe
function M.should_fetch(uri)
  local policy = config.org_resource_download_policy
  return Promise.resolve(policy == 'always' or M.is_uri_safe(uri)):next(function(safe)
    if safe then
      return true
    end
    if policy == 'prompt' then
      return M.confirm_safe(uri)
    end
    return false
  end)
end

---@param resource_uri string
---@param file_uri string | false
---@param patterns string[]
---@return boolean matches
local function check_patterns(resource_uri, file_uri, patterns)
  for _, pattern in ipairs(patterns) do
    local re = vim.regex(pattern)
    if re:match_str(resource_uri) or (file_uri and re:match_str(file_uri)) then
      return true
    end
  end
  return false
end

---Check the uri matches any of the (configured or cached) safe patterns.
---@param uri string
---@return OrgPromise<boolean> safe
function M.is_uri_safe(uri)
  local current_file = fs.get_real_path(utils.current_file_path())
  ---@type string | false # deduced type is `string | boolean`
  local file_uri = current_file and vim.uri_from_fname(current_file) or false
  local uri_patterns = {}
  if config.org_safe_remote_resources then
    vim.list_extend(uri_patterns, config.org_safe_remote_resources)
  end
  return State:load():next(function(state)
    local cached = state['org_safe_remote_resources']
    if cached then
      vim.list_extend(uri_patterns, cached)
    end
    return check_patterns(uri, file_uri, uri_patterns)
  end)
end

---@param uri string
---@return string escaped
local function uri_to_pattern(uri)
  -- Escape backslashes, disable magic characters, anchor front and back of the
  -- pattern.
  return string.format([[\V\^%s\$]], uri:gsub([[\]], [[\\]]))
end

---@param filename string
---@return string escaped
local function filename_to_pattern(filename)
  return uri_to_pattern(vim.uri_from_fname(filename))
end

---@param domain string
---@return string escaped
local function domain_to_pattern(domain)
  -- We construct the following regex:
  -- 1. http or https protocol;
  -- 2. followed by userinfo (`name:password@`),
  -- 3. followed by potentially `www.` (for convenience),
  -- 4. followed by the domain (in very-nomagic mode)
  -- 5. followed by either a slash or nothing at all.
  return string.format(
    [[\v^https?://([^@/?#]*\@)?(www\.)?(\V%s\v)($|/)]],
    -- `domain` here includes the host name and port. If it doesn't contain
    -- characters illegal in a host or port, this encoding should do nothing.
    -- If it contains illegal characters, the domain is broken in a safe way.
    vim.uri_encode(domain)
  )
end

---@param pattern string
---@return OrgPromise<OrgState>
local function cache_safe_pattern(pattern)
  ---@param state OrgState
  return State:load():next(function(state)
    -- We manipulate `cached` in a strange way here to ensure that `state` gets
    -- marked as dirty.
    local patterns = { pattern }
    local cached = state['org_safe_remote_resources']
    if cached then
      vim.list_extend(patterns, cached)
    end
    state['org_safe_remote_resources'] = patterns
  end)
end

---Ask the user if URI should be considered safe.
---@param uri string
---@return OrgPromise<boolean> safe
function M.confirm_safe(uri)
  ---@type OrgMenu
  return Promise.new(function(resolve)
    local menu = Menu:new({
      title = string.format('An org-mode document would like to download %s, which is not considered safe.', uri),
      prompt = 'Do you want to download this?',
    })
    menu:add_option({
      key = '!',
      label = 'Yes, and mark it as safe.',
      action = function()
        cache_safe_pattern(uri_to_pattern(uri))
        return true
      end,
    })
    local authority = uri:match('^https?://([^/?#]*)')
    -- `domain` here includes the host name and port.
    local domain = authority and authority:match('^[^@]*@(.*)$') or authority
    if domain then
      menu:add_option({
        key = 'd',
        label = string.format('Yes, and mark the domain as safe. (%s)', domain),
        action = function()
          cache_safe_pattern(domain_to_pattern(domain))
          return true
        end,
      })
    end
    local filename = fs.get_real_path(utils.current_file_path())
    if filename then
      menu:add_option({
        key = 'f',
        label = string.format('Yes, and mark the org file as safe. (%s)', filename),
        action = function()
          cache_safe_pattern(filename_to_pattern(filename))
          return true
        end,
      })
    end
    menu:add_option({
      key = 'y',
      label = 'Yes, just this once.',
      action = function()
        return true
      end,
    })
    menu:add_option({
      key = 'n',
      label = 'No, skip this resource.',
      action = function()
        return false
      end,
    })
    menu:add_separator({ icon = ' ', length = 1 })
    resolve(menu:open())
  end)
end

return M
