local Formatter = require('orgmode.agenda.view.formatter')
local AgendaItem = require('orgmode.agenda.agenda_item')
local Date = require('orgmode.objects.date')
local helpers = require('tests.plenary.helpers')

describe('Agenda formatter', function()
  local function generate_headline(content_line, title)
    title = title or 'This is some content'
    local file = helpers.create_file({
      '* TODO ' .. title,
      content_line,
    }, 'agenda_test.org')
    return file:get_headlines()[1]
  end

  it('should format category correctly', function()
    local today = Date.now()
    local headline = generate_headline(string.format('<%s>', today:to_string()))
    local agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    local metadata = { category_length = 10 }

    local format = '%c'
    local result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('agenda_test', result)

    format = '%-12c'
    result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('agenda_test ', result) -- agenda_test is 11 chars

    format = '%:c'
    result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('agenda_test:', result)
  end)

  it('should format time and scheduling correctly', function()
    local today = Date.now():set({ hour = 10, min = 0 })
    local headline = generate_headline(string.format('<%s>', today:to_string()))
    local agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    local metadata = { category_length = 10 }

    local format = '%t'
    local result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('10:00', result)

    headline = generate_headline(string.format('DEADLINE: <%s>', today:to_string()))
    agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    format = '%s'
    result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('Deadline:', result)
  end)

  it('should handle optional formatting with %?', function()
    local today = Date.now():set({ hour = 10, min = 0 })
    local headline = generate_headline(string.format('<%s>', today:to_string()))
    local agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    local metadata = { category_length = 10 }

    local format = '%?s'
    local result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('', result) -- s is empty

    headline = generate_headline(string.format('DEADLINE: <%s>', today:to_string()))
    agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('Deadline:', result)
  end)

  it('should handle optional space in format string', function()
    local today = Date.now():set({ hour = 10, min = 0 })
    local headline = generate_headline(string.format('<%s>', today:to_string()))
    local agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    local metadata = { category_length = 10 }

    local format = '% s'
    local result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('', result) -- s is empty

    headline = generate_headline(string.format('DEADLINE: <%s>', today:to_string()))
    agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    result = Formatter.format(format, agenda_item, metadata)
    assert.are.same(' Deadline:', result) -- notice the space
  end)

  it('should support evaluating expressions with %(...)', function()
    local today = Date.now()
    local headline = generate_headline(string.format('<%s>', today:to_string()))
    local agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    local metadata = { category_length = 10 }

    -- Define a global function for testing
    _G.test_prefix = function()
      return 'SHORT'
    end

    local format = '%(test_prefix())'
    local result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('SHORT', result)

    -- Test with width and alignment
    format = '%10(test_prefix())'
    result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('     SHORT', result)

    -- Test access to headline in the environment
    format = '%(headline:get_category())'
    result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('agenda_test', result)

    -- Test access to item marker
    format = '%(item.marker)'
    headline = generate_headline(string.format('DEADLINE: <%s>', today:to_string()))
    agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('Deadline:', result)

    _G.test_prefix = nil
  end)

  it('should handle multiple placeholders', function()
    local today = Date.now():set({ hour = 10, min = 0 })
    local headline = generate_headline(string.format('DEADLINE: <%s>', today:to_string()))
    local agenda_item = AgendaItem:new(headline:get_all_dates()[1], headline, today)
    local metadata = { category_length = 10 }

    local format = '%c %t %s'
    local result = Formatter.format(format, agenda_item, metadata)
    assert.are.same('agenda_test 10:00 Deadline:', result)
  end)
end)
