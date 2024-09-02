local Promise = require('orgmode.utils.promise')
local utils = require('orgmode.utils')
local ts_utils = require('orgmode.utils.treesitter')
local Headline = require('orgmode.files.headline')
local ts = vim.treesitter
local config = require('orgmode.config')
local Block = require('orgmode.files.elements.block')
local Link = require('orgmode.org.hyperlinks.link')
local Range = require('orgmode.files.elements.range')
local Memoize = require('orgmode.utils.memoize')

---@class OrgFileMetadata
---@field mtime number
---@field changedtick number

---@class OrgFileOpts
---@field filename string
---@field lines string[]
---@field bufnr? number

---@class OrgFile
---@field filename string
---@field lines string[]
---@field content string
---@field metadata OrgFileMetadata
---@field parser vim.treesitter.LanguageTree
---@field root TSNode
local OrgFile = {}

local memoize = Memoize:new(OrgFile, function(self)
  return {
    file = self,
    id = table.concat({ 'file', self.root and self.root:id() or '' }, '_'),
  }
end)

---Constructor function, should not be used directly
---@param opts OrgFileOpts
---@return OrgFile
function OrgFile:new(opts)
  local stat = vim.loop.fs_stat(opts.filename)
  local data = {
    filename = opts.filename,
    lines = opts.lines,
    content = table.concat(opts.lines, '\n'),
    metadata = {
      mtime = stat and stat.mtime.nsec or 0,
      changedtick = opts.bufnr and vim.api.nvim_buf_get_changedtick(opts.bufnr) or 0,
    },
  }
  setmetatable(data, self)
  return data
end

---Load the file
---@return OrgPromise<OrgFile | false>
function OrgFile.load(filename)
  if not utils.is_org_file(filename) then
    return Promise.resolve(false)
  end
  local bufnr = vim.fn.bufnr(filename) or -1

  if bufnr > -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    return Promise.resolve(OrgFile:new({
      filename = filename,
      lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
      bufnr = bufnr,
    }))
  end

  if not vim.loop.fs_stat(filename) then
    return Promise.resolve(false)
  end

  return utils.readfile(filename, { schedule = true }):next(function(lines)
    return OrgFile:new({
      filename = filename,
      lines = lines,
    })
  end)
end

---Reload the file if it has been modified
---@return OrgPromise<OrgFile>
function OrgFile:reload()
  if not self:is_modified() then
    return Promise.resolve(self)
  end

  local bufnr = self:bufnr()

  if bufnr > -1 then
    local updated_file = self:_update_lines(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), bufnr)
    return Promise.resolve(updated_file)
  end

  return utils.readfile(self.filename, { schedule = true }):next(function(lines)
    return self:_update_lines(lines)
  end)
end

---sync reload the file if it has been modified
---@param timeout? number
---@return OrgFile
function OrgFile:reload_sync(timeout)
  return self:reload():wait(timeout)
end

---@param action fun(...:OrgFile):any
function OrgFile:update(action)
  local is_same_file = self.filename == utils.current_file_path()
  if is_same_file then
    return Promise.resolve(action(self)):next(function(result)
      vim.cmd(':silent! w')
      return result
    end)
  end

  local edit_file = utils.edit_file(self.filename)
  edit_file.open()

  return Promise.resolve(action(self)):next(function(result)
    edit_file.close()
    return self:reload():next(function()
      return result
    end)
  end)
end

---@param action fun(...:OrgFile):any
function OrgFile:update_sync(action, timeout)
  return self:update(action):wait(timeout)
end

---Check if file has been modified via 2 methods:
---1. If file is loaded in a buffer, check the changedtick
---2. If file is not loaded in a buffer, check the mtime
---@return boolean
function OrgFile:is_modified()
  local bufnr = self:bufnr()
  if bufnr > -1 then
    local cur_changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
    return cur_changedtick ~= self.metadata.changedtick
  end
  local stat = vim.loop.fs_stat(self.filename)
  if not stat then
    return false
  end
  return stat.mtime.nsec ~= self.metadata.mtime
end

---Parse the file and update the root node
---@param skip_if_not_modified? boolean If true, skip parsing the file if it has not been modified
---@return TSNode
function OrgFile:parse(skip_if_not_modified)
  if skip_if_not_modified and self.root and not self:is_modified() then
    return self.root
  end
  self.parser = self:_get_parser()
  local trees = self.parser:parse()
  self.root = trees[1]:root()
  return self.root
end

---Parse the given tree-sitter query
---@param query string
---@param node? TSNode
function OrgFile:get_ts_matches(query, node)
  self:parse()
  node = node or self.root
  local ts_query = ts_utils.get_query(query)
  local matches = {}

  local from, _, to = node:range()
  for _, match, _ in ts_query:iter_matches(node, self:_get_source(), from, to + 1, { all = false }) do
    local items = {}
    for id, matched_nodes in pairs(match) do
      local name = ts_query.captures[id]
      local matched_node = matched_nodes
      if type(matched_nodes) == 'table' then
        matched_node = matched_nodes[#matched_nodes]
      end
      local node_text = self:get_node_text_list(matched_node)
      items[name] = {
        node = matched_node,
        text_list = node_text,
        text = node_text[1],
      }
    end
    table.insert(matches, items)
  end
  return matches
end

memoize('get_headlines')
---@return OrgHeadline[]
function OrgFile:get_headlines()
  if self:is_archive_file() then
    return {}
  end
  local matches = self:get_ts_matches('(section (headline) @headline)')
  return vim.tbl_map(function(match)
    return Headline:new(match.headline.node, self)
  end, matches)
end

memoize('get_top_level_headlines')
---@return OrgHeadline[]
function OrgFile:get_top_level_headlines()
  if self:is_archive_file() then
    return {}
  end
  local matches = self:get_ts_matches('(document (section (headline) @headline))')
  return vim.tbl_map(function(match)
    return Headline:new(match.headline.node, self)
  end, matches)
end

memoize('get_headlines_including_archived')
---@return OrgHeadline[]
function OrgFile:get_headlines_including_archived()
  local matches = self:get_ts_matches('(section (headline) @headline)')
  return vim.tbl_map(function(match)
    return Headline:new(match.headline.node, self)
  end, matches)
end

---@param title string
---@param exact? boolean
---@return OrgHeadline[]
function OrgFile:find_headlines_by_title(title, exact)
  return vim.tbl_filter(function(item)
    local pattern = '^' .. vim.pesc(title:lower())
    if exact then
      pattern = pattern .. '$'
    end
    return item:get_title():lower():match(pattern)
  end, self:get_headlines())
end

---@param title string
---@return OrgHeadline | nil
function OrgFile:find_headline_by_title(title)
  return utils.find(self:get_headlines(), function(item)
    return item:get_title():lower() == title:lower()
  end)
end

---@return OrgHeadline[]
function OrgFile:get_unfinished_todo_entries()
  if self:is_archive_file() then
    return {}
  end

  return vim.tbl_filter(function(headline)
    return not headline:is_archived() and headline:is_todo()
  end, self:get_headlines())
end

---@param search OrgSearch
---@param todo_only boolean
---@return OrgHeadline[]
function OrgFile:apply_search(search, todo_only)
  if self:is_archive_file() then
    return {}
  end

  return vim.tbl_filter(function(item)
    ---@cast item OrgHeadline
    if item:is_archived() or (todo_only and not item:is_todo()) then
      return false
    end

    local deadline = item:get_deadline_date()
    local scheduled = item:get_scheduled_date()
    local closed = item:get_closed_date()
    local properties = item:get_properties()

    return search:check({
      props = vim.tbl_extend('keep', {}, properties, {
        category = item:get_category(),
        deadline = deadline and deadline:to_wrapped_string(true),
        scheduled = scheduled and scheduled:to_wrapped_string(true),
        closed = closed and closed:to_wrapped_string(false),
      }),
      tags = item:get_tags(),
      todo = item:get_todo() or '',
    })
  end, self:get_headlines())
end

---@param search_term string
---@param no_escape? boolean
---@param ignore_archive_flag? boolean
---@return OrgHeadline[]
function OrgFile:find_headlines_matching_search_term(search_term, no_escape, ignore_archive_flag)
  if self:is_archive_file() and not ignore_archive_flag then
    return {}
  end
  local term = search_term:lower()
  if not no_escape then
    term = vim.pesc(term)
  end

  return vim.tbl_filter(function(item)
    return item:matches_search_term(term)
  end, self:get_headlines_including_archived())
end

---Find headlines where property value is matching the term partially from start
---@param property_name string
---@param term string
---@return OrgHeadline[]
function OrgFile:find_headlines_with_property_matching(property_name, term)
  return vim.tbl_filter(function(item)
    local property = item:get_property(property_name)
    return property and property:lower():match('^' .. vim.pesc(term:lower()))
  end, self:get_headlines())
end

---Find headlines where property value is matching the term exactly
---@param property_name string
---@param term string
---@return OrgHeadline[]
function OrgFile:find_headlines_with_property(property_name, term)
  return vim.tbl_filter(function(item)
    local property = item:get_property(property_name)
    return property and property:lower() == term:lower()
  end, self:get_headlines())
end

memoize('get_opened_headlines')
---@return OrgHeadline[]
function OrgFile:get_opened_headlines()
  if self:is_archive_file() then
    return {}
  end

  return vim.tbl_filter(function(headline)
    return not headline:is_archived()
  end, self:get_headlines())
end

--- Check if this file is an org archive file
--- @return boolean
function OrgFile:is_archive_file()
  return vim.fn.fnamemodify(self.filename, ':e') == 'org_archive'
end

function OrgFile:closest_headline_node(cursor)
  self:parse()
  if not cursor then
    cursor = vim.api.nvim_win_get_cursor(0)
  end
  local cursor_range = { cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2] + 1 }

  local node = self.parser:named_node_for_range(cursor_range)

  if not node then
    return nil
  end

  if node:type() == 'headline' then
    return node
  end

  if node:type() == 'section' then
    return node:field('headline')[1]
  end

  while node and node:type() ~= 'headline' do
    if node:type() == 'section' then
      node = node:field('headline')[1]
      break
    end
    node = node:parent()
  end

  return node
end

---@return OrgHeadline
function OrgFile:get_closest_headline(cursor)
  local node = self:closest_headline_node(cursor)
  if not node then
    error('No headline found')
  end
  return Headline:new(node, self)
end

---@return OrgHeadline | nil
function OrgFile:get_closest_headline_or_nil(cursor)
  local node = self:closest_headline_node(cursor)
  if not node then
    return nil
  end
  return Headline:new(node, self)
end

function OrgFile:get_node_at_cursor(cursor)
  self:parse()
  if not cursor then
    cursor = vim.api.nvim_win_get_cursor(0)
  end
  local row = cursor[1] - 1
  local col = cursor[2]

  return self.root:named_descendant_for_range(row, col, row, col)
end

---@param node? TSNode
---@param range? number[]
---@return string
function OrgFile:get_node_text(node, range)
  if not node then
    return ''
  end
  if range then
    return ts.get_node_text(node, self:_get_source(), {
      metadata = {
        range = range,
      },
    })
  end
  return ts.get_node_text(node, self:_get_source())
end

---@param node? TSNode
---@param range? number[]
---@return string[]
function OrgFile:get_node_text_list(node, range)
  local node_text = self:get_node_text(node, range)
  if node_text == '' then
    return {}
  end
  return vim.split(self:get_node_text(node, range), '\n', { plain = true })
end

---@param node? TSNode
---@param text string
---@param front_trim boolean? If true,trim the text from the front by 1 character
---@return boolean
function OrgFile:set_node_text(node, text, front_trim)
  if not node then
    return false
  end
  local bufnr = self:get_valid_bufnr()
  local start_row, start_col, end_row, end_col = node:range()
  local replacement = vim.split(text, '\n', { plain = true })
  if string.len(text) == 0 then
    replacement = {}
    if front_trim then
      start_col = math.max(start_col - 1, 0)
    else
      end_col = end_col + 1
    end
  end
  -- Some nodes have end range as row = next_line and col = 0
  -- for example a single line headline on line 10 gives
  -- (section: 10, 0, 11, 0) instead of (section: 10, 0, 10, 10)
  -- If we are setting text at the end of the file it will throw an out of range error
  -- To avoid that,get the last line number and it's last column
  local last_line = vim.api.nvim_buf_line_count(bufnr) - 1
  if end_row > last_line then
    end_row = last_line
    end_col = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1]:len()
  end
  local ok = pcall(vim.api.nvim_buf_set_text, bufnr, start_row, start_col, end_row, end_col, replacement)
  return ok
end

---@param node? TSNode
---@param lines string[]
---@return boolean
function OrgFile:set_node_lines(node, lines)
  if not node then
    return false
  end
  local bufnr = self:get_valid_bufnr()
  local start_row, _, end_row, _ = node:range()
  vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, lines)
  return true
end

---@return number
function OrgFile:bufnr()
  local bufnr = vim.fn.bufnr(self.filename) or -1
  -- Do not consider unloaded buffers as valid
  -- Treesitter is not working in them
  if bufnr > -1 and vim.api.nvim_buf_is_loaded(bufnr) then
    return bufnr
  end
  return -1
end

---Return valid buffer handle or throw an error if it's not valid
---@return number
function OrgFile:get_valid_bufnr()
  local bufnr = vim.fn.bufnr(self.filename) or -1
  if bufnr < 0 then
    error('[orgmode] No valid buffer for file ' .. self.filename .. ' to edit')
  end
  -- Do not consider unloaded buffers as valid
  -- Treesitter is not working in them
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    error('[orgmode] Cannot edit buffer ' .. tostring(bufnr) .. ' for file ' .. self.filename .. ', it is not loaded')
  end
  return bufnr
end

memoize('get_filetags')
--- Get tags list applied on file level via #+FILETAGS
--- @return string[]
function OrgFile:get_filetags()
  return utils.parse_tags_string(self:_get_directive('filetags'))
end

memoize('get_blocks')
--- @return OrgBlock[]
function OrgFile:get_blocks()
  local matches = self:get_ts_matches('(block) @block')
  return vim.tbl_map(function(match)
    return Block:new(match.block.node, self)
  end, matches)
end

function OrgFile:get_header_args()
  local header_args_prop = self:get_directive_property('header-args')
  if not header_args_prop then
    return vim.tbl_extend('force', {}, config.org_babel_default_header_args)
  end
  local header_args = config:parse_header_args(header_args_prop)
  return vim.tbl_extend('force', config.org_babel_default_header_args, header_args)
end

memoize('get_directive_property')
--- @param name string
--- @return string | nil
function OrgFile:get_directive_property(name)
  local properties = self:get_directive_properties()
  return properties[name:lower()]
end

memoize('get_directive_properties')
---@return table<string, string>
function OrgFile:get_directive_properties()
  self:parse(true)
  local properties = {}
  local directives_body = self.root:field('body')[1]
  if not directives_body then
    return properties
  end
  local directives = directives_body:field('directive')
  if not directives or #directives == 0 then
    return properties
  end

  for _, directive in ipairs(directives) do
    local name = directive:field('name')[1]
    local value = directive:field('value')[1]

    if name and value then
      local name_text = self:get_node_text(name)
      if name_text:lower() == 'property' then
        local value_items = vim.split(self:get_node_text(value), '%s+')
        if #value_items > 1 then
          properties[value_items[1]:lower()] = table.concat({ unpack(value_items, 2) }, ' ')
        end
      end
    end
  end

  return properties
end

memoize('get_drawer')
---@return table<string, string> | nil
function OrgFile:get_drawer(name)
  self:parse(true)
  local document_body = self.root:field('body')[1]
  if not document_body then
    return nil
  end

  local drawer = utils.find(ts_utils.get_named_children(document_body), function(node)
    if node:type() == 'drawer' then
      local drawer_name = node:field('name')[1]
      if drawer_name and self:get_node_text(drawer_name):lower() == name:lower() then
        return true
      end
    end
    return false
  end)

  if not drawer then
    return nil
  end

  return drawer
end

memoize('get_properties')
---@return table<string, string>, table<string, OrgRange>, TSNode | nil
function OrgFile:get_properties()
  local property_drawer = self:get_drawer('properties')
  if not property_drawer then
    return {}, {}, nil
  end
  local properties = {}
  local properties_ranges = {}
  local contents_node = property_drawer:field('contents')[1]
  local contents = self:get_node_text_list(contents_node)
  local start_line = contents_node and contents_node:start() or 0
  for i, line in ipairs(contents) do
    local property_name, property_value = line:match('^%s*:([^:]-):%s*(.*)$')
    if property_name and property_value then
      properties[property_name:lower()] = property_value
      properties_ranges[property_name:lower()] = Range.from_line(start_line + i)
    end
  end
  return properties, properties_ranges, property_drawer
end

memoize('get_property')
---@return string | nil, OrgRange
function OrgFile:get_property(name)
  local property_drawer, properties_ranges = self:get_properties()
  return property_drawer[name:lower()], properties_ranges[name:lower()]
end

---@param name string
---@param value? string
---@return OrgFile
function OrgFile:set_property(name, value)
  local bufnr = self:get_valid_bufnr()

  if not value then
    local existing_property, property_range = self:get_property(name)
    if existing_property and property_range then
      vim.fn.deletebufline(bufnr, property_range.start_line)
    end
    self:parse()
    local properties, _, properties_drawer = self:get_properties()
    if vim.tbl_isempty(properties) then
      self:set_node_lines(properties_drawer, {})
      self:parse()
    end
    return self
  end

  local _, _, properties_drawer = self:get_properties()
  local property = (':%s: %s'):format(name, value)

  if not properties_drawer then
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
      ':PROPERTIES:',
      property,
      ':END:',
    })
    self:parse()
    return self
  end

  local existing_property, property_range = self:get_property(name)
  if existing_property then
    vim.api.nvim_buf_set_lines(bufnr, property_range.start_line - 1, property_range.start_line, false, { property })
    self:parse()
    return self
  end

  local property_end = properties_drawer and properties_drawer:end_()
  vim.api.nvim_buf_set_lines(bufnr, property_end - 1, property_end - 1, false, { property })
  self:parse()
  return self
end

memoize('get_category')
--- Get the category name for this file
--- If no category is set, the filename without extension is returned
--- @return string
function OrgFile:get_category()
  local category = self:_get_directive('category')
  if category then
    return category
  end

  return vim.fn.fnamemodify(self.filename, ':t:r') or ''
end

memoize('get_title')
--- Get the title for this file
--- If no title is set, the filename without extension is returned
--- @return string
function OrgFile:get_title()
  local title = self:_get_directive('title')
  if title then
    return title
  end

  return vim.fn.fnamemodify(self.filename, ':t:r') or ''
end

memoize('get_opened_unfinished_headlines')
---@return OrgHeadline[]
function OrgFile:get_opened_unfinished_headlines()
  if self:is_archive_file() then
    return {}
  end

  return vim.tbl_filter(function(item)
    ---@cast item OrgHeadline
    return not item:is_archived() and not item:is_done()
  end, self:get_headlines())
end

--- Get the archive file location for this file
--- If this file is an archive file, it returns null
--- @return string | nil
function OrgFile:get_archive_file_location()
  local archive_location = self:_get_directive('archive')
  return config:parse_archive_location(self.filename, archive_location)
end

memoize('get_links')
---@return OrgLink[]
function OrgFile:get_links()
  self:parse(true)
  local ts_query = ts_utils.get_query([[
      (paragraph (expr) @links)
      (drawer (contents (expr) @links))
      (headline (item (expr)) @links)
  ]])

  local links = {}
  local processed_lines = {}
  for _, match in ts_query:iter_captures(self.root, self:_get_source()) do
    local line = match:start()
    if not processed_lines[line] then
      vim.list_extend(links, Link.all_from_line(self.lines[line + 1], line + 1))
      processed_lines[line] = true
    end
  end
  return links
end

memoize('get_directive')
---@param directive_name string
---@return string | nil
function OrgFile:get_directive(directive_name)
  return self:_get_directive(directive_name)
end

--- Get headline id or create a new one if it doesn't exist
--- @return string
function OrgFile:id_get_or_create()
  local id = self:get_property('id')
  if id then
    return id
  end
  local org_id = require('orgmode.org.id').new()
  self:set_property('ID', org_id)
  return org_id
end

---@private
---@return string | nil
function OrgFile:_get_directive(directive_name)
  self:parse(true)
  local directives_body = self.root:field('body')[1]
  if not directives_body then
    return nil
  end
  local directives = directives_body:field('directive')
  if not directives or #directives == 0 then
    return nil
  end

  for _, directive in ipairs(directives) do
    local name = directive:field('name')[1]
    local value = directive:field('value')[1]

    if name and value then
      local name_text = self:get_node_text(name)
      if name_text:lower() == directive_name:lower() then
        return self:get_node_text(value)
      end
    end
  end

  return nil
end

---@private
---@param lines string[]
---@param bufnr? number
function OrgFile:_update_lines(lines, bufnr)
  self.lines = lines
  self.content = table.concat(lines, '\n')
  self:parse()
  if bufnr then
    self.metadata.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  end
  local stat = vim.loop.fs_stat(self.filename)
  if stat then
    self.metadata.mtime = stat.mtime.nsec
  end
  return self
end

---@private
---@return vim.treesitter.LanguageTree
function OrgFile:_get_parser()
  local bufnr = self:bufnr()

  if bufnr > -1 then
    -- Always get the fresh parser for the buffer
    return ts.get_parser(bufnr, 'org', {})
  end

  -- In case the buffer got unloaded, go back to string parser
  if not self.parser or self:is_modified() or type(self.parser:source()) == 'number' then
    return ts.get_string_parser(self.content, 'org', {})
  end

  return self.parser
end

--- Get the ts source for the file
--- If there is a buffer, return buffer number
--- Otherwise, return the string content
---@private
---@return integer | string
function OrgFile:_get_source()
  local bufnr = self:bufnr()
  if bufnr > -1 then
    return bufnr
  end
  return self.content
end

return OrgFile
