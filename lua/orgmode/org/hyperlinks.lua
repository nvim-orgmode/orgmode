local Files = require('orgmode.parser.files')
local utils = require('orgmode.utils')
local Hyperlinks = {}

local function get_file_from_context(ctx)
  return (ctx.hyperlinks and ctx.hyperlinks.filepath and Files.get(ctx.hyperlinks.filepath) or Files.get_current_file())
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
  if file_match then
    file_match = Hyperlinks.get_file_real_path(file_match)
  end

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
  local file_base_no_start_path = file_base:gsub('^%./', '') .. ''
  local is_relative_path = file_base:match('^%./')
  local current_file_directory = vim.fn.fnamemodify(utils.current_file_path(), ':p:h')
  local valid_filenames = {}
  for _, f in ipairs(filenames) do
    if is_relative_path then
      local match = f:match('^' .. current_file_directory .. '/(' .. file_base_no_start_path .. '[^/]*%.org)$')
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
      for m in content:lower():gmatch(term) do
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

function Hyperlinks.get_file_real_path(url_path)
  local path = url_path
  path = path:gsub('^file:', '')
  if path:match('^~/') then
    path = path:gsub('^~', os.getenv('HOME'))
  end
  if path:match('^/') then
    return path
  end
  path = path:gsub('^./', '')
  return vim.fn.fnamemodify(utils.current_file_path(), ':p:h') .. '/' .. path
end

return Hyperlinks
