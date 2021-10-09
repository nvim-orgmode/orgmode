local Files = require('orgmode.parser.files')
local Table = require('orgmode.parser.table')
local Range = require('orgmode.parser.range')
local Duration = require('orgmode.objects.duration')

---@class ClockReport
---@field total_duration Duration
---@field from Date
---@field to Date
---@field files table[]
local ClockReport = {}

function ClockReport:new(opts)
  opts = opts or {}
  local data = {}
  data.from = opts.from
  data.to = opts.to
  data.total_duration = opts.total_duration
  data.files = opts.files or {}
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param start_line number
---@return table[]
function ClockReport:draw_for_agenda(start_line)
  local data = {
    { 'File', 'Headline', 'Time' },
    {},
    { '', 'ALL Total time', self.total_duration:to_string() },
    {},
  }

  for _, file in ipairs(self.files) do
    table.insert(data, { { value = file.name, reference = file }, 'File time', file.total_duration:to_string() })
    for _, headline in ipairs(file.headlines) do
      table.insert(data, {
        '',
        { value = headline.title, reference = headline },
        headline.logbook:get_total(self.from, self.to):to_string(),
      })
    end
    table.insert(data, {})
  end

  local clock_table = Table.from_list(data, start_line):compile()
  local result = {}
  for i, row in ipairs(clock_table.rows) do
    local highlights = {}
    local prev_row = clock_table.rows[i - 1]
    if prev_row and prev_row.is_separator then
      for _, cell in ipairs(row.cells) do
        local range = cell.range:clone()
        range.end_col = range.end_col + 1
        table.insert(highlights, {
          hlgroup = 'OrgBold',
          range = range,
        })
      end
    end

    table.insert(result, {
      line_content = row.content,
      is_table = true,
      table = clock_table,
      highlights = highlights,
    })
  end
  return result
end

---@param from Date
---@param to Date
---@return ClockReport
function ClockReport.from_date_range(from, to)
  local report = {
    from = from,
    to = to,
    total_duration = 0,
    files = {},
  }
  for _, orgfile in ipairs(Files.all()) do
    local file_clocks = orgfile:get_clock_report(from, to)
    if #file_clocks.headlines > 0 then
      report.total_duration = report.total_duration + file_clocks.total_duration.minutes
      table.insert(report.files, {
        name = orgfile.category .. '.org',
        total_duration = file_clocks.total_duration,
        headlines = file_clocks.headlines,
      })
    end
  end
  report.total_duration = Duration.from_minutes(report.total_duration)
  return ClockReport:new(report)
end

return ClockReport
