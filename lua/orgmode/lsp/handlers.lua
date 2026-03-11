local methods = vim.lsp.protocol.Methods
local OrgLspHandlers = {}

local HEADLINE_KIND = vim.lsp.protocol.SymbolKind.Struct

---@param headline OrgHeadline
local function get_headline_symbol(headline)
  ---@cast headline OrgHeadline
  local range = headline:get_range():to_lsp()
  local result = {
    name = headline:get_title(),
    kind = HEADLINE_KIND,
    range = range,
    selectionRange = range,
  }
  local child_headlines = headline:get_child_headlines()
  if #child_headlines > 0 then
    result.children = vim.tbl_map(get_headline_symbol, child_headlines)
  end
  return result
end

OrgLspHandlers[methods.textDocument_documentSymbol] = function(params)
  local filename = vim.uri_to_fname(params.textDocument.uri)
  local orgfile = require('orgmode').files:load_file_sync(filename)
  if not orgfile then
    return {}
  end

  return vim.tbl_map(get_headline_symbol, orgfile:get_top_level_headlines())
end

OrgLspHandlers[methods.workspace_symbol] = function(params)
  local results = {}
  local headlines = require('orgmode').files:find_headlines_matching_search_term(params.query or '', false, false)
  for _, headline in pairs(headlines) do
    table.insert(results, {
      name = headline:get_title(),
      kind = HEADLINE_KIND,
      location = {
        uri = vim.uri_from_fname(headline.file.filename),
        range = headline:get_range():to_lsp(),
      },
    })
  end

  return results
end

OrgLspHandlers[methods.textDocument_completion] = function(params)
  local line = vim.api
    .nvim_buf_get_lines(vim.uri_to_bufnr(params.textDocument.uri), params.position.line, params.position.line + 1, false)[1]
    :sub(1, params.position.character)

  local org = require('orgmode')
  local offset = org.completion:get_start({ line = line }) + 1
  local base = string.sub(line, offset)

  local completion = org.completion:complete({
    line = line,
    base = base,
    fuzzy = true,
  })

  local results = vim.tbl_map(function(item)
    return {
      label = item.word,
      labelDetails = item.menu and { description = item.menu } or nil,
    }
  end, completion)

  return {
    isIncomplete = true,
    items = results,
  }
end

OrgLspHandlers[methods.textDocument_references] = function(params)
  local org = require('orgmode')
  local headline =
    org.files:get(vim.uri_to_fname(params.textDocument.uri)):get_closest_headline({ params.position.line + 1, 0 })
  local custom_id = headline:get_property('CUSTOM_ID', false)
  local title = headline:get_title()

  if not headline then
    return {}
  end

  local function is_valid_target(target)
    if target == '*' .. title or target == title then
      return true
    end

    if custom_id and target == '#' .. custom_id then
      return true
    end

    return false
  end

  ---@type lsp.Location[]
  local locations = {}

  for _, orgfile in ipairs(org.files:all()) do
    for _, link in ipairs(orgfile:get_links()) do
      local file_path = link.url:get_file_path()
      local target_or_path = link.url:get_target() or link.url:get_path()
      local target = link.url:get_target()

      local location = {
        uri = vim.uri_from_fname(orgfile.filename),
        range = link.range:to_lsp(),
      }

      -- is a file headline link
      if file_path and vim.fs.normalize(file_path) == vim.fs.normalize(headline.file.filename) then
        if not target or is_valid_target(target) then
          table.insert(locations, location)
        end
        goto continue
      end

      -- is local link
      if orgfile.filename == headline.file.filename and is_valid_target(target_or_path) then
        table.insert(locations, location)
      end

      ::continue::
    end
  end

  return locations
end

return OrgLspHandlers
