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
    local menu_item = Capture:_create_menu_items(templates:get_list())
    assert.are.same('Multikey template...', menu_item[1].label)
  end)
end)

describe('Refile', function()
  it('to empty file', function()
    local destination_file = helpers.load_file_content({})

    local capture_lines = { '* foo' }
    helpers.load_file_content(capture_lines)
    local capture_file = helpers.file_from_content(capture_lines)
    assert(capture_file)
    local item = capture_file:get_headlines()[1]

    org.capture:_refile_to({
      file = destination_file,
      lines = capture_lines,
      item = item,
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foo',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('to end', function()
    local destination_file = helpers.load_file_content({
      '* foobar',
      '        ',
      '',
      '\t\t\t\t',
      '',
    })

    local capture_lines = { '** baz' }
    helpers.load_file_content(capture_lines)
    local capture_file = helpers.file_from_content(capture_lines)
    assert(capture_file)
    local item = capture_file:get_headlines()[1]

    org.capture:_refile_to({
      file = destination_file,
      lines = capture_lines,
      item = item,
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foobar',
      '* baz',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
  it('to headline', function()
    local destination_file = helpers.load_file_content({
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
    helpers.load_file_content(capture_lines)
    local capture_file = helpers.file_from_content(capture_lines)
    assert(capture_file)
    local item = capture_file:get_headlines()[1]

    org.capture:_refile_to({
      file = destination_file,
      lines = capture_lines,
      item = item,
      headline = 'foobar',
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
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

describe('Refile with empty lines', function()
  it('to empty file', function()
    local destination_file = helpers.load_file_content({})

    local capture_lines = { '* foo' }
    helpers.load_file_content(capture_lines)
    local capture_file = helpers.file_from_content(capture_lines)
    assert(capture_file)
    local item = capture_file:get_headlines()[1]

    org.capture:_refile_to({
      file = destination_file,
      lines = capture_lines,
      item = item,
      template = Template:new({
        properties = {
          empty_lines = {
            before = 2,
            after = 1,
          },
        },
      }),
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '',
      '',
      '* foo',
      '',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('to end', function()
    local destination_file = helpers.load_file_content({
      '* foobar',
      '        ',
      '',
      '\t\t\t\t',
      '',
    })

    local capture_lines = { '** baz' }
    helpers.load_file_content(capture_lines)
    local capture_file = helpers.file_from_content(capture_lines)
    assert(capture_file)
    local item = capture_file:get_headlines()[1]

    org.capture:_refile_to({
      file = destination_file,
      lines = capture_lines,
      item = item,
      template = Template:new({
        properties = {
          empty_lines = {
            before = 2,
            after = 1,
          },
        },
      }),
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foobar',
      '',
      '',
      '* baz',
      '',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
  it('to headline', function()
    local destination_file = helpers.load_file_content({
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
    helpers.load_file_content(capture_lines)
    local capture_file = helpers.file_from_content(capture_lines)
    assert(capture_file)
    local item = capture_file:get_headlines()[1]

    org.capture:_refile_to({
      file = destination_file,
      lines = capture_lines,
      item = item,
      headline = 'foobar',
      template = Template:new({
        properties = {
          empty_lines = {
            before = 2,
            after = 1,
          },
        },
      }),
    })
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
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
end)
