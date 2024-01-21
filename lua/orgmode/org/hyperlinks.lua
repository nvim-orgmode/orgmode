local Files = require('orgmode.parser.files')
local utils = require('orgmode.utils')
local fs = require('orgmode.utils.fs')
local Url = require('orgmode.objects.url')
local config = require('orgmode.config')
local Hyperlinks = {
  stored_links = {},
}

---@param url Url
local function get_file_from_url(url)
  local file_path = url:get_filepath()
  local canonical_path = file_path and fs.get_real_path(file_path)
  return canonical_path and Files.get(canonical_path) or Files.get_current_file()
end

---@param url Url
---@return string[]
function Hyperlinks.find_by_filepath(url)
  local filenames = Files.filenames()
  local file_base = url:get_filepath()
  if not file_base then
    return {}
  end
  --TODO integrate with orgmode.utils.fs or orgmode.objects.url
  local file_base_no_start_path = file_base:gsub('^%./', '') .. ''
  local is_relative_path = file_base:match('^%./')
  local current_file_directory = fs.get_current_file_dir()
  local valid_filenames = {}
  for _, f in ipairs(filenames) do
    if is_relative_path then
      local match = f:match('^' .. current_file_directory .. '/(' .. file_base_no_start_path .. '.*%.org)$')
      if match then
        table.insert(valid_filenames, './' .. match)
      end
    else
      if f:find('^' .. file_base) then
        table.insert(valid_filenames, f)
      end
    end
  end

  -- Outer checks already filter cases where `ctx.skip_add_prefix` is truthy,
  -- so no need to check it here
  return vim.tbl_map(function(path)
    return 'file:' .. path
  end, valid_filenames)
end

---@param url Url
---@return Section[]
function Hyperlinks.find_by_custom_id_property(url)
  local file = get_file_from_url(url)
  local custom_id = url:get_custom_id()
  if not custom_id then
    error(string.format('Expect an url with a custom_id: %q', url))
    return {}
  end
  return file:find_headlines_with_property_matching('CUSTOM_ID', custom_id)
end

---@param headlines Section[]
---@return string[]
function Hyperlinks.as_custom_id_anchors(headlines)
  return vim.tbl_map(function(headline)
    return type(headline) == 'table'
      and headline.properties
      and headline.properties.items
      and headline.properties.items.custom_id
      and '#' .. headline.properties.items.custom_id
  end, headlines)
end

---@param headlines Section[]
---@param omit_prefix? boolean
---@return string[]
function Hyperlinks.as_headline_anchors(headlines, omit_prefix)
  return vim.tbl_map(function(headline)
    if type(headline) == 'table' and headline.title then
      return omit_prefix and headline.title or '*' .. headline.title
    else
      return headline
    end
  end, headlines)
end

---@param url Url
---@return Section[]
function Hyperlinks.find_by_title(url)
  local file = get_file_from_url(url)
  local headline = url:get_headline() or url:get_dedicated_target()
  if not headline then
    error(string.format('Expect an url with a headline: %q', url.str))
    return {}
  end
  return file:find_headlines_by_title(headline, false)
end

local function as_dedicated_anchor_pattern(anchor_str)
  return string.format('<<<?(%s[^>]*)>>>?', anchor_str):lower()
end

---@param url Url
---@return Section[]
function Hyperlinks.find_by_dedicated_target(url)
  local anchor = url and url:get_dedicated_target()
  if anchor then
    return Files.get_current_file():find_headlines_matching_search_term(as_dedicated_anchor_pattern(anchor), true)
  else
    return {}
  end
end

---@param url Url
---@return fun(headlines: Section[]): string[]
function Hyperlinks.as_dedicated_targets(url)
  return function(headlines)
    local targets = {}
    local term = as_dedicated_anchor_pattern(url:get_dedicated_target())
    for _, headline in ipairs(headlines) do
      for m in headline.title:lower():gmatch(term) do
        table.insert(targets, m)
      end
      for _, content in ipairs(headline.content) do
        for m in content:lower():gmatch(term) do
          table.insert(targets, m)
        end
      end
    end
    return targets
  end
end

---@param url Url
---@return fun(headlines: Section[]): table<string>
function Hyperlinks.as_dedicated_anchors_or_internal_titles(url)
  return function(headlines)
    local dedicated_anchors = Hyperlinks.as_dedicated_targets(url)(headlines)
    local fuzzy_titles = Hyperlinks.as_headline_anchors(headlines, true)
    return utils.concat(dedicated_anchors, fuzzy_titles, true)
  end
end

---@param url Url
---@return Section[], fun(headline: Section[]): string[]
function Hyperlinks.find_matching_links(url)
  local result = {}
  local mapper = function(item)
    return item
  end
  if not url then
    return result, mapper
  elseif url:is_file_plain() then
    result = Hyperlinks.find_by_filepath(url)
  elseif url:is_custom_id() then
    result = Hyperlinks.find_by_custom_id_property(url)
    mapper = Hyperlinks.as_custom_id_anchors
  elseif url:is_headline() then
    result = Hyperlinks.find_by_title(url)
    mapper = Hyperlinks.as_headline_anchors
  elseif url:is_dedicated_anchor_or_internal_title() then
    result = utils.concat(
      Hyperlinks.find_by_dedicated_target(url),
      -- TODO replace with real fuzzy title search
      Hyperlinks.find_by_title(url)
    )
    mapper = Hyperlinks.as_dedicated_anchors_or_internal_titles(url)
  end

  return result, mapper
end

---@param headline Headline
---@param path? string
function Hyperlinks.get_link_to_headline(headline, path)
  path = path or utils.current_file_path()
  local title = headline:title()
  local id
  if config.org_id_link_to_org_use_id then
    id = headline:id_get_or_create()
  end
  return Hyperlinks._generate_link_to_headline(title, id, path)
end

---@private
function Hyperlinks._generate_link_to_headline(title, id, path)
  if not config.org_id_link_to_org_use_id or not id then
    return ('file:%s::*%s'):format(path, title)
  end
  return ('id:%s  %s'):format(id, title)
end

---@param headline Headline
function Hyperlinks.store_link_to_headline(headline)
  local title = headline:title()
  Hyperlinks.stored_links[Hyperlinks.get_link_to_headline(headline)] = title
end

---@param arg_lead string
---@return string[]
function Hyperlinks.autocomplete_links(arg_lead)
  local url = Url.new(arg_lead)
  local result, mapper = Hyperlinks.find_matching_links(url)

  if url:is_file_plain() then
    return mapper(result)
  end

  if url:is_custom_id() or url:is_headline() then
    local file = get_file_from_url(url)
    local results = mapper(result)
    return vim.tbl_map(function(value)
      return ('file:%s::%s'):format(file.filename, value)
    end, results)
  end

  return vim.tbl_keys(Hyperlinks.stored_links)
end

return Hyperlinks
