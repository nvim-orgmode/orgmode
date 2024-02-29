local utils = require('orgmode.utils')
local Date = require('orgmode.objects.date')

---@class OrgDatetree
---@field files OrgFiles
local Datetree = {}
Datetree.__index = Datetree

---@param opts { files: OrgFiles }
function Datetree:new(opts)
  return setmetatable({
    files = opts.files,
  }, Datetree)
end

---@param template OrgCaptureTemplate
---@return OrgHeadline, number
function Datetree:create(template)
  local destination_file = self.files:get(template:get_target())
  local result = self:_get_datetree_destination(template)

  if result.create then
    self.files
      :update_file(destination_file.filename, function(file)
        vim.api.nvim_buf_set_lines(file:bufnr(), result.target_line, result.target_line, false, result.content)
      end)
      :wait()
    destination_file = destination_file:reload_sync()
  end

  local headline = destination_file:get_closest_headline({ result.headline_at, 0 })
  local opts = template:get_datetree_opts()
  local target_line = headline:get_range().end_line
  if opts.reversed then
    target_line = headline:get_range().start_line
  end
  return headline, target_line
end

---@param template OrgCaptureTemplate
function Datetree:_get_datetree_destination(template)
  local destination_file = self.files:get(template:get_target())
  local opts = template:get_datetree_opts()
  local date = opts.date
  local tree = self:_get_tree_by_type(opts)

  local top_level_headlines = destination_file:get_top_level_headlines()
  ---@type OrgHeadline[]
  local result = {}

  local create_levels = function(append_line)
    local target_line = append_line
    if not target_line then
      target_line = #destination_file.lines
      if #result > 0 then
        target_line = result[#result]:get_range().end_line
      end
    end
    local content = {}
    for i = (#result + 1), #tree do
      table.insert(content, string.rep('*', i) .. ' ' .. date:format(tree[i].format))
    end

    return {
      create = true,
      target_line = target_line,
      headline_at = target_line + (#tree - #result),
      content = content,
    }
  end

  for i, item in ipairs(tree) do
    local headlines = top_level_headlines
    if i > 1 then
      headlines = result[i - 1]:get_child_headlines()
    end

    local date_str = date:format(item.format)

    local existing_headline = utils.find(headlines, function(headline)
      return headline:get_title() == date_str
    end)

    if not existing_headline then
      local target_line = self:_find_target_line(headlines, item, date, opts.reversed)
      return create_levels(target_line)
    end

    table.insert(result, existing_headline)
  end

  return {
    create = false,
    headline_at = result[#result]:get_range().start_line,
  }
end

function Datetree:_find_target_line(headlines, tree_item, date, is_reversed)
  local sort_matches = function(matches)
    if not matches[1] then
      return nil
    end
    local sorted_matches = {}
    for k, i in ipairs(tree_item.order) do
      sorted_matches[k] = matches[i]
    end
    return sorted_matches
  end

  local date_str = date:format(tree_item.format)
  local date_matches = sort_matches({ date_str:match(tree_item.pattern) })
  assert(date_matches)

  local target_headline = utils.find(headlines, function(headline)
    local matches = sort_matches({ headline:get_title():match(tree_item.pattern) })
    if not matches then
      return false
    end

    for i = 1, #date_matches - 1 do
      if date_matches[i] ~= matches[i] then
        return false
      end
    end

    if is_reversed then
      return tonumber(matches[#matches]) < tonumber(date_matches[#date_matches])
    end
    return tonumber(matches[#matches]) > tonumber(date_matches[#date_matches])
  end)

  if target_headline then
    return target_headline:get_range().start_line - 1
  end

  return nil
end

---@private
---@param opts OrgCaptureTemplateDatetreeOpts
---@return OrgDatetreeTreeItem[]
function Datetree:_get_tree_by_type(opts)
  local trees = {
    -- Each entry in the tree is considered a headline.
    -- For example, this tree has 3 entries, and the result of it is:
    -- * YEAR
    -- ** MONTH
    -- *** DAY
    -- Level (stars) is determined by the index of the tree item.
    -- You can create any tree you want, but it must have at least one item,
    -- and have fields explained below
    --
    -- format: string
    -- The lua date format to use for the tree item. This will be used to create the headline.
    -- In this example, the format is '%Y', and it will create a year (example: 2024)
    --
    -- pattern: string
    -- The lua pattern used to parse important date parts from the formatted date.
    -- For example, if `format` is set to `%Y-%m-%d %A`, it will generate something like this:
    -- 2024-02-25 Sunday
    -- To be able to compare the dates in the datetree and figure out where to put the new entries,
    -- We need to parse the date parts from the formatted date. That's where the pattern comes in.
    -- With the lua pattern `^(%d%d%d%d)%-(%d%d)%-(%d%d).*$`, we parse year, month and day.
    -- Later, datetree can figure out where to put the new entry by comparing the parsed date parts.
    --
    -- order: number[]
    -- This is the array of numbers that works in conjuction with the pattern.
    -- It needs to contain the order of parsed date parts ordered by importance.
    -- For example, if the pattern is `^(%d%d%d%d)%-(%d%d)%-(%d%d).*$`, and the order is { 1, 2, 3 },
    -- This means that comparator will first check the year (first pattern match), then month (second pattern) and then day (last pattern).
    -- If we would want to use a date format DD.MM.YYYY, we would set all options like this:
    -- format = '%d.%m.%Y'
    -- pattern = '^(%d%d)%.(%d%d)%.(%d%d%d%d)$'
    -- order = { 3, 2, 1 }
    --
    -- Order is now 3, 2, 1 because we want to compare year first, which is the 3rd match,
    -- then month, which is 2nd match, and then day, which is first.
    day = {
      {
        format = '%Y',
        pattern = '^(%d%d%d%d)$',
        order = { 1 },
      },
      {
        format = '%Y-%m %B',
        pattern = '^(%d%d%d%d)%-(%d%d).*$',
        order = { 1, 2 },
      },
      {
        format = '%Y-%m-%d %A',
        pattern = '^(%d%d%d%d)%-(%d%d)%-(%d%d).*$',
        order = { 1, 2, 3 },
      },
    },
    month = {
      {
        format = '%Y',
        pattern = '^(%d%d%d%d)$',
        order = { 1 },
      },
      {
        format = '%Y-%m %B',
        pattern = '^(%d%d%d%d)%-(%d%d).*$',
        order = { 1, 2 },
      },
    },
    week = {
      {
        format = '%Y',
        pattern = '^(%d%d%d%d)$',
        order = { 1 },
      },
      {
        format = '%Y-W%V',
        pattern = '^(%d%d%d%d)%-W(%d%d).*$',
        order = { 1, 2 },
      },
      {
        format = '%Y-%m-%d %A',
        pattern = '^(%d%d%d%d)%-(%d%d)%-(%d%d).*$',
        order = { 1, 2, 3 },
      },
    },
  }

  if opts.tree_type == 'custom' and opts.tree then
    return opts.tree
  end

  return trees[opts.tree_type]
end

return Datetree
