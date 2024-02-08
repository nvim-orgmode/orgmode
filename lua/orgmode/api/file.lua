---@diagnostic disable: invisible
local OrgHeadline = require('orgmode.api.headline')

---@class OrgApiFile
---@field category string current file category name. By default it's only filename without extension unless defined differently via #+CATEGORY directive
---@field filename string absolute path of the current file
---@field headlines OrgApiHeadline[]
---@field is_archive_file boolean
---@field private _file OrgFile
local OrgFile = {}

---@param headline OrgApiHeadline
---@param headlines_by_id table<string, OrgApiHeadline>
---@private
local function map_child_headlines(headline, headlines_by_id)
  if #headline._section:get_child_headlines() == 0 then
    return headline
  end

  local child_headlines = {}
  for _, child_section in ipairs(headline._section:get_child_headlines()) do
    local child_headline = headlines_by_id[child_section:get_range().start_line]
    child_headline.parent = headline
    table.insert(child_headlines, child_headline)
    map_child_headlines(child_headline, headlines_by_id)
  end
  headline.headlines = child_headlines
  return headline
end

---@private
function OrgFile:_new(opts)
  local data = {}
  data.category = opts.category
  data.filename = opts.filename
  data.headlines = opts.headlines
  data.is_archive_file = opts.is_archive_file or false
  data._file = opts._file
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param file OrgFile
---@private
function OrgFile._build_from_internal_file(file)
  local headlines = {}
  local headlines_by_id = {}
  for i, section in ipairs(file:get_headlines()) do
    local headline = OrgHeadline._build_from_internal_headline(section, i)
    table.insert(headlines, headline)
    headlines_by_id[section:get_range().start_line] = headline
  end

  local instance = OrgFile:_new({
    _file = file,
    category = file:get_category(),
    filename = file.filename,
    headlines = headlines,
    is_archive_file = file:is_archive_file(),
  })

  for _, headline in ipairs(instance.headlines) do
    map_child_headlines(headline, headlines_by_id)
    headline.file = instance
  end

  return instance
end

--- Return refreshed instance of the file
---@return OrgApiFile
function OrgFile:reload()
  return OrgFile._build_from_internal_file(self._file:reload_sync())
end

--- Return closest headline, or nil if there are no headlines found
--- If cursor is not provided, it will use current cursor position
--- @param cursor? { line: number, col: number } (1, 0)-indexed cursor position, same as returned from `vim.api.nvim_win_get_cursor(0)`
--- @return OrgApiHeadline | nil
function OrgFile:get_closest_headline(cursor)
  local file = self:reload()
  local internal_headline = file._file:get_closest_headline_or_nil(cursor)
  if not internal_headline then
    return nil
  end
  for _, headline in ipairs(file.headlines) do
    if headline.position.start_line == internal_headline:get_range().start_line then
      return headline
    end
  end
  return nil
end

return OrgFile
