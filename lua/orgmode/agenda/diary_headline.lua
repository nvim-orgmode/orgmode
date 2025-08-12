---@class OrgDiaryHeadline
---@field file OrgFile
---@field _title string
local DiaryHeadline = {}
DiaryHeadline.__index = DiaryHeadline

---@param opts { file: OrgFile, title: string }
function DiaryHeadline:new(opts)
  local data = {
    file = opts.file,
    _title = opts.title,
  }
  setmetatable(data, self)
  return data
end

function DiaryHeadline:is_done()
  return false
end

function DiaryHeadline:get_category()
  return self.file:get_category()
end

function DiaryHeadline:get_title()
  return self._title, 0
end

function DiaryHeadline:get_todo()
  return nil, nil, nil
end

function DiaryHeadline:get_priority()
  return '', nil
end

function DiaryHeadline:get_priority_sort_value()
  return math.huge
end

function DiaryHeadline:get_tags()
  return {}, nil
end

function DiaryHeadline:is_archived()
  return false
end

function DiaryHeadline:is_clocked_in()
  return false
end

return DiaryHeadline


