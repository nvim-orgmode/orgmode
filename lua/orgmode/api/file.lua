local OrgHeadline = require('orgmode.api.headline')

---@class OrgFile
---@field category string current file category name. By default only filename without extension unless defined via #+CATEGORY directive
---@field filename string absolute path of the current file
---@field headlines OrgHeadline[]
---@field is_archive_file boolean
local OrgFile = {}

---@param headline OrgHeadline
---@param headlines_by_id table<string, OrgHeadline>
---@private
local function map_child_headlines(headline, headlines_by_id)
  if #headline._section.sections == 0 then
    return headline
  end

  local child_headlines = {}
  for _, child_section in ipairs(headline._section.sections) do
    local child_headline = headlines_by_id[child_section.id]
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

---@param file File
---@private
function OrgFile._build_from_internal_file(file)
  local headlines = {}
  local headlines_by_id = {}
  for i, section in ipairs(file.sections) do
    local headline = OrgHeadline._build_from_internal_section(section, i)
    table.insert(headlines, headline)
    headlines_by_id[section.id] = headline
  end

  local instance = OrgFile:_new({
    _file = file,
    category = file.category,
    filename = file.filename,
    headlines = headlines,
    is_archive_file = file.is_archive_file,
  })

  for _, headline in ipairs(instance.headlines) do
    map_child_headlines(headline, headlines_by_id)
    headline.file = instance
  end

  return instance
end

--- Return refreshed instance of the file
---@return OrgFile
function OrgFile:reload()
  return OrgFile._build_from_internal_file(self._file:refresh())
end

return OrgFile
