local Files = require('orgmode.parser.files')
local utils = require('orgmode.utils')
local Hyperlinks = {}

function Hyperlinks.find_by_custom_id_property(base, skip_mapping)
  local headlines = Files.get_current_file():find_headlines_with_property_matching('CUSTOM_ID', base:sub(2))
  if skip_mapping then return headlines end
  return vim.tbl_map(function(headline)
    return '#'..headline.properties.items.CUSTOM_ID
  end, headlines)
end

function Hyperlinks.find_by_title_pointer(base, skip_mapping)
  local headlines = Files.get_current_file():find_headlines_by_title(base:sub(2))
  if skip_mapping then return headlines end
  return vim.tbl_map(function(headline)
    return '*'..headline.title
  end, headlines)
end

function Hyperlinks.find_by_dedicated_target(base, skip_mapping)
  if not base or base == '' then return {} end
  local term = string.format('<<<?(%s[^>]*)>>>?', base):lower()
  local headlines = Files.get_current_file():find_headlines_matching_search_term(term, true)
  if skip_mapping then return headlines end
  local targets = {}
  for _, headline in ipairs(headlines) do
    for m in headline.title:lower():gmatch(term) do
      table.insert(targets, m)
    end
    for _, content in ipairs(headline.content) do
    for m in content.line:lower():gmatch(term) do
      table.insert(targets, m)
    end
    end
  end
  return targets
end

function Hyperlinks.find_by_title(base, skip_mapping)
  if not base or base == '' then return {} end
  local headlines = Files.get_current_file():find_headlines_by_title(base)
  if skip_mapping then return headlines end
  return vim.tbl_map(function(headline)
    return headline.title
  end, headlines)
end

function Hyperlinks.find_matching_links(base, skip_mapping)
  base = vim.trim(base)
  local prefix = base:sub(1, 1)
  if prefix == '#' then
    return Hyperlinks.find_by_custom_id_property(base, skip_mapping)
  end

  if prefix == '*' then
    return Hyperlinks.find_by_title_pointer(base, skip_mapping)
  end

  local results = Hyperlinks.find_by_dedicated_target(base, skip_mapping)
  local all = utils.concat(results, Hyperlinks.find_by_title(base, skip_mapping))
  return all
end

return Hyperlinks
