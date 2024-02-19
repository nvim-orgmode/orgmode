local Table = require('orgmode.files.elements.table')
local Duration = require('orgmode.objects.duration')

---@class OrgClockReport
---@field from OrgDate
---@field to OrgDate
---@field table OrgTable
---@field files OrgFiles
local ClockReport = {}

---@param opts { from: OrgDate, to: OrgDate, files: OrgFiles }
---@return OrgClockReport
function ClockReport:new(opts)
  opts = opts or {}
  local data = {}
  data.from = opts.from
  data.to = opts.to
  data.files = opts.files
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param start_line number
---@return table[]
function ClockReport:draw_for_agenda(start_line)
  local report = self:generate_report()
  local data = {
    { 'File', 'Headline', 'Time' },
    'hr',
    { '', 'ALL Total time', report.total_duration:to_string() },
    'hr',
  }

  for _, file in ipairs(report.files_with_clocks) do
    table.insert(data, { { value = file.name, reference = file }, 'File time', file.total_duration:to_string() })
    for _, headline in ipairs(file.headlines) do
      table.insert(data, {
        '',
        { value = headline:get_title(), reference = headline },
        headline:get_logbook():get_total(self.from, self.to):to_string(),
      })
    end
    table.insert(data, 'hr')
  end

  local clock_table = Table.from_list(data, start_line, 0):compile()
  self.table = clock_table
  local result = {}
  for i, row in ipairs(clock_table.rows) do
    local highlights = {}
    local prev_row = clock_table.rows[i - 1]
    if prev_row and prev_row.is_separator then
      for _, cell in ipairs(row.cells) do
        local range = cell.range:clone()
        range.start_col = range.start_col + 1
        range.end_col = range.end_col + 2
        table.insert(highlights, {
          hlgroup = '@org.bold',
          range = range,
        })
      end
    elseif i > 1 and not row.is_separator then
      for _, cell in ipairs(row.cells) do
        if cell.reference then
          local range = cell.range:clone()
          range.start_col = range.start_col + 1
          range.end_col = range.end_col + 2
          table.insert(highlights, {
            hlgroup = '@org.hyperlink',
            range = range,
          })
        end
      end
    end

    table.insert(result, {
      line_content = row.content,
      is_table = true,
      table_row = row,
      highlights = highlights,
    })
  end
  return result
end

function ClockReport:generate_report()
  local total_duration = 0
  local files_with_clocks = {}
  for _, orgfile in ipairs(self.files:all()) do
    local file_clocks = self:_get_clock_report_for_file(orgfile)
    if #file_clocks.headlines > 0 then
      total_duration = total_duration + file_clocks.total_duration.minutes
      table.insert(files_with_clocks, {
        name = orgfile:get_category() .. '.org',
        total_duration = file_clocks.total_duration,
        headlines = file_clocks.headlines,
      })
    end
  end

  return {
    total_duration = Duration.from_minutes(total_duration),
    files_with_clocks = files_with_clocks,
  }
end

function ClockReport:_get_clock_report_for_file(orgfile)
  local total_duration = 0
  local headlines = {}
  for _, headline in ipairs(orgfile:get_headlines()) do
    local logbook = headline:get_logbook()
    if logbook then
      local minutes = logbook:get_total_minutes(self.from, self.to)
      if minutes > 0 then
        table.insert(headlines, headline)
        total_duration = total_duration + minutes
      end
    end
  end

  return {
    headlines = headlines,
    total_duration = Duration.from_minutes(total_duration),
  }
end

---@param item table
function ClockReport:find_agenda_item(item)
  local line = vim.fn.line('.')
  local col = vim.fn.col('.')
  local found_cell = nil
  for _, cell in ipairs(item.table_row.cells) do
    if cell.range:is_in_range(line, col) then
      found_cell = cell
      break
    end
  end

  if found_cell and found_cell.reference then
    return {
      jumpable = true,
      file = found_cell.reference.file.filename,
      file_position = found_cell.reference:get_range().start_line,
    }
  end
  return {
    jumpable = false,
  }
end

return ClockReport
