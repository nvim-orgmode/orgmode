local ts_utils = require('orgmode.utils.treesitter')
local TextObjects = {}

local function get_range_for_node_range(start_line, end_line, end_col)
  -- Node ranges are 0 indexed
  local start_range = start_line + 1
  local end_range = end_line + 1
  -- Sections range ends on next line with col value of 0, and we need to subtract 1 to get correct end line
  if end_col == 0 and start_line ~= end_line then
    end_range = end_range - 1
  end
  return { start_range = start_range, end_range = end_range }
end

local function get_current_section_range()
  local node = ts_utils.get_node_at_cursor()
  if not node then
    return
  end
  while node and node:type() ~= 'section' do
    node = node:parent()
  end
  if not node then
    return
  end
  local start_line, _, end_line, end_col = node:range()
  local children = ts_utils.get_named_children(node)
  if children[#children]:type() == 'section' then
    for _, child in ipairs(children) do
      if child:type() == 'section' then
        local s, _, _, ec = child:range()
        end_line = s
        end_col = ec
        break
      end
    end
  end

  return get_range_for_node_range(start_line, end_line, end_col)
end

---@param ranges table
---@param exclude_stars boolean
local function do_selection(ranges, exclude_stars)
  local start_range = ranges.start_range
  local end_range = ranges.end_range
  local col = 1
  if exclude_stars then
    local _, offset = vim.fn.getline(start_range):find('^%*+%s*')
    col = col + offset
  end
  vim.fn.cursor({ start_range, col })
  local down_motion = ''
  if (end_range - start_range) > 0 then
    down_motion = string.format('%dgg', end_range)
  end
  local visual_mode = exclude_stars and 'v' or 'V'
  local goto_line_end = exclude_stars and '$' or ''
  vim.cmd(string.format('norm!%s%s%s', visual_mode, down_motion, goto_line_end))
end

local function current_heading(exclude_stars)
  local range = get_current_section_range()
  if range then
    do_selection(range, exclude_stars)
  end
end

local function current_subtree(exclude_stars)
  local node = ts_utils.closest_node(ts_utils.get_node_at_cursor(), 'section')
  if not node then
    return
  end
  local start_range, _, end_range, end_col = node:range()
  do_selection(get_range_for_node_range(start_range, end_range, end_col), exclude_stars)
end

local function current_heading_from_root(exclude_stars)
  local end_range = get_current_section_range().end_range
  local node = ts_utils.get_node_at_cursor()
  if not node then
    return
  end
  while node do
    local parent = node:parent()
    if not parent or parent:type() == 'document' then
      break
    end
    node = parent
  end
  local start_range, _, _, end_col = node:range()
  do_selection(get_range_for_node_range(start_range, end_range, end_col), exclude_stars)
end

local function current_subtree_from_root(exclude_stars)
  local node = ts_utils.get_node_at_cursor()
  if not node then
    return
  end
  while node do
    local parent = node:parent()
    if not parent or parent:type() == 'document' then
      break
    end
    node = parent
  end
  local start_range, _, end_range, end_col = node:range()
  do_selection(get_range_for_node_range(start_range, end_range, end_col), exclude_stars)
end

function TextObjects.inner_heading()
  current_heading(true)
end

function TextObjects.around_heading()
  current_heading(false)
end

function TextObjects.inner_subtree()
  current_subtree(true)
end

function TextObjects.around_subtree()
  current_subtree(false)
end

function TextObjects.inner_heading_from_root()
  current_heading_from_root(true)
end

function TextObjects.around_heading_from_root()
  current_heading_from_root(false)
end

function TextObjects.inner_subtree_from_root()
  current_subtree_from_root(true)
end

function TextObjects.around_subtree_from_root()
  current_subtree_from_root(false)
end

return TextObjects
