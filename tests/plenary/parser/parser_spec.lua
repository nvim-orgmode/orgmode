local File = require('orgmode.parser.file')
local Range = require('orgmode.parser.range')
local Date = require('orgmode.objects.date')
local Duration = require('orgmode.objects.duration')
local config = require('orgmode.config')
local Logbook = require('orgmode.parser.logbook')

local function assert_section(root, section, expect)
  assert.are.same(expect.content or {}, section.content)
  assert.are.same(expect.dates or {}, section.dates)
  assert.are.same(expect.sections or {}, section.sections)
  assert.are.same(expect.line or '', section.line)
  assert.are.same(expect.line_number or 0, section.line_number)
  assert.are.same(expect.level or 0, section.level)
  assert.are.same(expect.title or '', section.title)
  assert.are.same(expect.priority or '', section.priority)
  assert.are.same(expect.properties_items or {}, section.properties.items)
  assert.are.same(expect.properties_range, section.properties.range)
  assert.are.same(expect.todo_keyword or { type = '', value = '' }, section.todo_keyword)
  assert.are.same(expect.tags or {}, section.tags)
  assert.are.same(expect.own_tags or {}, section:get_own_tags())
  assert.are.same(expect.category or 'todos', section.category)
  assert.are.same(expect.file or '', section.file)
  assert.are.same(root, section.root)
  assert.are.same(expect.parent, section.parent)
  assert.are.same(expect.logbook, section.logbook)
  assert.is.Not.Nil(section.node)
end

describe('Parser', function()
  it('should parse filetags headline', function()
    local lines = {
      '#+FILETAGS: :Tag1:Tag2:',
      '* TODO Something with a lot of tags :WORK:',
    }

    local parsed = File.from_content(lines, 'todos')
    assert.are.same(parsed.tags, { 'Tag1', 'Tag2' })
    assert.are.same(false, parsed.is_archive_file)
    assert_section(parsed, parsed:get_section(1), {
      line = '* TODO Something with a lot of tags :WORK:',
      title = 'Something with a lot of tags',
      line_number = 2,
      level = 1,
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 2,
          end_line = 2,
          start_col = 3,
          end_col = 6,
        }),
      },
      tags = { 'Tag1', 'Tag2', 'WORK' },
      own_tags = { 'WORK' },
    })
  end)

  it('should parse lines', function()
    local lines = {
      'Top level content',
      '* TODO Test orgmode',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** TODO [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** TODO Working on this now :OFFICE:NESTED:',
      '* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
    }

    local parsed = File.from_content(lines, 'todos')
    local first_section = parsed:get_section(1)

    assert_section(parsed, first_section, {
      sections = { parsed:get_section(2) },
      line = '* TODO Test orgmode',
      line_number = 2,
      level = 1,
      title = 'Test orgmode',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 2,
          end_line = 2,
          start_col = 3,
          end_col = 6,
        }),
      },
    })

    local second_section = parsed:get_section(2)

    assert_section(parsed, second_section, {
      content = { 'Some content for level 2' },
      sections = { parsed:get_section(3) },
      line = '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      line_number = 3,
      level = 2,
      title = '[#A] Test orgmode level 2',
      priority = 'A',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 3,
          end_line = 3,
          start_col = 4,
          end_col = 7,
        }),
      },
      tags = { 'PRIVATE' },
      own_tags = { 'PRIVATE' },
      parent = first_section,
    })

    local third_section = parsed:get_section(3)

    assert_section(parsed, third_section, {
      content = { 'Content Level 3' },
      line = '*** TODO [#1] Level 3',
      line_number = 5,
      level = 3,
      title = '[#1] Level 3',
      priority = '1',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 5,
          end_line = 5,
          start_col = 5,
          end_col = 8,
        }),
      },
      tags = { 'PRIVATE' },
      parent = second_section,
    })

    local fourth_section = parsed:get_section(4)

    assert_section(parsed, fourth_section, {
      content = { 'content for top level todo' },
      line = '* DONE top level todo :WORK:',
      line_number = 7,
      level = 1,
      title = 'top level todo',
      todo_keyword = {
        type = 'DONE',
        value = 'DONE',
        range = Range:new({
          start_line = 7,
          end_line = 7,
          start_col = 3,
          end_col = 6,
        }),
      },
      tags = { 'WORK' },
      own_tags = { 'WORK' },
    })

    local fifth_section = parsed:get_section(5)

    assert_section(parsed, fifth_section, {
      content = { 'multiple tags content, tags not read from content :FROMCONTENT:' },
      sections = { parsed:get_section(6) },
      line = '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      line_number = 9,
      level = 1,
      title = 'top level todo with multiple tags',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 9,
          end_line = 9,
          start_col = 3,
          end_col = 6,
        }),
      },
      tags = { 'OFFICE', 'PROJECT' },
      own_tags = { 'OFFICE', 'PROJECT' },
    })

    local sixth_section = parsed:get_section(6)

    assert_section(parsed, sixth_section, {
      line = '** TODO Working on this now :OFFICE:NESTED:',
      line_number = 11,
      level = 2,
      title = 'Working on this now',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 11,
          end_line = 11,
          start_col = 4,
          end_col = 7,
        }),
      },
      tags = { 'OFFICE', 'PROJECT', 'NESTED' },
      own_tags = { 'OFFICE', 'NESTED' },
      parent = fifth_section,
    })

    local seventh_section = parsed:get_section(7)

    assert_section(parsed, seventh_section, {
      line = '* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
      line_number = 12,
      level = 1,
      title = 'NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
    })
  end)

  it('should parse headline and its planning dates', function()
    local lines = {
      '* TODO Test orgmode <2021-05-15 Sat> :WORK:',
      'DEADLINE: <2021-05-20 Thu> SCHEDULED: <2021-05-18> CLOSED: [2021-05-21 Fri]',
      '* TODO get deadline only if first line after headline',
      'Some content',
      'DEADLINE: <2021-05-22 Sat>',
    }

    local parsed = File.from_content(lines, 'work')
    local first_section = parsed:get_section(1)
    assert_section(parsed, first_section, {
      line = '* TODO Test orgmode <2021-05-15 Sat> :WORK:',
      line_number = 1,
      level = 1,
      title = 'Test orgmode <2021-05-15 Sat>',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 3,
          end_col = 6,
        }),
      },
      tags = { 'WORK' },
      own_tags = { 'WORK' },
      category = 'work',
      dates = {
        Date.from_string('2021-05-15 Sat', {
          active = true,
          range = Range:new({
            start_line = 1,
            end_line = 1,
            start_col = 21,
            end_col = 36,
          }),
        }),
        Date.from_string('2021-05-20 Thu', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 26,
          }),
        }),
        Date.from_string('2021-05-18', {
          type = 'SCHEDULED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 39,
            end_col = 50,
          }),
        }),
        Date.from_string('2021-05-21 Fri', {
          type = 'CLOSED',
          active = false,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 60,
            end_col = 75,
          }),
        }),
      },
    })
  end)

  it('should properly parse non planning date from planning line', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      '<2021-10-01 Fri>',
      '* TODO get deadline only if first line after headline',
      'Some content',
      'DEADLINE: <2021-05-22 Sat>',
    }

    local parsed = File.from_content(lines, 'work')
    local first_section = parsed:get_section(1)
    assert_section(parsed, first_section, {
      line = '* TODO Test orgmode :WORK:',
      line_number = 1,
      level = 1,
      title = 'Test orgmode',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 3,
          end_col = 6,
        }),
      },
      tags = { 'WORK' },
      own_tags = { 'WORK' },
      category = 'work',
      dates = {
        Date.from_string('2021-10-01 Fri', {
          type = 'NONE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 1,
            end_col = 16,
          }),
        }),
      },
    })
  end)

  it('should parse properties drawer', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo',
    }

    local parsed = File.from_content(lines, 'work')
    assert_section(parsed, parsed:get_section(1), {
      line = '* TODO Test orgmode :WORK:',
      line_number = 1,
      level = 1,
      title = 'Test orgmode',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 3,
          end_col = 6,
        }),
      },
      dates = {
        Date.from_string('2021-05-10 11:00', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 28,
          }),
        }),
      },
      tags = { 'WORK' },
      own_tags = { 'WORK' },
      category = 'work',
      properties_items = {
        some_prop = 'some value',
      },
      properties_range = Range:new({
        start_line = 3,
        end_line = 5,
        start_col = 1,
        end_col = 0,
      }),
    })

    assert_section(parsed, parsed:get_section(2), {
      line = '* TODO Another todo',
      line_number = 6,
      level = 1,
      title = 'Another todo',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 6,
          end_line = 6,
          start_col = 3,
          end_col = 6,
        }),
      },
      category = 'work',
    })
  end)

  it('should not parse properties that are not in the :PROPERTIES: drawer', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local section = parsed:get_section(1)
    assert.are.same({ items = {} }, section.properties)
  end)

  it('should parse properties only if its positioned after headline or planning date', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      'Some content in between',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo',
    }

    local parsed = File.from_content(lines, 'work')
    local headline = parsed:get_section(1)
    assert.are.same({}, headline.properties.items)

    lines = {
      '* TODO Test orgmode :WORK:',
      'Some content in between',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo',
    }

    parsed = File.from_content(lines, 'work')
    headline = parsed:get_section(1)
    assert.are.same({}, headline.properties.items)

    lines = {
      '* TODO Test orgmode :WORK:',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo',
    }

    parsed = File.from_content(lines, 'work')
    headline = parsed:get_section(1)
    assert.are.same({ some_prop = 'some value' }, headline.properties.items)

    lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo',
    }

    parsed = File.from_content(lines, 'work')
    headline = parsed:get_section(1)
    assert.are.same({ some_prop = 'some value' }, headline.properties.items)
  end)

  it('should override headline category from property', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    assert.are.same('work', parsed:get_section(1):get_category())
    lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':CATEGORY: my-category',
      ':END:',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    assert.are.same('my-category', parsed:get_section(1):get_category())
  end)

  it('should parse source code #BEGIN_SRC filetype', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '#+BEGIN_SRC javascript',
      'console.log("test");',
      '#+END_SRC',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    assert.are.same({ 'javascript' }, parsed.source_code_filetypes)
  end)

  it('should consider file archived if file name is matching org-archive-location setting', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '#+BEGIN_SRC javascript',
      'console.log("test");',
      '#+END_SRC',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work', '/tmp/my-work.org_archive', true)
    assert.are.same(parsed.is_archive_file, true)
  end)

  it('should properly handle tag inheritance', function()
    local lines = {
      '#+FILETAGS: TOPTAG',
      '',
      '* TODO Test orgmode :WORK:MYPROJECT:',
      '  First level content',
      '** TODO Level 2 todo :CHILDPROJECT:',
      '   Second level content',
      '*** TODO Child todo',
    }
    local parsed = File.from_content(lines, 'work', '')
    assert.are.same({ 'TOPTAG', 'WORK', 'MYPROJECT' }, parsed:get_section(1).tags)
    assert.are.same({ 'TOPTAG', 'WORK', 'MYPROJECT', 'CHILDPROJECT' }, parsed:get_section(2).tags)
    assert.are.same({ 'TOPTAG', 'WORK', 'MYPROJECT', 'CHILDPROJECT' }, parsed:get_section(3).tags)

    config:extend({ org_use_tag_inheritance = false })
    parsed = File.from_content(lines, 'work', '')
    assert.are.same({ 'WORK', 'MYPROJECT' }, parsed:get_section(1).tags)
    assert.are.same({ 'CHILDPROJECT' }, parsed:get_section(2).tags)
    assert.are.same({}, parsed:get_section(3).tags)

    config:extend({ org_use_tag_inheritance = true, org_tags_exclude_from_inheritance = { 'MYPROJECT' } })
    parsed = File.from_content(lines, 'work', '')
    assert.are.same({ 'TOPTAG', 'WORK', 'MYPROJECT' }, parsed:get_section(1).tags)
    assert.are.same({ 'TOPTAG', 'WORK', 'CHILDPROJECT' }, parsed:get_section(2).tags)
    assert.are.same({ 'TOPTAG', 'WORK', 'CHILDPROJECT' }, parsed:get_section(3).tags)
  end)

  it('should parse logbook drawer', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      ':LOGBOOK:',
      ':CLOCK: [2021-09-23 Thu 10:00]--[2021-09-23 Thu 12:00] => 02:00',
      ':CLOCK: [2021-09-25 Sat 10:00]',
      ':END:',
      '* TODO Another todo',
    }

    local parsed = File.from_content(lines, 'work')
    local first_clock_start = Date.from_string('2021-09-23 10:00', {
      type = 'LOGBOOK',
      active = false,
      is_date_range_start = true,
      range = Range:new({
        start_line = 7,
        end_line = 7,
        start_col = 9,
        end_col = 30,
      }),
    })
    local first_clock_end = Date.from_string('2021-09-23 12:00', {
      type = 'LOGBOOK',
      active = false,
      is_date_range_end = true,
      related_date_range = first_clock_start,
      range = Range:new({
        start_line = 7,
        end_line = 7,
        start_col = 33,
        end_col = 54,
      }),
    })
    first_clock_start.related_date_range = first_clock_end
    assert_section(parsed, parsed:get_section(1), {
      line = '* TODO Test orgmode :WORK:',
      line_number = 1,
      level = 1,
      title = 'Test orgmode',
      content = { unpack(lines, 6, 9) },
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 3,
          end_col = 6,
        }),
      },
      dates = {
        Date.from_string('2021-05-10 11:00', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 28,
          }),
        }),
        first_clock_start,
        first_clock_end,
        Date.from_string('2021-09-25 10:00', {
          type = 'LOGBOOK',
          active = false,
          range = Range:new({
            start_line = 8,
            end_line = 8,
            start_col = 9,
            end_col = 30,
          }),
        }),
      },
      tags = { 'WORK' },
      own_tags = { 'WORK' },
      category = 'work',
      properties_items = {
        some_prop = 'some value',
      },
      properties_range = Range:new({
        start_line = 3,
        end_line = 5,
        start_col = 1,
        end_col = 0,
      }),
      logbook = Logbook:new({
        range = Range:new({
          start_line = 6,
          end_line = 9,
          start_col = 1,
          end_col = 0,
        }),
        items = {
          {
            start_time = first_clock_start,
            end_time = first_clock_end,
            duration = Duration.from_seconds(first_clock_end.timestamp - first_clock_start.timestamp),
          },
          {
            start_time = Date.from_string('2021-09-25 10:00', {
              type = 'LOGBOOK',
              active = false,
              range = Range:new({
                start_line = 8,
                end_line = 8,
                start_col = 9,
                end_col = 30,
              }),
            }),
          },
        },
      }),
    })

    assert_section(parsed, parsed:get_section(2), {
      line = '* TODO Another todo',
      line_number = 10,
      level = 1,
      title = 'Another todo',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 10,
          end_line = 10,
          start_col = 3,
          end_col = 6,
        }),
      },
      category = 'work',
    })
  end)

  it('should parse dates from headline', function()
    local lines = {
      '* TODO Test with date <2022-05-02 Mon 12:00>',
    }

    local parsed = File.from_content(lines, 'work', '')

    assert_section(parsed, parsed:get_section(1), {
      line = '* TODO Test with date <2022-05-02 Mon 12:00>',
      line_number = 1,
      level = 1,
      title = 'Test with date <2022-05-02 Mon 12:00>',
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 3,
          end_col = 6,
        }),
      },
      tags = {},
      own_tags = {},
      category = 'work',
      dates = {
        Date.from_string('2022-05-02 Mon 12:00', {
          type = 'NONE',
          active = true,
          range = Range:new({
            start_line = 1,
            end_line = 1,
            start_col = 23,
            end_col = 44,
          }),
        }),
      },
    })
  end)
end)
