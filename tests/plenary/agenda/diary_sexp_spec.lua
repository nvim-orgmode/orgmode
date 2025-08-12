local helpers = require('tests.plenary.helpers')
local AgendaType = require('orgmode.agenda.types.agenda')
local Date = require('orgmode.objects.date')

describe('Diary Sexp in org files', function()
  it("includes anniversary entry on the correct day", function()
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
  it('diary-remind matches only within N days before the event', function()
    local Sexpr = require('orgmode.diary.sexp')
    local Date = require('orgmode.objects.date')
    local matcher = assert(Sexpr.parse("(diary-remind '(org-anniversary 2000 10 31) 14)"))
    assert.is_false(matcher:matches(Date.from_string('2000-10-15 Sun')))
    assert.is_true(matcher:matches(Date.from_string('2000-10-20 Fri')))
    assert.is_true(matcher:matches(Date.from_string('2000-10-31 Tue')))
    assert.is_false(matcher:matches(Date.from_string('2000-11-01 Wed')))
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

    local day = Date.from_string('2025-08-04 Mon')
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
    local day = Date.from_string('2025-08-04 Mon')
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

