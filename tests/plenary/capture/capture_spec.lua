local Capture = require('orgmode.capture')
local Templates = require('orgmode.capture.templates')

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
