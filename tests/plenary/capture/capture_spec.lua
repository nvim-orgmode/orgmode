local Capture = require('orgmode.capture')
local Templates = require('orgmode.capture.templates')
local Template = require('orgmode.capture.template')
local helpers = require('tests.plenary.helpers')
local org = require('orgmode')

describe('Menu Items', function()
  it('should create a menu item for each template', function()
    local templates = Templates:new({
      t = {
        description = 'todo',
      },
      b = {
        description = 'bookmark',
      },
      f = {
        description = 'file update',
      },
    })
    ---@diagnostic disable-next-line: invisible
    local menu_items = Capture:_create_menu_items(templates:get_list())
    assert.are.same(#menu_items, 3)
    assert.are.same(
      { 'b', 'f', 't' },
      vim.tbl_map(function(x)
        return x.key
      end, vim.fn.sort(menu_items))
    )
  end)

  it('should create one entry for multi-key shortcuts', function()
    local multikey_templates = Templates:new({
      k = 'Multikey templates',
      kt = {
        description = 'multikey todo',
      },
      kb = 'multikey bookmark',
      kbb = {
        description = 'browser bookmark',
      },
      kbf = {
        description = 'file bookmark',
      },
    })
    ---@diagnostic disable-next-line: invisible
    local menu_items = Capture:_create_menu_items(multikey_templates:get_list())
    assert.are.same(#menu_items, 1)
    assert.are.same(
      { 'k' },
      vim.tbl_map(function(x)
        return x.key
      end, vim.fn.sort(menu_items))
    )
  end)

  it('computes the sub templates', function()
    local multikey_templates = Templates:new({
      k = 'Multikey templates',
      kt = {
        description = 'multikey todo',
      },
      kb = 'multikey bookmark',
      kbb = {
        description = 'browser bookmark',
      },
      kbf = {
        description = 'file bookmark',
      },
    })
    ---@diagnostic disable-next-line: invisible
    local sub_template_items = Capture:_get_subtemplates('k', multikey_templates:get_list())
    local expected = Templates:new({
      b = 'multikey bookmark',
      bb = {
        description = 'browser bookmark',
      },
      bf = {
        description = 'file bookmark',
      },
      t = {
        description = 'multikey todo',
      },
    }):get_list()
    assert.are.same(expected, sub_template_items)
  end)

  it('should create one entry for multi-key shortcuts with subtemplates', function()
    local multikey_templates = Templates:new({
      k = {
        description = 'Multikey templates',
        subtemplates = {
          t = {
            description = 'multikey todo',
          },
          b = {
            description = 'multikey bookmark',
            subtemplates = {
              b = {
                description = 'browser bookmark',
              },
              f = {
                description = 'file bookmark',
              },
            },
          },
        },
      },
    })
    ---@diagnostic disable-next-line: invisible
    local menu_items = Capture:_create_menu_items(multikey_templates:get_list())
    assert.are.same(#menu_items, 1)
    assert.are.same(
      { 'k' },
      vim.tbl_map(function(x)
        return x.key
      end, vim.fn.sort(menu_items))
    )
  end)

  it('adds an ellipses', function()
    local templates = Templates:new({
      k = 'Multikey template',
    })
    ---@diagnostic disable-next-line: invisible
    local menu_item = Capture:_create_menu_items(templates:get_list())
    assert.are.same('Multikey template...', menu_item[1].label)
  end)
end)

describe('Refile', function()
  it('to empty file', function()
    local destination_file = helpers.create_file({})

    local capture_lines = {
      '* bar',
      '* foo',
      '* baz',
    }
    local capture_file = helpers.create_file(capture_lines)
    local source_headline = capture_file:get_headlines()[2]

    ---@diagnostic disable-next-line: invisible
    org.capture:_refile_from_org_file({
      source_headline = source_headline,
      destination_file = destination_file,
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* foo',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('to end', function()
    local destination_file = helpers.create_file({
      '* foobar',
      '        ',
      '',
      '\t\t\t\t',
      '',
    })

    local capture_lines = {
      '* foo',
      '** baz',
      '* bar',
    }
    local capture_file = helpers.create_file(capture_lines)
    assert(capture_file)
    local item = capture_file:get_headlines()[2]

    ---@diagnostic disable-next-line: invisible
    org.capture:_refile_from_org_file({
      destination_file = destination_file,
      source_headline = item,
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* foobar',
      '* baz',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
  it('to headline', function()
    local destination_file = helpers.create_file({
      '* foobar',
      '        ',
      '',
      '\t\t\t\t',
      '',
      '* barbar',
      '',
      '        ',
      '',
    })

    local capture_lines = { '** baz' }
    local capture_file = helpers.create_file_instance(capture_lines)
    local item = capture_file:get_headlines()[1]

    ---@diagnostic disable-next-line: invisible
    org.capture:_refile_from_org_file({
      destination_file = destination_file,
      source_headline = item,
      destination_headline = destination_file:get_headlines()[1],
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* foobar',
      '** baz',
      '* barbar',
      '',
      '        ',
      '',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)

describe('Capture', function()
  it('to empty file', function()
    local destination_file = helpers.create_file({})

    local capture_lines = { '* foo' }
    local capture_file = helpers.create_file_instance(capture_lines)
    local item = capture_file:get_headlines()[1]

    ---@diagnostic disable-next-line: invisible
    org.capture:_refile_from_capture_buffer({
      destination_file = destination_file,
      source_file = capture_file,
      source_headline = item,
      template = Template:new({
        properties = {
          empty_lines = {
            before = 2,
            after = 1,
          },
        },
      }),
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '',
      '',
      '* foo',
      '',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('to end', function()
    local destination_file = helpers.create_file({
      '* foobar',
      '        ',
      '',
      '\t\t\t\t',
      '',
    })

    local capture_lines = { '** baz' }
    local capture_file = helpers.create_file(capture_lines)
    assert(capture_file)
    local item = capture_file:get_headlines()[1]

    ---@diagnostic disable-next-line: invisible
    org.capture:_refile_from_capture_buffer({
      destination_file = destination_file,
      source_file = capture_file,
      source_headline = item,
      template = Template:new({
        properties = {
          empty_lines = {
            before = 2,
            after = 1,
          },
        },
      }),
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* foobar',
      '',
      '',
      '* baz',
      '',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
  it('to headline', function()
    local destination_file = helpers.create_file({
      '* foobar',
      '        ',
      '',
      '\t\t\t\t',
      '',
      '* barbar',
      '',
      '        ',
      '',
    })

    local capture_lines = { '** baz' }
    local capture_file = helpers.create_file_instance(capture_lines)
    local item = capture_file:get_headlines()[1]

    ---@diagnostic disable-next-line: invisible
    org.capture:_refile_from_capture_buffer({
      destination_file = destination_file,
      source_file = capture_file,
      source_headline = item,
      destination_headline = destination_file:get_headlines()[1],
      template = Template:new({
        properties = {
          empty_lines = {
            before = 2,
            after = 1,
          },
        },
      }),
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* foobar',
      '',
      '',
      '** baz',
      '',
      '* barbar',
      '',
      '        ',
      '',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('to regex', function()
    local destination_file = helpers.create_file({
      '#+title foo',
      'appendhere',
      '',
      '* foobar',
      '* barbar',
    })

    local capture_lines = { '** baz' }
    local capture_file = helpers.create_file_instance(capture_lines)
    local item = capture_file:get_headlines()[1]

    ---@diagnostic disable-next-line: invisible
    org.capture:_refile_from_capture_buffer({
      destination_file = destination_file,
      source_file = capture_file,
      source_headline = item,
      template = Template:new({
        regexp = 'appendhere',
      }),
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '#+title foo',
      'appendhere',
      '* baz',
      '',
      '* foobar',
      '* barbar',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)
