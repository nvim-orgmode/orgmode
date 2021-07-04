local Types = require('orgmode.parser.types')
local parser = require('orgmode.parser')
local Range = require('orgmode.parser.range')
local Date = require('orgmode.objects.date')
local config = require('orgmode.config')

describe('Parser', function()
  it('should parse filetags headline', function()
    local lines = {
      '#+FILETAGS: :Tag1:Tag2:',
      '* TODO Something with a lot of tags :WORK:'
    }

    local parsed = parser.parse(lines, 'todos')
    assert.are.same(parsed.tags, {'Tag1', 'Tag2'})
    assert.are.same(false, parsed.is_archive_file)
    assert.are.same({
      content = {},
      dates = {},
      headlines = {},
      level = 1,
      line = "* TODO Something with a lot of tags :WORK:",
      id = 2,
      range = Range.from_line(2),
      parent = parsed,
      type = "HEADLINE",
      archived = false,
      title = 'Something with a lot of tags',
      priority = '',
      properties = { items = {} },
      todo_keyword = {
        type = 'TODO',
        value = 'TODO',
        range = Range:new({
          start_line = 2,
          end_line = 2,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'Tag1', 'Tag2', 'WORK'},
      category = 'todos',
      file = '',
    }, parsed:get_item(2))
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

    local parsed = parser.parse(lines, 'todos')
    assert.are.same({
      level = 0,
      line = "Top level content",
      range = Range.from_line(1),
      id = 1,
      parent = parsed,
      dates = {},
      type = "CONTENT",
    }, parsed:get_item(1))
    assert.are.same({
      content = {},
      dates = {},
      headlines = { parsed:get_item(3) },
      level = 1,
      line = "* TODO Test orgmode",
      range = Range:new({ start_line = 2, end_line = 6 }),
      id = 2,
      parent = parsed,
      priority = '',
      properties = { items = {} },
      title = 'Test orgmode',
      type = "HEADLINE",
      archived = false,
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'TODO',
        type = 'TODO',
        range = Range:new({
          start_line = 2,
          end_line = 2,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {},
    }, parsed:get_item(2))
    assert.are.same({
      content = { parsed:get_item(4) },
      dates = {},
      headlines = { parsed:get_item(5) },
      level = 2,
      line = "** TODO [#A] Test orgmode level 2 :PRIVATE:",
      range = Range:new({ start_line = 3, end_line = 6 }),
      id = 3,
      parent = parsed:get_item(2),
      priority = 'A',
      properties = { items = {} },
      title = '[#A] Test orgmode level 2',
      type = "HEADLINE",
      archived = false,
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'TODO',
        type = 'TODO',
        range = Range:new({
          start_line = 3,
          end_line = 3,
          start_col = 4,
          end_col = 7
        }),
      },
      tags = {'PRIVATE'},
    }, parsed:get_item(3))
    assert.are.same({
      level = 2,
      line = "Some content for level 2",
      id = 4,
      range = Range.from_line(4),
      dates = {},
      parent = parsed:get_item(3),
      type = "CONTENT",
    }, parsed:get_item(4))
    assert.are.same({
      content = { parsed:get_item(6) },
      dates = {},
      headlines = {},
      level = 3,
      line = "*** TODO [#1] Level 3",
      id = 5,
      range = Range:new({ start_line = 5, end_line = 6 }),
      parent = parsed:get_item(3),
      priority = '1',
      properties = { items = {} },
      title = '[#1] Level 3',
      type = "HEADLINE",
      archived = false,
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'TODO',
        type = 'TODO',
        range = Range:new({
          start_line = 5,
          end_line = 5,
          start_col = 5,
          end_col = 8
        }),
      },
      tags = {'PRIVATE'},
    }, parsed:get_item(5))
    assert.are.same({
      level = 3,
      line = "Content Level 3",
      id = 6,
      range = Range.from_line(6),
      dates = {},
      parent = parsed:get_item(5),
      type = "CONTENT",
    }, parsed:get_item(6))
    assert.are.same({
      content = { parsed:get_item(8) },
      dates = {},
      headlines = {},
      level = 1,
      line = "* DONE top level todo :WORK:",
      id = 7,
      priority = '',
      properties = { items = {} },
      range = Range:new({ start_line = 7, end_line = 8 }),
      title = 'top level todo',
      parent = parsed,
      type = "HEADLINE",
      archived = false,
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'DONE',
        type = 'DONE',
        range = Range:new({
          start_line = 7,
          end_line = 7,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'WORK'},
    }, parsed:get_item(7))
    assert.are.same({
      level = 1,
      line = "content for top level todo",
      id = 8,
      range = Range.from_line(8),
      parent = parsed:get_item(7),
      dates = {},
      type = "CONTENT",
    }, parsed:get_item(8))
    assert.are.same({
      content = { parsed:get_item(10) },
      dates = {},
      headlines = { parsed:get_item(11) },
      level = 1,
      line = "* TODO top level todo with multiple tags :OFFICE:PROJECT:",
      id = 9,
      range = Range:new({ start_line = 9, end_line = 11 }),
      parent = parsed,
      priority = '',
      properties = { items = {} },
      title = 'top level todo with multiple tags',
      type = "HEADLINE",
      archived = false,
      category = 'todos',
      file = '',
      todo_keyword = {
        value = 'TODO',
        type = 'TODO',
        range = Range:new({
          start_line = 9,
          end_line = 9,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'OFFICE', 'PROJECT'},
    }, parsed:get_item(9))
    assert.are.same({
      level = 1,
      line = "multiple tags content, tags not read from content :FROMCONTENT:",
      id = 10,
      range = Range.from_line(10),
      dates = {},
      parent = parsed:get_item(9),
      type = "CONTENT",
    }, parsed:get_item(10))
    assert.are.same({
      content = {},
      dates = {},
      headlines = {},
      level = 2,
      line = "** TODO Working on this now :OFFICE:NESTED:",
      id = 11,
      range = Range.from_line(11),
      parent = parsed:get_item(9),
      type = "HEADLINE",
      archived = false,
      category = 'todos',
      file = '',
      priority = '',
      properties = { items = {} },
      title = 'Working on this now',
      todo_keyword = {
        value = 'TODO',
        type = 'TODO',
        range = Range:new({
          start_line = 11,
          end_line = 11,
          start_col = 4,
          end_col = 7
        }),
      },
      tags = {'OFFICE', 'PROJECT', 'NESTED'},
    }, parsed:get_item(11))
    assert.are.same({
      content = {},
      dates = {},
      headlines = {},
      level = 1,
      line = "* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:",
      id = 12,
      range = Range.from_line(12),
      parent = parsed,
      priority = '',
      properties = { items = {} },
      title = 'NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
      type = "HEADLINE",
      archived = false,
      category = 'todos',
      file = '',
      todo_keyword = { value = '', type = '' },
      tags = {},
    }, parsed:get_item(12))
    assert.are.same(0, parsed.level)
    assert.are.same(0, parsed.id)
    assert.are.same(lines, parsed.lines)
    assert.are.same(false, parsed.is_archive_file)
    assert.are.same(Range:new({
      start_line = 1,
      end_line = 12
    }), parsed.range)
    assert.are.same(4, #parsed.headlines)
    assert.are.same(parsed.headlines[1], parsed.items[2])
    assert.are.same(parsed.headlines[2], parsed.items[7])
    assert.are.same(parsed.headlines[3], parsed.items[9])
    assert.are.same(parsed.headlines[4], parsed.items[12])
  end)

  it('should parse headline and its planning dates', function()
    local lines = {
      '* TODO Test orgmode <2021-05-15 Sat> :WORK:',
      'DEADLINE: <2021-05-20 Thu> SCHEDULED: <2021-05-18> CLOSED: <2021-05-21 Fri>',
      '* TODO get deadline only if first line after headline',
      'Some content',
      'DEADLINE: <2021-05-22 Sat>'
    }

    local parsed = parser.parse(lines, 'work')
    assert.are.same({
      content = { parsed:get_item(2) },
      dates = {
        Date.from_string('2021-05-15 Sat', {
          active = true,
          range = Range:new({
            start_line = 1,
            end_line = 1,
            start_col = 21,
            end_col = 36
          }),
        }),
        Date.from_string('2021-05-20 Thu', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 26
          }),
        }),
        Date.from_string('2021-05-18', {
          type = 'SCHEDULED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 39,
            end_col = 50
          }),
        }),
        Date.from_string('2021-05-21 Fri', {
          type = 'CLOSED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 60,
            end_col = 75
          }),
        }),
      },
      headlines = {},
      level = 1,
      line = "* TODO Test orgmode <2021-05-15 Sat> :WORK:",
      id = 1,
      range = Range:new({
        start_line = 1,
        end_line = 2,
      }),
      parent = parsed,
      priority = '',
      properties = { items = {} },
      title = 'Test orgmode <2021-05-15 Sat>',
      type = "HEADLINE",
      archived = false,
      category = 'work',
      file = '',
      todo_keyword = {
        value = 'TODO',
        type = 'TODO',
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'WORK'},
    }, parsed:get_item(1))
    assert.are.same({
      level = 1,
      line = "DEADLINE: <2021-05-20 Thu> SCHEDULED: <2021-05-18> CLOSED: <2021-05-21 Fri>",
      id = 2,
      range = Range:new({
        start_line = 2,
        end_line = 2,
      }),
      parent = parsed:get_item(1),
      type = "PLANNING",
      dates = {
        Date.from_string('2021-05-20 Thu', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 26
          }),
        }),
        Date.from_string('2021-05-18', {
          type = 'SCHEDULED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 39,
            end_col = 50
          }),
        }),
        Date.from_string('2021-05-21 Fri', {
          type = 'CLOSED',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 60,
            end_col = 75
          }),
        }),
      },
    }, parsed:get_item(2))
    assert.are.same({
      content = {parsed:get_item(4), parsed:get_item(5)},
      dates = {
        Date.from_string('2021-05-22 Sat', {
          active = true,
          type = 'NONE',
          range = Range:new({
            start_line = 5,
            end_line = 5,
            start_col = 11,
            end_col = 26
          }),
        }),
      },
      headlines = {},
      level = 1,
      line = "* TODO get deadline only if first line after headline",
      id = 3,
      range = Range:new({
        start_line = 3,
        end_line = 5,
      }),
      parent = parsed,
      priority = '',
      properties = { items = {} },
      title = 'get deadline only if first line after headline',
      type = "HEADLINE",
      archived = false,
      category = 'work',
      file = '',
      todo_keyword = {
        value = 'TODO',
        type = 'TODO',
        range = Range:new({
          start_line = 3,
          end_line = 3,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {},
    }, parsed:get_item(3))
    assert.are.same({
      level = 1,
      line = "Some content",
      range = Range:new({
        start_line = 4,
        end_line = 4,
      }),
      id = 4,
      dates = {},
      parent = parsed:get_item(3),
      type = "CONTENT",
    }, parsed:get_item(4))
    assert.are.same({
      level = 1,
      line = "DEADLINE: <2021-05-22 Sat>",
      dates = {
        Date.from_string('2021-05-22 Sat', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 5,
            end_line = 5,
            start_col = 11,
            end_col = 26
          }),
        }),
      },
      range = Range:new({
        start_line = 5,
        end_line = 5,
      }),
      id = 5,
      parent = parsed:get_item(3),
      type = Types.PLANNING,
    }, parsed:get_item(5))
  end)

  it('should parse drawer', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo'
    }

    local parsed = parser.parse(lines, 'work')
    assert.are.same({
      content = {
        parsed:get_item(2),
        parsed:get_item(3),
        parsed:get_item(4),
        parsed:get_item(5),
      },
      dates = {
        Date.from_string('2021-05-10 11:00', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 28
          }),
        }),
      },
      headlines = {},
      level = 1,
      line = "* TODO Test orgmode :WORK:",
      id = 1,
      range = Range:new({
        start_line = 1,
        end_line = 5,
      }),
      parent = parsed,
      type = "HEADLINE",
      archived = false,
      title = 'Test orgmode',
      priority = '',
      properties = {
        items = {
          SOME_PROP = 'some value'
        },
        range = Range:new({
          start_line = 3,
          end_line = 5,
        }),
        valid = true
      },
      todo_keyword = {
        value = 'TODO',
        type = 'TODO',
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 3,
          end_col = 6
        }),
      },
      tags = {'WORK'},
      category = 'work',
      file = '',
    }, parsed:get_item(1))
    assert.are.same({
      level = 1,
      line = "DEADLINE: <2021-05-10 11:00>",
      dates = {
        Date.from_string('2021-05-10 11:00', {
          type = 'DEADLINE',
          active = true,
          range = Range:new({
            start_line = 2,
            end_line = 2,
            start_col = 11,
            end_col = 28
          }),
        }),
      },
      range = Range:new({
        start_line = 2,
        end_line = 2,
      }),
      id = 2,
      parent = parsed:get_item(1),
      type = Types.PLANNING,
    }, parsed:get_item(2))
    assert.are.same({
      level = 1,
      line = ":PROPERTIES:",
      dates = {},
      range = Range:new({
        start_line = 3,
        end_line = 3,
      }),
      id = 3,
      parent = parsed:get_item(1),
      type = Types.DRAWER,
      drawer = {
        name = 'PROPERTIES',
      },
    }, parsed:get_item(3))
    assert.are.same({
      level = 1,
      line = ":SOME_PROP: some value",
      dates = {},
      range = Range:new({
        start_line = 4,
        end_line = 4,
      }),
      id = 4,
      parent = parsed:get_item(1),
      type = Types.DRAWER,
      drawer = {
        properties = {
          SOME_PROP = 'some value'
        },
      },
    }, parsed:get_item(4))
    assert.are.same({
      level = 1,
      line = ":END:",
      dates = {},
      range = Range:new({
        start_line = 5,
        end_line = 5,
      }),
      id = 5,
      parent = parsed:get_item(1),
      type = Types.DRAWER,
      drawer = {
        ended = true,
      },
    }, parsed:get_item(5))
  end)

  it('should not parse properties that are not in the :PROPERTIES: drawer', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo'
    }
    local parsed = parser.parse(lines, 'work')
    assert.are.same({ items = {} }, parsed:get_item(1).properties)
  end)

  it('should override headline category from property', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':END:',
      '* TODO Another todo'
    }
    local parsed = parser.parse(lines, 'work')
    assert.are.same('work', parsed:get_item(1):get_category())
    lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      ':PROPERTIES:',
      ':SOME_PROP: some value',
      ':CATEGORY: my-category',
      ':END:',
      '* TODO Another todo'
    }
    parsed = parser.parse(lines, 'work')
    assert.are.same('my-category', parsed:get_item(1):get_category())
  end)

  it('should parse source code #BEGIN_SRC filetype', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '#+BEGIN_SRC javascript',
      'console.log("test");',
      '#+END_SRC',
      '* TODO Another todo'
    }
    local parsed = parser.parse(lines, 'work')
    assert.are.same({'javascript'}, parsed.source_code_filetypes)
  end)

  it('should consider file archived if file name is matching org-archive-location setting', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '#+BEGIN_SRC javascript',
      'console.log("test");',
      '#+END_SRC',
      '* TODO Another todo'
    }
    local parsed = parser.parse(lines, 'work', '/tmp/my-work.org_archive', true)
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
      '*** TODO Child todo'
    }
    local parsed = parser.parse(lines, 'work', '')
    assert.are.same({'TOPTAG', 'WORK', 'MYPROJECT'}, parsed:get_item(3).tags)
    assert.are.same({'TOPTAG', 'WORK', 'MYPROJECT', 'CHILDPROJECT'}, parsed:get_item(5).tags)
    assert.are.same({'TOPTAG', 'WORK', 'MYPROJECT', 'CHILDPROJECT'}, parsed:get_item(7).tags)

    config:extend({ org_use_tag_inheritance = false })
    parsed = parser.parse(lines, 'work', '')
    assert.are.same({'WORK', 'MYPROJECT'}, parsed:get_item(3).tags)
    assert.are.same({'CHILDPROJECT'}, parsed:get_item(5).tags)
    assert.are.same({}, parsed:get_item(7).tags)

    config:extend({ org_use_tag_inheritance = true, org_tags_exclude_from_inheritance = {'MYPROJECT'} })
    parsed = parser.parse(lines, 'work', '')
    assert.are.same({'TOPTAG', 'WORK', 'MYPROJECT'}, parsed:get_item(3).tags)
    assert.are.same({'TOPTAG', 'WORK', 'CHILDPROJECT'}, parsed:get_item(5).tags)
    assert.are.same({'TOPTAG', 'WORK', 'CHILDPROJECT'}, parsed:get_item(7).tags)
  end)
end)
