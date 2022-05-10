local ts_utils = require('nvim-treesitter.ts_utils')
local tree_utils = require('orgmode.utils.treesitter')
local query = vim.treesitter.query
local Headline = require('orgmode.treesitter.headline')

local List = {}

function List:new(list_node)
  local data = { list = list_node }
  setmetatable(data, self)
  self.__index = self
  return data
end

-- Updates the cookie of the immediate parent
-- This always checks for a parent list first
-- then for a headline.
function List:parent_cookie()
  local parent_list = tree_utils.find_list(self.list:parent())
  if parent_list then
    -- We only care about the cookie if it's at the top
    local top_item = parent_list:named_child(0)
    local content = top_item:field('contents')[1]
    -- The cookie should be the last thing on the line
    local cookie_node = content:named_child(content:named_child_count() - 1)
    if query.get_node_text(cookie_node, 0):match('%[%d?/%d?%]') then
      return cookie_node
    end
  end

  local parent_header = Headline:new(tree_utils.closest_headline())
  return parent_header:cookie()
end

function List:update_parent_cookie()
  local parent_cookie = self:parent_cookie()
  if not parent_cookie then
    return
  end

  local checkboxes = self:checkboxes()
  local checked_boxes = vim.tbl_filter(function(box)
    return box:match('%[%w%]')
  end, checkboxes)
  local new_status = ('[%d/%d]'):format(#checked_boxes, #checkboxes)
  tree_utils.set_node_text(parent_cookie, new_status)
end

function List:checkboxes()
  return vim.tbl_map(function(node)
    local text = query.get_node_text(node, 0)
    return text:match('%[.%]')
  end, ts_utils.get_named_children(self.list))
end

return List
