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

---@class PairedTokenLocations
---@field content string The content that was detected for the token
---@field sindex integer The 0-indexed, starting position in the string the first token was found at
---@field eindex integer The 0-indexed ending position in the string the second token was found at

---Gets all positions of paried tokens
---@param str string The string to search
---@param token string The pair of strings to search for
---@param strict? boolean Should not allow reuse of end token from previous pair for new pair, default: true
---@param init? integer Starting position to search from in the string, default: 1
---@return PairedTokenLocations locations The paired token locations
function TextObjects.get_paired_token_locations(str, token, strict, init)
  strict = strict or true
  -- If the offset is 1, then it won't reuse the previous pair's token.
  -- Consider the following string where the token is `%`:
  --
  -- > Hello %world%, %goodbye!%
  --
  -- If the offset is 0 then on the first pair the starting index will be on the last `%` of
  -- 'world'. When the next pair is being found, it will be searching from that last `%` of 'world'
  -- up to the first `%` of 'goodbye!'. So the next pair will be from the last `%` of 'world' and the
  -- first `%` of 'goodbye!'
  --
  -- If the offset is 1, then the starting index will not be on a valid token and will consequently
  -- be moved forward to the first `%` of 'goodbye!' and then the end index for the pair will be set
  -- to the last `%` of 'goodbye!'.
  local offset = (strict and 1 or 0)
  local escaped_token = token:gsub('.', '%%%1')

  init = init or 1
  local locations = {}

  ---@type integer | nil
  local sindex = init
  ---@type integer | nil
  local eindex = init
  while sindex and eindex do
    sindex, eindex = str:find(escaped_token .. '(.-)' .. escaped_token, sindex)
    if sindex and eindex then
      local token_content = str:sub(sindex, eindex)
      table.insert(locations, { content = token_content, sindex = sindex - 1, eindex = eindex - 1 })
      sindex = eindex + offset
    end
  end

  return locations
end

---Creates a visual selection in or around the nearest pair of tokens identical to Vim's quote
---selection textobjects.
---@param token string The string to select in or around
---@param around boolean If true, the selection should be around the token, default: false
function TextObjects.select_nearest_token_pair(token, around)
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local cursor_pos = vim.api.nvim_win_get_cursor(win)
  ---The position of the cursor in the current window
  local cursor = {
    ---@type integer The one-indexed position of the cursor row
    row = cursor_pos[1],
    ---@type integer The one-indexed position of the cursor's column
    col = cursor_pos[2],
  }
  local cur_line_content = vim.api.nvim_buf_get_lines(buf, cursor.row - 1, cursor.row, true)[1]
  local matches = TextObjects.get_paired_token_locations(cur_line_content, token, true)
  if #matches == 0 then
    return
  end

  ---@type PairedTokenLocations
  local match
  for curr_match_index, curr_match in ipairs(matches) do
    -- We have a valid match location, we shouldn't search for any other matches as the match set
    -- will be the nearest match
    if match then
      break
    end

    -- If the cursor is within a pair of tokens, then that is the nearest match
    if cursor.col >= curr_match.sindex and cursor.col <= curr_match.eindex then
      match = curr_match
    -- If the cursor is behind a pair of tokens, then we want to correctly determine the correct
    -- match from there.
    elseif cursor.col < curr_match.sindex then
      local last_match = matches[curr_match_index - 1]
      -- If we have a previous pair of tokens that is behind our cursor (and since we're not in
      -- between a STRICT pair of tokens) we are between two tokens currently and should create a
      -- match coming from the end of the last pair of tokens and the start of the next pair.
      --
      -- Otherwise, the nearest match is the pair of tokens ahead of the cursor.
      if last_match then
        match = {
          sindex = last_match.eindex,
          eindex = curr_match.sindex,
        }
      else
        match = curr_match
      end
    end
  end

  if not match then
    return
  end

  if around then
    -- The way vim's default text objects work is if they have trailing whitespace, the around
    -- selection should also select the trailing whitespace. As such, we have to determine if
    -- there's trailing whitespace after the match and if so, extend the selection to include it.
    local whitespace_start, whitespace_end = cur_line_content:find('.%s*[^%S]', match.eindex)

    -- whitespace_start is 1-indexed, have to decrement it to compare it with the 0-indexed
    -- match.eindex
    if (whitespace_start and whitespace_end) and whitespace_start - 1 == match.eindex then
      match.eindex = whitespace_end - 1
    end
  else
    -- The match currently is selecting the tokens as well, reduce the match to bring it within the
    -- tokens for inner selection
    match.sindex = match.sindex + 1
    match.eindex = match.eindex - 1
  end

  vim.api.nvim_buf_set_mark(buf, '<', cursor.row, match.sindex, {})
  vim.api.nvim_buf_set_mark(buf, '>', cursor.row, match.eindex, {})
  vim.cmd('silent! normal! gv')
end

return TextObjects
