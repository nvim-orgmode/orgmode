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
---@return OrgHeadline
function Datetree:create(template)
  local date = template:get_datetree_date()
  local destination_file = self.files:get(template:get_target())
  local result = self:_get_datetree_destination(destination_file, date)

  if result.create then
    self.files
      :update_file(destination_file.filename, function(file)
        vim.api.nvim_buf_set_lines(file:bufnr(), result.target_line, result.target_line, false, result.content)
      end)
      :wait()
    destination_file = destination_file:reload_sync()
  end

  return destination_file:get_closest_headline({ result.headline_at, 0 })
end

---@private
---@param destination_file OrgFile
---@param date OrgDate
---@return { create: boolean, target_line: number, content: string[], headline_at: number }
function Datetree:_get_datetree_destination(destination_file, date)
  local year_date = date:format('%Y')
  local month_date = date:start_of('month')
  local month_date_str = date:format('%Y-%m %B')
  local day_date = date:format('%Y-%m-%d %A')
  local year_headline = utils.find(destination_file:get_top_level_headlines(), function(headline)
    return headline:get_title() == year_date
  end)

  if not year_headline then
    local target_line = self:_get_insert_year_at(destination_file, year_date)
    return {
      create = true,
      target_line = target_line,
      headline_at = target_line + 3,
      content = {
        '* ' .. year_date,
        '** ' .. month_date_str,
        '*** ' .. day_date,
      },
    }
  end

  local month_headline = utils.find(year_headline:get_child_headlines(), function(month)
    return month:get_title() == month_date_str
  end)

  if not month_headline then
    local target_line = self:_get_insert_month_at(year_headline, month_date)
    return {
      create = true,
      target_line = target_line,
      headline_at = target_line + 2,
      content = {
        '** ' .. month_date_str,
        '*** ' .. day_date,
      },
    }
  end

  local month_headlines = month_headline:get_child_headlines()
  local day_headline = utils.find(month_headlines, function(day)
    return day:get_title() == day_date
  end)

  if not day_headline then
    local target_line = self:_get_insert_day_at(month_headline, date)

    return {
      create = true,
      target_line = target_line,
      headline_at = target_line + 1,
      content = {
        '*** ' .. day_date,
      },
    }
  end

  return {
    create = false,
    headline_at = day_headline:get_range().start_line,
  }
end

---@private
---@param destination_file OrgFile
---@param year_date string -- year in format YYYY
---@return number
function Datetree:_get_insert_year_at(destination_file, year_date)
  local future_year_headline = utils.find(destination_file:get_top_level_headlines(), function(headline)
    local get_year = headline:get_title():match('^%d%d%d%d$')
    return get_year and tonumber(get_year) > tonumber(year_date)
  end)

  if future_year_headline then
    return future_year_headline:get_range().start_line - 1
  end

  return #destination_file.lines
end

---@private
---@param year_headline OrgHeadline
---@param month_date OrgDate
---@return number
function Datetree:_get_insert_month_at(year_headline, month_date)
  local future_month_headline = utils.find(year_headline:get_child_headlines(), function(headline)
    local year_num, month_num = headline:get_title():match('^(%d%d%d%d)%-(%d%d)%s+%w+$')
    if year_num and month_num then
      local timestamp = os.time({ year = year_num, month = month_num, day = 1 })
      return timestamp > month_date.timestamp
    end
    return false
  end)

  if future_month_headline then
    return future_month_headline:get_range().start_line - 1
  end

  return year_headline:get_range().end_line
end

---@private
---@param month_headline OrgHeadline
---@param date OrgDate
---@return number
function Datetree:_get_insert_day_at(month_headline, date)
  local future_day_headline = utils.find(month_headline:get_child_headlines(), function(headline)
    local year_num, month_num, day_num = headline:get_title():match('^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+%w+$')
    return year_num
      and Date.from_table({
        year = year_num,
        month = month_num,
        day = day_num,
      }):is_after(date, 'day')
  end)

  if future_day_headline then
    return future_day_headline:get_range().start_line - 1
  end

  return month_headline:get_range().end_line
end

return Datetree
