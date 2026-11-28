local OrgFiles = require('orgmode.files')
local Date = require('orgmode.objects.date')
local ClockReport = require('orgmode.clock.report')

local created_dirs = {}

---@param lines string[]
---@return OrgFiles
local function build(lines)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  table.insert(created_dirs, dir)
  vim.fn.writefile(lines, dir .. '/clocks.org')
  local files = OrgFiles:new({ paths = dir .. '/*' })
  files:load_sync(true, 10000)
  return files
end

---Clock report for the agenda span starting at `from`, with the range built
---the way the agenda builds it.
---@param lines string[]
---@param from string
---@param span 'day' | 'week' | 'month'
---@return OrgClockReport
local function clock_report(lines, from, span)
  local start = Date.from_string(from)
  return ClockReport:new({
    from = start,
    to = start:add({ [span] = 1 }),
    files = build(lines),
  })
end

---@param lines string[]
---@param from string
---@param span 'day' | 'week' | 'month'
---@return number
local function report_minutes(lines, from, span)
  return clock_report(lines, from, span):generate_report().total_duration.minutes
end

---@param report OrgClockReport
---@param title string
---@return string[] | nil
local function table_row(report, title)
  for _, row in ipairs(report:get_table_report(1).rows) do
    local cells = vim.tbl_map(function(cell)
      return vim.trim(cell.content)
    end, row.cells)
    if cells[2] == title then
      return cells
    end
  end
end

-- Emacs: org-clock-sum (org-clock.el, Org 9.8.7) clips each clock to
-- [tstart, tend) and counts every CLOCK line of the entry, inside or outside
-- a drawer. The agenda clock report calls it through org-clock-get-clocktable
-- with :tstart and :tend set to the agenda span (org-agenda-list).
describe('Clock report', function()
  after_each(function()
    for _, dir in ipairs(created_dirs) do
      vim.fn.delete(dir, 'rf')
    end
    created_dirs = {}
  end)

  describe('clock across midnight', function()
    local lines = {
      '* Night shift',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-26 Thu 23:00]--[2026-11-27 Fri 01:00] =>  2:00',
      '  :END:',
    }

    it('counts only the part before midnight for the first day', function()
      assert.are.same(60, report_minutes(lines, '2026-11-26', 'day'))
    end)

    it('counts only the part after midnight for the second day', function()
      assert.are.same(60, report_minutes(lines, '2026-11-27', 'day'))
    end)
  end)

  it('does not count a clock that ends exactly at the start of the day', function()
    local lines = {
      '* Until midnight',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-26 Thu 23:30]--[2026-11-27 Fri 00:00] =>  0:30',
      '  :END:',
    }
    assert.are.same(0, report_minutes(lines, '2026-11-27', 'day'))
  end)

  it('does not count a clock that starts exactly at the end of the day', function()
    local lines = {
      '* From midnight',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-27 Fri 00:00]--[2026-11-27 Fri 00:20] =>  0:20',
      '  :END:',
    }
    assert.are.same(0, report_minutes(lines, '2026-11-26', 'day'))
  end)

  it('counts the whole day for a clock that covers the day', function()
    local lines = {
      '* Whole week',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-23 Mon 08:00]--[2026-11-28 Sat 08:00] => 120:00',
      '  :END:',
    }
    assert.are.same(24 * 60, report_minutes(lines, '2026-11-27', 'day'))
  end)

  describe('clock across a week boundary', function()
    local lines = {
      '* Sunday night',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-29 Sun 22:00]--[2026-11-30 Mon 02:00] =>  4:00',
      '  :END:',
    }

    it('counts only the part in the first week', function()
      assert.are.same(120, report_minutes(lines, '2026-11-23', 'week'))
    end)

    it('counts only the part in the second week', function()
      assert.are.same(120, report_minutes(lines, '2026-11-30', 'week'))
    end)
  end)

  describe('clock across a month boundary', function()
    local lines = {
      '* Month end',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-30 Mon 23:00]--[2026-12-01 Tue 01:00] =>  2:00',
      '  :END:',
    }

    it('counts only the part in the first month', function()
      assert.are.same(60, report_minutes(lines, '2026-11-01', 'month'))
    end)

    it('counts only the part in the second month', function()
      assert.are.same(60, report_minutes(lines, '2026-12-01', 'month'))
    end)
  end)

  it('counts the clocks of every logbook drawer of a headline', function()
    local lines = {
      '* Two drawers',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-26 Thu 14:00]--[2026-11-26 Thu 14:10] =>  0:10',
      '  :END:',
      '  Some text.',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-26 Thu 14:10]--[2026-11-26 Thu 14:20] =>  0:10',
      '  :END:',
    }
    assert.are.same(20, report_minutes(lines, '2026-11-26', 'day'))
  end)

  it('counts a clock line outside a drawer', function()
    local lines = {
      '* No drawer',
      '  CLOCK: [2026-11-26 Thu 15:00]--[2026-11-26 Thu 15:15] =>  0:15',
    }
    assert.are.same(15, report_minutes(lines, '2026-11-26', 'day'))
  end)

  it('lists the clipped time in the headline row of the table', function()
    local report = clock_report({
      '* Night shift',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-26 Thu 23:00]--[2026-11-27 Fri 01:00] =>  2:00',
      '  :END:',
    }, '2026-11-27', 'day')
    assert.are.same({ '', 'Night shift', '1:00' }, table_row(report, 'Night shift'))
  end)

  it('lists a parent without the clocks of its child and counts both once in the total', function()
    local report = clock_report({
      '* Parent',
      '  :LOGBOOK:',
      '  CLOCK: [2026-11-26 Thu 10:00]--[2026-11-26 Thu 10:30] =>  0:30',
      '  :END:',
      '** Child',
      '   :LOGBOOK:',
      '   CLOCK: [2026-11-26 Thu 11:00]--[2026-11-26 Thu 11:15] =>  0:15',
      '   :END:',
    }, '2026-11-26', 'day')
    assert.are.same({ '', 'Parent', '0:30' }, table_row(report, 'Parent'))
    assert.are.same({ '', 'Child', '0:15' }, table_row(report, 'Child'))
    assert.are.same(45, report:generate_report().total_duration.minutes)
  end)

  it('does not list a headline whose body dates are not clocks', function()
    local report = clock_report({
      '* Clocked',
      '  CLOCK: [2026-11-26 Thu 15:00]--[2026-11-26 Thu 15:15] =>  0:15',
      '* Meeting',
      '  Booked [2026-11-26 Thu 09:00]--[2026-11-26 Thu 10:00] and <2026-11-26 Thu 11:00>',
    }, '2026-11-26', 'day')
    local titles = vim.tbl_map(function(headline)
      return headline:get_title()
    end, report:generate_report().files_with_clocks[1].headlines)
    assert.are.same({ 'Clocked' }, titles)
  end)
end)
