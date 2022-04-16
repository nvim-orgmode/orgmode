local Capture = require('orgmode.capture')

describe('Menu Items', function()
  it('should create a menu item for each template', function()
    local templates = {
      t = {
        description = 'todo',
      },
      b = {
        description = 'bookmark',
      },
      f = {
        description = 'file update',
      },
    }
    menu_items = Capture:_create_menu_items(templates)
    assert.are.same(#menu_items, 3)
    assert.are.same(
      { 'b', 'f', 't' },
      vim.tbl_map(function(x)
        return x.key
      end, vim.fn.sort(menu_items))
    )
  end)

  it('should create one entry for multi-key shortcuts', function()
    local multikey_templates = {
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
    }
    menu_items = Capture:_create_menu_items(multikey_templates)
    assert.are.same(#menu_items, 1)
    assert.are.same(
      { 'k' },
      vim.tbl_map(function(x)
        return x.key
      end, vim.fn.sort(menu_items))
    )
  end)

  it('computes the sub templates', function()
    local multikey_templates = {
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
    }
    sub_template_items = Capture:_get_subtemplates('k', multikey_templates)
    assert.are.same({
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
    }, sub_template_items)
  end)

  it('adds an ellipses', function()
    local template = {
      k = 'Multikey template',
    }
    menu_item = Capture:_create_menu_items(template)
    assert.are.same('Multikey template...', menu_item[1].label)
  end)
end)
