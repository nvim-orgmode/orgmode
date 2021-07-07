local Headline = require('orgmode.parser.headline')
local Content = require('orgmode.parser.content')
local AgendaItem = require('orgmode.agenda.agenda_item')
local Date = require('orgmode.objects.date')
local Highlights = require('orgmode.colors.highlights')
local config = require('orgmode.config')
local hl_map = Highlights.get_agenda_hl_map()

local function generate(content_line, keyword)
  keyword = keyword or 'TODO'
  local headline = Headline:new({
    line = '* '..keyword..' This is some content',
    lnum = 1,
    parent = { id = 0 },
  })
  local content = Content:new({
    line = content_line,
    lnum = 2,
    parent = { id = 1, level = 0 },
  })
  headline:add_content(content)
  return headline
end

describe('Agenda item', function()
  describe('for today', function()
    it('should consider inactive and closed dates invalid', function()
      local today = Date.now()
      local headline = generate(string.format('Inactive date [%s]', today:to_string()))
      local agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)

      headline = generate(string.format('CLOSED: <%s>', today:to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
    end)

    it('should consider non planning date only for today', function()
      local today = Date.now()
      local headline = generate(string.format('Some content <%s>', today:to_string()))
      local agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same(today:format_time()..'...... ', agenda_item.label)

      headline = generate(string.format('Some content <%s>', today:subtract({ day = 2 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)

      headline = generate(string.format('Some content <%s>', today:add({ day = 2 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
    end)

    it('should accept deadline date for today, past unfinished tasks and future tasks within warning period', function()
      local today = Date.now()
      -- today
      local headline = generate(string.format('DEADLINE: <%s>', today:to_string()))
      local agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.deadline },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same(today:format_time()..'...... Deadline:', agenda_item.label)

      -- past
      headline = generate(string.format('DEADLINE: <%s>', today:subtract({ day = 7 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.deadline },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('7 d. ago:', agenda_item.label)

      -- ignores past that are done
      headline = generate(string.format('DEADLINE: <%s>', today:subtract({ day = 7 }):to_string()), 'DONE')
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)

      -- ignores future that are done
      headline = generate(string.format('DEADLINE: <%s>', today:add({ day = 7 }):to_string()), 'DONE')
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)

      -- future without warning within the default warning days
      headline = generate(string.format('DEADLINE: <%s>', today:add({ day = 9 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('In 9 d.:', agenda_item.label)

      -- future without warning within the default warning days and less than 6 days (highlights as warning)
      headline = generate(string.format('DEADLINE: <%s>', today:add({ day = 6 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.warning },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('In 6 d.:', agenda_item.label)

      -- future with warning within the defined warning period
      headline = generate(string.format('DEADLINE: <%s -10d>', today:add({ day = 9 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('In 9 d.:', agenda_item.label)

      -- future with warning within the defined warning period and less than 6 days (highlights as warning)
      headline = generate(string.format('DEADLINE: <%s -10d>', today:add({ day = 6 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.warning },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('In 6 d.:', agenda_item.label)

      -- future with warning outside of defined warning period is not shown
      headline = generate(string.format('DEADLINE: <%s -7d>', today:add({ day = 8 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
    end)

    it('should accept scheduled for today, past unfinished, and unfinished adjusted for today or past', function()
      -- Today
      local today = Date.now()
      local headline = generate(string.format('SCHEDULED: <%s>', today:to_string()))
      local agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.ok },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same(today:format_time()..'...... Scheduled:', agenda_item.label)

      -- Past undone
      headline = generate(string.format('SCHEDULED: <%s>', today:subtract({ day = 7 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.warning },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('Sched. 7x:', agenda_item.label)

      -- Past done ignored
      headline = generate(string.format('SCHEDULED: <%s>', today:subtract({ day = 7 }):to_string()), 'DONE')
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)

      -- Future ignored
      headline = generate(string.format('SCHEDULED: <%s>', today:add({ day = 7 }):to_string()), 'DONE')
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)

      -- Undone adjusted for today shown
      headline = generate(string.format('SCHEDULED: <%s -2d>', today:subtract({ day = 2 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.warning },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('Sched. 2x:', agenda_item.label)

      -- Undone adjusted for today or past shown
      headline = generate(string.format('SCHEDULED: <%s -2d>', today:subtract({ day = 4 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.warning },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('Sched. 4x:', agenda_item.label)

      -- Done adjusted for today ignored
      headline = generate(string.format('SCHEDULED: <%s -2d>', today:subtract({ day = 2 }):to_string()), 'DONE')
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
    end)

    it('should not show scheduled DONE item if disabled in config', function()
      local today = Date.now()
      -- Scheduled done shown by default
      local headline = generate(string.format('SCHEDULED: <%s>', today:to_string()), 'DONE')
      local agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item.highlights)
      assert.are.same(today:format_time()..'...... Scheduled:', agenda_item.label)

      -- Deadline done shown by default
      local headline_deadline = generate(string.format('DEADLINE: <%s>', today:to_string()), 'DONE')
      local agenda_item_deadline = AgendaItem:new(headline_deadline.dates[1], headline_deadline, today)
      assert.is.True(agenda_item_deadline.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item_deadline.highlights)
      assert.are.same(today:format_time()..'...... Deadline:', agenda_item_deadline.label)

      config:extend({ org_agenda_skip_scheduled_if_done = true })

      -- Scheduled done hidden
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
      -- Deadline done still showing
      agenda_item_deadline = AgendaItem:new(headline_deadline.dates[1], headline_deadline, today)
      assert.is.True(agenda_item_deadline.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item_deadline.highlights)
      assert.are.same(today:format_time()..'...... Deadline:', agenda_item_deadline.label)

      config:extend({ org_agenda_skip_scheduled_if_done = false })
    end)

    it('should not show deadline DONE item if disabled in config', function()
      local today = Date.now()
      -- Scheduled done shown by default
      local headline = generate(string.format('SCHEDULED: <%s>', today:to_string()), 'DONE')
      local agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item.highlights)
      assert.are.same(today:format_time()..'...... Scheduled:', agenda_item.label)

      -- Deadline done shown by default
      local headline_deadline = generate(string.format('DEADLINE: <%s>', today:to_string()), 'DONE')
      local agenda_item_deadline = AgendaItem:new(headline_deadline.dates[1], headline_deadline, today)
      assert.is.True(agenda_item_deadline.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item_deadline.highlights)
      assert.are.same(today:format_time()..'...... Deadline:', agenda_item_deadline.label)

      config:extend({ org_agenda_skip_deadline_if_done = true })

      -- Scheduled done still showing
      assert.is.True(agenda_item.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE', } }, agenda_item.highlights)
      assert.are.same(today:format_time()..'...... Scheduled:', agenda_item.label)

      -- Deadline done hidden
      agenda_item_deadline = AgendaItem:new(headline_deadline.dates[1], headline_deadline, today)
      assert.is.False(agenda_item_deadline.is_valid)
      assert.are.same({}, agenda_item_deadline.highlights)
      assert.are.same('', agenda_item_deadline.label)

      config:extend({ org_agenda_skip_deadline_if_done = false })
    end)
  end)

  describe('for non today date', function()
    it('should consider inactive and closed dates invalid', function()
      local future_day = Date.now():add({ day = 3 })
      local headline = generate(string.format('Inactive date [%s]', future_day:to_string()))
      local agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)

      headline = generate(string.format('CLOSED: <%s>', future_day:to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
    end)

    it('should consider non planning date only for same day', function()
      -- Valid for same day
      local future_day = Date.now():add({ day = 3 })
      local headline = generate(string.format('Some content <%s>', future_day:to_string()))
      local agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same(future_day:format_time()..'...... ', agenda_item.label)

    -- Invalid for any other day
      headline = generate(string.format('Some content <%s>', future_day:add({ day = 1 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
    end)

    it('should consider deadline date only on same day', function()
      -- Valid for same day
      local future_day = Date.now():add({ day = 3 })
      local headline = generate(string.format('DEADLINE: <%s>', future_day:to_string()))
      local agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.deadline },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same(future_day:format_time()..'...... Deadline:', agenda_item.label)

      -- Green highlight if it's done
      headline = generate(string.format('DEADLINE: <%s>', future_day:to_string()), 'DONE')
      agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.ok },
        {
          hlgroup = hl_map.DONE,
          todo_keyword = 'DONE',
        }
      }, agenda_item.highlights)
      assert.are.same(future_day:format_time()..'...... Deadline:', agenda_item.label)

    -- Invalid for any other day
      headline = generate(string.format('DEADLINE: <%s>', future_day:add({ day = 1 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
    end)

    it('should consider scheduled for same day only if it doesnt have adjustments', function()
      -- Valid for same day, shows as green if it's future
      local future_day = Date.now():add({ day = 3 })
      local headline = generate(string.format('SCHEDULED: <%s>', future_day:to_string()))
      local agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        {
          hlgroup = hl_map.ok,
        },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same(future_day:format_time()..'...... Scheduled:', agenda_item.label)

      -- Valid for same day, shows as yellow if it's past
      local past_day = Date.now():subtract({ day = 3 })
      headline = generate(string.format('SCHEDULED: <%s>', past_day:to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, past_day)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        {
          hlgroup = hl_map.warning,
        },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same(past_day:format_time()..'...... Scheduled:', agenda_item.label)

      -- Invalid for any other day
      headline = generate(string.format('SCHEDULED: <%s>', future_day:add({ day = 1 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)

      -- Invalid if it has an adjustment
      headline = generate(string.format('SCHEDULED: <%s -2d>', future_day:add({ day = 1 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
    end)
  end)

  it('should properly add dot padding only when needed', function()
    local day_with_end_time = Date.now():set({ hour = 10, min = 0 })
    day_with_end_time.timestamp_end = day_with_end_time.timestamp + 3600

    local headline = generate(string.format('SCHEDULED: <%s>', day_with_end_time:to_string()))
    local agenda_item = AgendaItem:new(headline.dates[1], headline, day_with_end_time)
    assert.are.same('10:00-11:00 Scheduled:', agenda_item.label)

    local day_with_only_time = Date.now():set({ hour = 10, min = 0 })
    headline = generate(string.format('SCHEDULED: <%s>', day_with_only_time:to_string()))
    agenda_item = AgendaItem:new(headline.dates[1], headline, day_with_only_time)
    assert.are.same('10:00...... Scheduled:', agenda_item.label)
  end)

  it('should properly read date ranges bigger than current day', function()
    local range_start = Date.from_string('2021-06-13 Sun 13:30')
    local range_end = range_start:add({ day = 4, hour = 1 })
    local headline = generate(string.format('Some text <%s>--<%s>', range_start:to_string(), range_end:to_string()))
    local day = range_start:clone()
    local agenda_item = AgendaItem:new(headline.dates[1], headline, day)
    assert.is.True(agenda_item.is_valid)
    assert.are.same('13:30...... (1/5):', agenda_item.label)
    agenda_item = AgendaItem:new(headline.dates[2], headline, day)
    assert.is.False(agenda_item.is_valid)

    day = day:add({ day = 1 })
    agenda_item = AgendaItem:new(headline.dates[1], headline, day)
    assert.is.True(agenda_item.is_valid)
    assert.are.same('(2/5):', agenda_item.label)
    agenda_item = AgendaItem:new(headline.dates[2], headline, day)
    assert.is.False(agenda_item.is_valid)

    day = day:add({ day = 1 })
    agenda_item = AgendaItem:new(headline.dates[1], headline, day)
    assert.is.True(agenda_item.is_valid)
    assert.are.same('(3/5):', agenda_item.label)
    agenda_item = AgendaItem:new(headline.dates[2], headline, day)
    assert.is.False(agenda_item.is_valid)

    day = day:add({ day = 1 })
    agenda_item = AgendaItem:new(headline.dates[1], headline, day)
    assert.is.True(agenda_item.is_valid)
    assert.are.same('(4/5):', agenda_item.label)
    agenda_item = AgendaItem:new(headline.dates[2], headline, day)
    assert.is.False(agenda_item.is_valid)

    day = day:add({ day = 1 })
    agenda_item = AgendaItem:new(headline.dates[1], headline, day)
    assert.is.False(agenda_item.is_valid)

    agenda_item = AgendaItem:new(headline.dates[2], headline, day)
    assert.is.True(agenda_item.is_valid)
    assert.are.same('14:30...... (5/5):', agenda_item.label)
  end)

  it('should ignore end range if it is set to the same day as start day', function()
    local range_start = Date.from_string('2021-06-13 Sun 13:30')
    local range_end = range_start:add({ hour = 5 })
    local headline = generate(string.format('Some text <%s>--<%s>', range_start:to_string(), range_end:to_string()))
    local day = range_start:clone()
    local agenda_item = AgendaItem:new(headline.dates[1], headline, day)
    assert.is.True(agenda_item.is_valid)
    assert.are.same('13:30...... ', agenda_item.label)
    agenda_item = AgendaItem:new(headline.dates[2], headline, day)
    assert.is.False(agenda_item.is_valid)

    day = day:add({ day = 1 })
    agenda_item = AgendaItem:new(headline.dates[1], headline, day)
    assert.is.False(agenda_item.is_valid)
    agenda_item = AgendaItem:new(headline.dates[2], headline, day)
    assert.is.False(agenda_item.is_valid)
  end)

    it('should not show scheduled DONE item if disabled in config', function()
      local future_day = Date.now():add({ day = 2 })
      -- Scheduled done shown by default
      local headline = generate(string.format('SCHEDULED: <%s>', future_day:to_string()), 'DONE')
      local agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item.highlights)
      assert.are.same(future_day:format_time()..'...... Scheduled:', agenda_item.label)

      -- Deadline done shown by default
      local headline_deadline = generate(string.format('DEADLINE: <%s>', future_day:to_string()), 'DONE')
      local agenda_item_deadline = AgendaItem:new(headline_deadline.dates[1], headline_deadline, future_day)
      assert.is.True(agenda_item_deadline.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item_deadline.highlights)
      assert.are.same(future_day:format_time()..'...... Deadline:', agenda_item_deadline.label)

      config:extend({ org_agenda_skip_scheduled_if_done = true })

      -- Scheduled done hidden
      agenda_item = AgendaItem:new(headline.dates[1], headline, future_day)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
      -- Deadline done still showing
      agenda_item_deadline = AgendaItem:new(headline_deadline.dates[1], headline_deadline, future_day)
      assert.is.True(agenda_item_deadline.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item_deadline.highlights)
      assert.are.same(future_day:format_time()..'...... Deadline:', agenda_item_deadline.label)

      config:extend({ org_agenda_skip_scheduled_if_done = false })
    end)

    it('should not show deadline DONE item if disabled in config', function()
      local past_day = Date.now():subtract({ day = 2 })
      -- Scheduled done shown by default
      local headline = generate(string.format('SCHEDULED: <%s>', past_day:to_string()), 'DONE')
      local agenda_item = AgendaItem:new(headline.dates[1], headline, past_day)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item.highlights)
      assert.are.same(past_day:format_time()..'...... Scheduled:', agenda_item.label)

      -- Deadline done shown by default
      local headline_deadline = generate(string.format('DEADLINE: <%s>', past_day:to_string()), 'DONE')
      local agenda_item_deadline = AgendaItem:new(headline_deadline.dates[1], headline_deadline, past_day)
      assert.is.True(agenda_item_deadline.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE' } }, agenda_item_deadline.highlights)
      assert.are.same(past_day:format_time()..'...... Deadline:', agenda_item_deadline.label)

      config:extend({ org_agenda_skip_deadline_if_done = true })

      -- Scheduled done still showing
      assert.is.True(agenda_item.is_valid)
      assert.are.same({ { hlgroup = hl_map.ok }, { hlgroup = hl_map.DONE, todo_keyword = 'DONE', } }, agenda_item.highlights)
      assert.are.same(past_day:format_time()..'...... Scheduled:', agenda_item.label)

      -- Deadline done hidden
      agenda_item_deadline = AgendaItem:new(headline_deadline.dates[1], headline_deadline, past_day)
      assert.is.False(agenda_item_deadline.is_valid)
      assert.are.same({}, agenda_item_deadline.highlights)
      assert.are.same('', agenda_item_deadline.label)

      config:extend({ org_agenda_skip_deadline_if_done = false })
    end)
end)
