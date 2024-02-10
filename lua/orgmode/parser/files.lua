local config = require('orgmode.config')
local utils = require('orgmode.utils')
local ts_utils = require('orgmode.utils.treesitter')
local OrgFiles = require('orgmode.files')
local Listitem = require('orgmode.files.elements.listitem')
local ClockReport = require('orgmode.clock.report')

---@class Files
---@field orgfiles table<string, OrgFile>
---@field tags string[]
---@field file_loader OrgFiles|nil
local Files = {
  orgfiles = {},
  tags = {},
  file_loader = nil,
}

function Files.new()
  Files.load()
  vim.notify(
    '[orgmode] "orgmode.parser.files" is deprecated. Use "orgmode.api" instead (see :h OrgApi.load)',
    vim.log.levels.WARN
  )
  return Files
end

function Files.load(callback)
  Files.loader():load():next(function(files)
    Files.orgfiles = files
    Files._build_tags()
    if callback then
      callback()
    end
  end)

  return Files
end

function Files.unload()
  Files.loader():unload()
  Files.file_loader = nil
  return Files
end

function Files.reload(file, callback)
  local prev_file = Files.orgfiles[file]
  Files.loader():load_file(file):next(function(orgfile)
    Files.orgfiles[orgfile.filename] = orgfile
    Files._build_tags()
    if callback then
      callback()
    end
    return orgfile
  end)
end

---@return OrgFile[]
function Files.all()
  return Files.loader():all()
end

---@return string[]
function Files.filenames()
  return vim.tbl_map(function(file)
    return file.filename
  end, Files.all())
end

---@param file string
---@return OrgFile
function Files.get(file)
  local orgfile = Files.loader():load_file_sync(file)
  assert(orgfile, 'File not found or is in invalid format')
  return orgfile
end

---@return string[]
function Files.get_tags()
  return Files.tags
end

---@return OrgFile
function Files.get_current_file()
  local current_file = Files.loader():get_current_file()
  assert(current_file, 'Current file not found or is in invalid format')
  return current_file
end

---@param title string
---@return OrgHeadline[]
function Files.find_headlines_by_title(title, exact)
  return Files.loader():find_headlines_by_title(title, exact)
end

---@param property_name string
---@param term string
---@return OrgHeadline[]
function Files.find_headlines_with_property_matching(property_name, term)
  return Files.loader():find_headlines_with_property_matching(property_name, term)
end

---@param filename string
---@param action function
---@return OrgPromise<OrgFile>
function Files.update_file(filename, action)
  return Files.loader():update_file(filename, action)
end

---@param term string
---@param no_escape boolean
---@param search_extra_files boolean
---@return OrgHeadline[]
function Files.find_headlines_matching_search_term(term, no_escape, search_extra_files)
  return Files.loader():find_headlines_matching_search_term(term, no_escape, search_extra_files)
end

---@return OrgHeadline
function Files.get_closest_headline(cursor)
  return Files.loader():get_closest_headline(cursor)
end

---Return closest headline or nil if none found
---@return OrgHeadline | nil
function Files.get_closest_headline_or_nil(cursor)
  return Files.loader():get_closest_headline_or_nil(cursor)
end

---@return OrgHeadline | nil
function Files.get_clocked_headline()
  -- TODO: Optimize
  for _, file in ipairs(Files.all()) do
    for _, headline in ipairs(file:get_headlines()) do
      if headline:is_clocked_in() then
        return headline
      end
    end
  end
  return nil
end

function Files.get_closest_listitem()
  local node = ts_utils.closest_node(ts_utils.get_node_at_cursor(), 'listitem')
  if node then
    return Listitem:new(node, Files.get_current_file())
  end
  return nil
end

function Files.get_clock_report(from, to)
  return ClockReport:new({
    from = from,
    to = to,
    files = Files.loader(),
  }):generate_report()
end

function Files._build_tags()
  local tags = {}
  for _, orgfile in ipairs(Files.all()) do
    if not orgfile:is_archive_file() then
      for _, headline in ipairs(orgfile:get_headlines()) do
        local htags = headline:get_tags()
        if htags and #htags > 0 then
          for _, tag in ipairs(htags) do
            tags[tag] = 1
          end
        end
      end
    end
  end
  local taglist = vim.tbl_keys(tags)
  table.sort(taglist)
  Files.tags = taglist
end

function Files.autocomplete_tags(arg_lead)
  return utils.prompt_autocomplete(arg_lead, Files.get_tags())
end

---@return OrgFiles
function Files.loader()
  if not Files.file_loader then
    Files.file_loader = OrgFiles:new({
      paths = config.org_agenda_files,
    })
  end

  return Files.file_loader
end

return Files.new()
