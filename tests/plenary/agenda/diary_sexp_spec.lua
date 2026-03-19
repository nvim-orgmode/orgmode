local helpers = require('tests.plenary.helpers')
local AgendaType = require('orgmode.agenda.types.agenda')
local Date = require('orgmode.objects.date')

describe('Diary Sexp in org files', function()
  it('includes anniversary entry on the correct day', function()
    local files = helpers.create_agenda_files({
      {
        filename = 'a.org',
        content = {
          '* TODO Holder',
          "%%(diary-anniversary 10 31 1948) Arthur's %d%s birthday",
        },
      },
    })

    local today = Date.from_string('1990-10-31 Wed') --[[@as OrgDate]]
    local org = require('orgmode')
    local files_api = org.files
    local highlighter = org.highlighter
    local AgendaFilter = require('orgmode.agenda.filter')
    local agenda = AgendaType:new({
      files = files_api,
      highlighter = highlighter,
      agenda_filter = AgendaFilter:new(),
      span = 'day',
      from = today,
    })

    agenda:prepare():wait()
    local view = agenda:render(0)
    local found = false
    for _, line in ipairs(view.lines) do
      local compiled = line:compile()
      if compiled.content:match("Arthur's") then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)

  it('works when placed outside any headline', function()
    helpers.create_agenda_files({
      {
        filename = 'b.org',
        content = {
          "%%(diary-anniversary 10 31 1948) Arthur's %d%s birthday",
        },
      },
    })

    local today = Date.from_string('1990-10-31 Wed') --[[@as OrgDate]]
    local org = require('orgmode')
    local files_api = org.files
    local highlighter = org.highlighter
    local AgendaFilter = require('orgmode.agenda.filter')
    local agenda = AgendaType:new({
      files = files_api,
      highlighter = highlighter,
      agenda_filter = AgendaFilter:new(),
      span = 'day',
      from = today,
    })

    agenda:prepare():wait()
    local view = agenda:render(0)
    local found_ordinal = false
    for _, line in ipairs(view.lines) do
      local compiled = line:compile()
      if compiled.content:match("Arthur's 42nd birthday") then
        found_ordinal = true
        break
      end
    end
    assert.is_true(found_ordinal)
  end)

  it('supports org-anniversary year month day with diary-remind', function()
    helpers.create_agenda_files({
      {
        filename = 'c.org',
        content = {
          "%%(diary-remind '(org-anniversary 2000 10 31) 14) %d. Test reminder",
        },
      },
    })

    local today = Date.from_string('2000-10-20 Fri') --[[@as OrgDate]]
    local org = require('orgmode')
    local files_api = org.files
    local highlighter = org.highlighter
    local AgendaFilter = require('orgmode.agenda.filter')
    local agenda = AgendaType:new({
      files = files_api,
      highlighter = highlighter,
      agenda_filter = AgendaFilter:new(),
      span = 'day',
      from = today,
    })

    agenda:prepare():wait()
    local view = agenda:render(0)
    local found = false
    for _, line in ipairs(view.lines) do
      local compiled = line:compile()
      if compiled.content:match('Test reminder') then
        found = true
        break
      end
    end
    assert.is_true(found)
  end)
end)

describe('Diary Sexp evaluator', function()
  local Sexpr = require('orgmode.diary.sexp')

  it('diary-remind matches only within N days before the event', function()
    local matcher = assert(Sexpr.parse("(diary-remind '(org-anniversary 2000 10 31) 14)"))
    assert.is_false(matcher:matches(Date.from_string('2000-10-15 Sun')))
    assert.is_true(matcher:matches(Date.from_string('2000-10-20 Fri')))
    assert.is_true(matcher:matches(Date.from_string('2000-10-31 Tue')))
    assert.is_false(matcher:matches(Date.from_string('2000-11-01 Wed')))
  end)

  it('diary-date matches a specific date', function()
    local matcher = assert(Sexpr.parse('(diary-date 3 14)'))
    assert.is_true(matcher:matches(Date.from_string('2025-03-14 Fri')))
    assert.is_true(matcher:matches(Date.from_string('2026-03-14 Sat')))
    assert.is_false(matcher:matches(Date.from_string('2025-03-15 Sat')))
    assert.is_false(matcher:matches(Date.from_string('2025-04-14 Mon')))
  end)

  it('diary-date with year matches only that year', function()
    local matcher = assert(Sexpr.parse('(diary-date 12 25 2025)'))
    assert.is_true(matcher:matches(Date.from_string('2025-12-25 Thu')))
    assert.is_false(matcher:matches(Date.from_string('2026-12-25 Fri')))
  end)

  it('diary-float matches nth weekday of month', function()
    -- 2nd Monday (dow=1) of March 2025
    local matcher = assert(Sexpr.parse('(diary-float 3 1 2)'))
    assert.is_true(matcher:matches(Date.from_string('2025-03-10 Mon')))
    assert.is_false(matcher:matches(Date.from_string('2025-03-03 Mon')))
    assert.is_false(matcher:matches(Date.from_string('2025-03-17 Mon')))
    assert.is_false(matcher:matches(Date.from_string('2025-04-10 Thu')))
  end)

  it('diary-float with t matches any month', function()
    -- 1st Friday (dow=5) of any month
    local matcher = assert(Sexpr.parse('(diary-float t 5 1)'))
    -- Jan 2025: 1st Friday is Jan 3
    assert.is_true(matcher:matches(Date.from_string('2025-01-03 Fri')))
    -- Feb 2025: 1st Friday is Feb 7
    assert.is_true(matcher:matches(Date.from_string('2025-02-07 Fri')))
    assert.is_false(matcher:matches(Date.from_string('2025-01-10 Fri')))
  end)

  it('diary-float with negative nth counts from end of month', function()
    -- Last Friday (dow=5) of March 2025
    local matcher = assert(Sexpr.parse('(diary-float 3 5 -1)'))
    assert.is_true(matcher:matches(Date.from_string('2025-03-28 Fri')))
    assert.is_false(matcher:matches(Date.from_string('2025-03-21 Fri')))
  end)

  it('boolean and combinator', function()
    -- Match March 14 AND it must be year 2025
    local matcher = assert(Sexpr.parse('(and (diary-date 3 14) (= year 2025))'))
    assert.is_true(matcher:matches(Date.from_string('2025-03-14 Fri')))
    assert.is_false(matcher:matches(Date.from_string('2026-03-14 Sat')))
  end)

  it('boolean or combinator', function()
    local matcher = assert(Sexpr.parse('(or (diary-date 1 1) (diary-date 12 25))'))
    assert.is_true(matcher:matches(Date.from_string('2025-01-01 Wed')))
    assert.is_true(matcher:matches(Date.from_string('2025-12-25 Thu')))
    assert.is_false(matcher:matches(Date.from_string('2025-06-15 Sun')))
  end)

  it('boolean not combinator', function()
    -- Every day except Sundays
    local matcher = assert(Sexpr.parse('(not (= dow 0))'))
    assert.is_true(matcher:matches(Date.from_string('2025-03-17 Mon')))
    assert.is_false(matcher:matches(Date.from_string('2025-03-16 Sun')))
  end)

  it('mod operator', function()
    -- Every other year starting from 2020
    local matcher = assert(Sexpr.parse('(= (mod year 2) 0)'))
    assert.is_true(matcher:matches(Date.from_string('2024-01-01 Mon')))
    assert.is_false(matcher:matches(Date.from_string('2025-01-01 Wed')))
  end)

  it('returns nil for malformed sexp', function()
    assert.is_nil(Sexpr.parse('((('))
    assert.is_nil(Sexpr.parse(''))
    assert.is_nil(Sexpr.parse(nil))
  end)

  it('malformed sexp does not match', function()
    local matcher = Sexpr.parse('(diary-anniversary)')
    -- Should parse but not match (missing args)
    if matcher then
      assert.is_false(matcher:matches(Date.from_string('2025-01-01 Wed')))
    end
  end)
end)

describe('Diary Sexp extract_remind_info', function()
  local Sexpr = require('orgmode.diary.sexp')

  it('extracts from org-anniversary', function()
    local m, d, n = Sexpr.extract_remind_info("(diary-remind '(org-anniversary 2000 10 31) 14)")
    assert.are.equal(10, m)
    assert.are.equal(31, d)
    assert.are.equal(14, n)
  end)

  it('extracts from diary-anniversary year-first', function()
    local m, d, n = Sexpr.extract_remind_info("(diary-remind '(diary-anniversary 1948 10 31) 7)")
    assert.are.equal(10, m)
    assert.are.equal(31, d)
    assert.are.equal(7, n)
  end)

  it('extracts from diary-anniversary month-first', function()
    local m, d, n = Sexpr.extract_remind_info("(diary-remind '(diary-anniversary 10 31 1948) 7)")
    assert.are.equal(10, m)
    assert.are.equal(31, d)
    assert.are.equal(7, n)
  end)

  it('extracts from diary-date', function()
    local m, d, n = Sexpr.extract_remind_info("(diary-remind '(diary-date 3 14) 5)")
    assert.are.equal(3, m)
    assert.are.equal(14, d)
    assert.are.equal(5, n)
  end)

  it('returns nil for non-remind expressions', function()
    local m, d, n = Sexpr.extract_remind_info('(org-anniversary 2000 10 31)')
    assert.is_nil(m)
    assert.is_nil(d)
    assert.is_nil(n)
  end)
end)

describe('Diary Sexp filtering', function()
  it('excludes diary-remind entries outside the window', function()
    helpers.create_agenda_files({
      {
        filename = 'd.org',
        content = {
          "%%(diary-remind '(org-anniversary 2000 10 31) 14) %d. Test reminder",
        },
      },
    })

    local day = Date.from_string('2000-10-15 Sun') -- 16 days before
    local org = require('orgmode')
    local AgendaFilter = require('orgmode.agenda.filter')
    local agenda = AgendaType:new({
      files = org.files,
      highlighter = org.highlighter,
      agenda_filter = AgendaFilter:new(),
      span = 'day',
      from = day,
    })

    agenda:prepare():wait()
    local view = agenda:render(0)
    local any = false
    for _, line in ipairs(view.lines) do
      if line:compile().content:match('Test reminder') then
        any = true
        break
      end
    end
    assert.is_false(any)
  end)

  it('shows only reminders within window for given day', function()
    helpers.create_agenda_files({
      {
        filename = 'e.org',
        content = {
          '* Urodziny',
          "%%(diary-remind '(org-anniversary 1920 01 02) 14) %d. urodziny Isaaca Asimova",
          "%%(diary-remind '(org-anniversary 1963 08 09) 14) %d. urodziny Whitney Houston",
          "%%(diary-remind '(org-anniversary 1959 03 08) 14) %d. urodziny Lester Holt",
        },
      },
    })

    local test_day = Date.from_string('2025-08-04 Mon')
    local org = require('orgmode')
    local AgendaFilter = require('orgmode.agenda.filter')
    local agenda = AgendaType:new({
      files = org.files,
      highlighter = org.highlighter,
      agenda_filter = AgendaFilter:new(),
      span = 'day',
      from = test_day,
    })

    agenda:prepare():wait()
    local view = agenda:render(0)
    local found_houston_day = false
    for _, line in ipairs(view.lines) do
      local compiled = line:compile().content
      if compiled:match('Houston') and compiled:match('In %d+ d%.:') then
        found_houston_day = true
      end
    end
    assert.is_true(found_houston_day)
  end)
end)
