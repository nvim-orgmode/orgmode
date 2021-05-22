local Headline = require('orgmode.parser.headline')
local Content = require('orgmode.parser.content')
local AgendaItem = require('orgmode.agenda.agenda_item')
local Date = require('orgmode.objects.date')
local AgendaHighlights = require('orgmode.agenda.highlights')
local hl_map = AgendaHighlights.get_agenda_hl_map()

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
      assert.are.same('7 d. ago', agenda_item.label)

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
      assert.are.same('In 9 d.', agenda_item.label)

      -- future without warning within the default warning days and less than 6 days (highlights as warning)
      headline = generate(string.format('DEADLINE: <%s>', today:add({ day = 6 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.scheduledPast },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('In 6 d.', agenda_item.label)

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
      assert.are.same('In 9 d.', agenda_item.label)

      -- future with warning within the defined warning period and less than 6 days (highlights as warning)
      headline = generate(string.format('DEADLINE: <%s -10d>', today:add({ day = 6 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.scheduledPast },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('In 6 d.', agenda_item.label)

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
        { hlgroup = hl_map.scheduled },
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
        { hlgroup = hl_map.scheduledPast },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('Sched. 7x', agenda_item.label)

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
        { hlgroup = hl_map.scheduledPast },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('Sched. 2x', agenda_item.label)

      -- Undone adjusted for today or past shown
      headline = generate(string.format('SCHEDULED: <%s -2d>', today:subtract({ day = 4 }):to_string()))
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.True(agenda_item.is_valid)
      assert.are.same({
        { hlgroup = hl_map.scheduledPast },
        {
          hlgroup = hl_map.TODO,
          todo_keyword = 'TODO',
        }
      }, agenda_item.highlights)
      assert.are.same('Sched. 4x', agenda_item.label)

      -- Done adjusted for today ignored
      headline = generate(string.format('SCHEDULED: <%s -2d>', today:subtract({ day = 2 }):to_string()), 'DONE')
      agenda_item = AgendaItem:new(headline.dates[1], headline, today)
      assert.is.False(agenda_item.is_valid)
      assert.are.same({}, agenda_item.highlights)
      assert.are.same('', agenda_item.label)
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
        { hlgroup = hl_map.scheduled },
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
          hlgroup = hl_map.scheduled,
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
          hlgroup = hl_map.scheduledPast,
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
end)
