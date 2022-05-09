local Files = require('orgmode.parser.files')
local utils = require('orgmode.utils')
local Hyperlinks = {}

local function get_file_from_context(ctx)
  return (
    ctx.hyperlinks and ctx.hyperlinks.filepath and Files.get(ctx.hyperlinks.filepath, true)
    or Files.get_current_file()
  )
end

local function update_hyperlink_ctx(ctx)
  if not ctx.line then
    return
  end

  -- TODO: Support text search, see here [https://orgmode.org/manual/External-Links.html]
  local hyperlinks_ctx = {
    filepath = false,
    headline = false,
    custom_id = false,
  }

  local file_match = ctx.line:match('file:(.-)::')
  file_match = file_match and vim.fn.fnamemodify(file_match, ':p') or file_match

  if file_match and Files.get(file_match) then
    hyperlinks_ctx.filepath = Files.get(file_match).filename
    hyperlinks_ctx.headline = ctx.line:match('file:.-::(%*.-)$')

    if not hyperlinks_ctx.headline then
      hyperlinks_ctx.custom_id = ctx.line:match('file:.-::(#.-)$')
    end

    ctx.base = hyperlinks_ctx.headline or hyperlinks_ctx.custom_id or ctx.base
  end

  ctx.hyperlinks = hyperlinks_ctx
end

function Hyperlinks.find_by_filepath(ctx)
  local filenames = Files.filenames()
  local file_base = ctx.base:gsub('^file:', '')
  if vim.trim(file_base) ~= '' then
    filenames = vim.tbl_filter(function(f)
      return f:find('^' .. file_base)
    end, filenames)
  end

  -- Outer checks already filter cases where `ctx.skip_add_prefix` is truthy,
  -- so no need to check it here
  return vim.tbl_map(function(path)
    return 'file:' .. path
  end, filenames)
end

function Hyperlinks.find_by_custom_id_property(ctx)
  local file = get_file_from_context(ctx)
  local headlines = file:find_headlines_with_property_matching('CUSTOM_ID', ctx.base:sub(2))
  if ctx.skip_add_prefix then
    return headlines
  end
  return vim.tbl_map(function(headline)
    return '#' .. headline.properties.items.custom_id
  end, headlines)
end

function Hyperlinks.find_by_title_pointer(ctx)
  local file = get_file_from_context(ctx)
  local headlines = file:find_headlines_by_title(ctx.base:sub(2), false)
  if ctx.skip_add_prefix then
    return headlines
  end
  return vim.tbl_map(function(headline)
    return '*' .. headline.title
  end, headlines)
end

function Hyperlinks.find_by_dedicated_target(ctx)
  if not ctx.base or ctx.base == '' then
    return {}
  end
  local term = string.format('<<<?(%s[^>]*)>>>?', ctx.base):lower()
  local headlines = Files.get_current_file():find_headlines_matching_search_term(term, true)
  if ctx.skip_add_prefix then
    return headlines
  end
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

function Hyperlinks.find_by_title(ctx)
  if not ctx.base or ctx.base == '' then
    return {}
  end
  local headlines = Files.get_current_file():find_headlines_by_title(ctx.base, false)
  if ctx.skip_add_prefix then
    return headlines
  end
  return vim.tbl_map(function(headline)
    return headline.title
  end, headlines)
end

function Hyperlinks.find_matching_links(ctx)
  ctx = ctx or {}
  ctx.base = ctx.base and vim.trim(ctx.base) or nil

  update_hyperlink_ctx(ctx)

  if ctx.base:find('^file:') and not ctx.skip_add_prefix then
    return Hyperlinks.find_by_filepath(ctx)
  end

  local prefix = ctx.base:sub(1, 1)
  if prefix == '#' then
    return Hyperlinks.find_by_custom_id_property(ctx)
  end
  if prefix == '*' then
    return Hyperlinks.find_by_title_pointer(ctx)
  end

  local results = Hyperlinks.find_by_dedicated_target(ctx)
  local all = utils.concat(results, Hyperlinks.find_by_title(ctx))
  return all
end

return Hyperlinks
