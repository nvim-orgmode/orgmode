local instance = {}
local Config = {}
local utils = require('orgmode.utils')
local defaults = require('orgmode.config.defaults')
local mappings = require('orgmode.config.mappings')

---@class Config
---@param opts? table
function Config:new(opts)
  local data = {
    opts = vim.tbl_deep_extend('force', defaults, opts or {})
  }
  setmetatable(data, self)
  return data
end

function Config:__index(key)
  if self.opts[key] then return self.opts[key] end
  return rawget(getmetatable(self), key)
end

---@param opts table
---@return Config
function Config:extend(opts)
  self.opts = vim.tbl_deep_extend('force', self.opts, opts or {})
  return self
end

---@return string[]
function Config:get_all_files()
  if not self.org_agenda_files or self.org_agenda_files == '' or (type(self.org_agenda_files) == 'table' and vim.tbl_isempty(self.org_agenda_files)) then
    return {}
  end
  local files = self.org_agenda_files
  if type(files) ~= 'table' then
    files = { files }
  end

  local all_files = vim.tbl_map(function(file)
    return vim.fn.glob(vim.fn.fnamemodify(file, ':p'), 0, 1)
  end, files)


  all_files = vim.tbl_flatten(all_files)

  return vim.tbl_filter(function(file)
    local ext = vim.fn.fnamemodify(file, ':e')
    return ext == 'org' or ext == 'org_archive'
  end, all_files)
end

---@return number
function Config:get_week_start_day_number()
  return utils.convert_from_isoweekday(1)
end

---@return number
function Config:get_week_end_day_number()
  return utils.convert_from_isoweekday(7)
end

---@return string|number
function Config:get_agenda_span()
  local span = self.opts.org_agenda_span
  local valid_spans = {'day', 'month', 'week', 'year'}
  if type(span) == 'string' and not vim.tbl_contains(valid_spans, span) then
    utils.echo_warning(string.format(
      'Invalid agenda span %s. Valid spans: %s. Falling back to week',
      span,
      table.concat(valid_spans, ', ')
    ))
    span = 'week'
  end
  if type(span) == 'number' and span < 0 then
    utils.echo_warning(string.format(
      'Invalid agenda span number %d. Must be 0 or more. Falling back to week',
      span,
      table.concat(valid_spans, ', ')
    ))
    span = 'week'
  end
  return span
end

function Config:get_todo_keywords()
  local types = { TODO = {}, DONE = {}, ALL = {} };
  local type = 'TODO'
  for _, word in ipairs(self.opts.org_todo_keywords) do
    if word == '|' then
      type = 'DONE'
    else
      table.insert(types[type], word)
      table.insert(types.ALL, word)
    end
  end
  if #types.DONE == 0 then
    types.DONE = {table.remove(types.TODO, #types.TODO)}
  end
  return types
end

function Config:setup_mappings(category)
  if self.opts.mappings.disable_all then return end
  if not category then
    utils.keymap('n', self.opts.mappings.global.org_agenda, '<cmd>lua require("orgmode").action("agenda.prompt")<CR>')
    utils.keymap('n', self.opts.mappings.global.org_capture, '<cmd>lua require("orgmode").action("capture.prompt")<CR>')
    return
  end
  if not self.opts.mappings[category] then return end

  for name, key in pairs(self.opts.mappings[category]) do
    if mappings[category] and mappings[category][name] then
      local map = vim.tbl_map(function(i) return string.format('"%s"', i) end, mappings[category][name])
      local keys = key
      if type(keys) == 'string' then
        keys = { keys }
      end
      for _, k in ipairs(keys) do
        utils.buf_keymap(0, 'n', k, string.format('<cmd>lua require("orgmode").action(%s)<CR>', table.concat(map, ', ')))
      end
    end
  end
end

function Config:parse_archive_location(file, archive_loc)
  if self:is_archive_file(file) then return nil end

  archive_loc = archive_loc or self.opts.org_archive_location
  -- TODO: Support archive to headline
  local parts = vim.split(archive_loc, '::')
  local archive_location = vim.trim(parts[1])
  if archive_location:find('%%s') then
    return string.format(archive_location, file)
  end
  return vim.fn.fnamemodify(archive_location, ':p')
end

function Config:is_archive_file(file)
  return vim.fn.fnamemodify(file, ':e') == 'org_archive'
end

function Config:get_inheritable_tags(headline)
  if not headline.tags or not self.opts.org_use_tag_inheritance then
    return {}
  end
  if vim.tbl_isempty(self.opts.org_tags_exclude_from_inheritance) then
    return {unpack(headline.tags)}
  end

  return vim.tbl_filter(function(tag)
    return not vim.tbl_contains(self.opts.org_tags_exclude_from_inheritance, tag)
  end, headline.tags)
end

instance = Config:new()
return instance
