local Files = require('orgmode.parser.files')
local Table = require('orgmode.parser.table')
local Duration = require('orgmode.objects.duration')

---@class AgendaClockReport
---@field total_duration Duration
---@field files table[]
local AgendaClockReport = {}

function AgendaClockReport:new(opts)
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

function AgendaClockReport:draw_for_agenda()
  local data = {
    { 'File', 'Headline', 'Time' },
    {},
    { '', 'ALL Total time', self.total_duration:to_string() },
    {},
  }

  for _, file in ipairs(self.files) do
    table.insert(data, { file.name, 'File time', file.total_duration:to_string() })
    for _, headline in ipairs(file.headlines) do
      table.insert(data, { '', headline.title, headline.logbook:get_total():to_string() })
    end
    table.insert(data, {})
  end

  local table = Table.from_list(data)
  return vim.tbl_map(function(row)
    return {
      line_content = row,
      is_table = true,
    }
  end, table:draw())
end

---@param from Date
---@param to Date
---@return AgendaClockReport
function AgendaClockReport.from_range(from, to)
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
  return AgendaClockReport:new(report)
end

return AgendaClockReport
