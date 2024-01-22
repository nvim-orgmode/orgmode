local Omni = require('orgmode.org.autocompletion.omni')
local helpers = require('tests.plenary.helpers')

describe('Autocompletion should properly find start offset for omni autocompletion', function()
  local function setup_file(content)
    -- Add space to the end of content because insert mode in
    -- tests doesn't pick up a proper cursor location
    helpers.load_as_agenda_file({ content .. ' ' })
    vim.cmd('norm!A')
  end
  it('for an empty line', function()
    setup_file('')
    local result = Omni.find_start()
    assert.are.same(0, result)
  end)
  it('for an empty headline', function()
    setup_file('* ')
    vim.cmd('norm!A')
    local result = Omni.find_start()
    assert.are.same(2, result)
  end)
  it('within TODO in headline', function()
    setup_file('* TO')
    vim.cmd('norm!A')
    local result = Omni.find_start()
    assert.are.same(2, result)

    setup_file('* TODO')
    vim.cmd('norm!A')
    result = Omni.find_start()
    assert.are.same(2, result)
  end)
  it('in the middle of a headline', function()
    setup_file('* TODO some text ')
    vim.cmd('norm!A')
    local result = Omni.find_start()
    assert.are.same(17, result)
  end)
  it('within tag in headline', function()
    setup_file('* TODO tags goes at the end :')
    local result = Omni.find_start()
    assert.are.same(28, result)

    setup_file('* TODO tags goes at the end :SOMET')
    result = Omni.find_start()
    assert.are.same(28, result)
  end)
  it('after tag in headline', function()
    setup_file('* TODO tags goes at the end :SOMETAG:')
    local result = Omni.find_start()
    assert.are.same(36, result)
  end)
  it('within special directives (#+)', function()
    setup_file('#')
    local result = Omni.find_start()
    assert.are.same(0, result)

    setup_file('#+')
    result = Omni.find_start()
    assert.are.same(0, result)

    setup_file('#+ar')
    result = Omni.find_start()
    assert.are.same(0, result)
  end)

  describe('Autocompletion', function()
    it('within properties', function()
      setup_file(':')
      local result = Omni.find_start()
      assert.are.same(0, result)

      setup_file('  :')
      result = Omni.find_start()
      assert.are.same(2, result)

      setup_file('  :PROP')
      result = Omni.find_start()
      assert.are.same(2, result)

      setup_file('  :PROPERTI')
      result = Omni.find_start()
      assert.are.same(2, result)
    end)
    it('within hyperlinks', function()
      setup_file('  [[')
      local result = Omni.find_start()
      assert.are.same(4, result)

      setup_file('  [[*some')
      result = Omni.find_start()
      assert.are.same(4, result)

      setup_file('  [[#val')
      result = Omni.find_start()
      assert.are.same(4, result)

      setup_file('  [[test')
      result = Omni.find_start()
      assert.are.same(4, result)

      setup_file('  [[file:')
      result = Omni.find_start()
      assert.are.same(4, result)
    end)
    it('within file hyperlink anchors (file: prefix)', function()
      setup_file('  [[file:./some/path/file.org::*')
      local result = Omni.find_start()
      assert.are.same(31, result)

      setup_file('  [[file:./some/path/file.org::#')
      result = Omni.find_start()
      assert.are.same(31, result)

      setup_file('  [[file:./some/path/file.org::')
      result = Omni.find_start()
      assert.are.same(31, result)
    end)
    it('within file hyperlink anchors (./ prefix, headline)', function()
      setup_file('  [[./1-34_some/path/file.org::*')
      local result = Omni.find_start()
      assert.are.same(31, result)
    end)
    --TODO These tests expose a bug. Actually the expected start should be 31 as in the tests before
    it('within file hyperlink anchors (./ prefix, custom_id)', function()
      setup_file('  [[./1-34_some/path/file.org::#')
      local result = Omni.find_start()
      assert.are.same(30, result)
    end)
    it('within file hyperlink anchors (./ prefix, dedicated anchor)', function()
      setup_file('  [[./1-34_some/path/file.org::')
      local result = Omni.find_start()
      assert.are.same(30, result)
    end)
  end)

  describe('Autocompletion', function()
    before_each(function()
      setup_file('')
    end)

    it('should return an empty table when base is empty', function()
      setup_file('')
      local result = Omni.get_completions('')
      assert.are.same({}, result)
    end)

    it('should return DEADLINE: when base is D', function()
      -- Metadata
      local result = Omni.get_completions('D')
      assert.are.same({
        { menu = '[Org]', word = 'DEADLINE:' },
      }, result)
    end)

    it('should return defined keywords when base is :', function()
      local result = Omni.get_completions(':')
      local props = {
        { menu = '[Org]', word = ':PROPERTIES:' },
        { menu = '[Org]', word = ':END:' },
        { menu = '[Org]', word = ':LOGBOOK:' },
        { menu = '[Org]', word = ':STYLE:' },
        { menu = '[Org]', word = ':REPEAT_TO_STATE:' },
        { menu = '[Org]', word = ':CUSTOM_ID:' },
        { menu = '[Org]', word = ':CATEGORY:' },
      }
      assert.are.same(props, result)
    end)

    it('should filter keywords down', function()
      local result = Omni.get_completions(':C')
      assert.are.same({
        { menu = '[Org]', word = ':CUSTOM_ID:' },
        { menu = '[Org]', word = ':CATEGORY:' },
      }, result)

      result = Omni.get_completions(':CA')
      assert.are.same({
        { menu = '[Org]', word = ':CATEGORY:' },
      }, result)
    end)

    it('should find and filter down export options when base is #', function()
      -- Directives
      local result = Omni.get_completions('#')
      local directives = {
        { menu = '[Org]', word = '#+title' },
        { menu = '[Org]', word = '#+author' },
        { menu = '[Org]', word = '#+email' },
        { menu = '[Org]', word = '#+name' },
        { menu = '[Org]', word = '#+filetags' },
        { menu = '[Org]', word = '#+archive' },
        { menu = '[Org]', word = '#+options' },
        { menu = '[Org]', word = '#+category' },
        { menu = '[Org]', word = '#+begin_src' },
        { menu = '[Org]', word = '#+end_src' },
        { menu = '[Org]', word = '#+begin_example' },
        { menu = '[Org]', word = '#+end_example' },
      }
      assert.are.same(directives, result)

      result = Omni.get_completions('#+')
      assert.are.same(directives, result)

      result = Omni.get_completions('#+b')
      assert.are.same({
        { menu = '[Org]', word = '#+begin_src' },
        { menu = '[Org]', word = '#+begin_example' },
      }, result)
    end)
  end)

  before_each(function()
    setup_file('* ')
  end)

  it('should find and filter down TODO keywords at the beginning of a headline', function()
    local result = Omni.get_completions('')
    assert.are.same({
      { menu = '[Org]', word = 'TODO' },
      { menu = '[Org]', word = 'DONE' },
    }, result)

    setup_file('* T')
    result = Omni.get_completions('T')
    assert.are.same({
      { menu = '[Org]', word = 'TODO' },
    }, result)
  end)

  it('should find defined tags', function()
    local file = helpers.load_as_agenda_file({
      '#+filetags: :OFFICE:PRIVATE:',
    })
    setup_file('* TODO tags go at the end :')
    local result = Omni.get_completions(':')
    assert.are.same({
      { menu = '[Org]', word = ':OFFICE:' },
      { menu = '[Org]', word = ':PRIVATE:' },
      { menu = '[Org]', word = ':SOMETAG:' },
    }, result)

    result = Omni.get_completions(':OFF')
    assert.are.same({
      { menu = '[Org]', word = ':OFFICE:' },
    }, result)

    vim.fn.setline(1, '* TODO tags go at the end :OFFICE:')
    result = Omni.get_completions(':')
    assert.are.same({
      { menu = '[Org]', word = ':OFFICE:' },
      { menu = '[Org]', word = ':PRIVATE:' },
      { menu = '[Org]', word = ':SOMETAG:' },
    }, result)

    setup_file('#+filetags: ')
    result = Omni.get_completions('')
    assert.are.same({}, result)
    --
    setup_file('#+filetags: :')
    result = Omni.get_completions(':')
    assert.are.same({
      { menu = '[Org]', word = ':OFFICE:' },
      { menu = '[Org]', word = ':PRIVATE:' },
      { menu = '[Org]', word = ':SOMETAG:' },
    }, result)
  end)
end)

describe('Autocompletion in hyperlinks', function()
  it('should complete headlines', function()
    local orgfile = helpers.load_as_agenda_file({
      '* Item for work 1',
      '* Item for work 2',
    })
    local filename = vim.fn.fnamemodify(orgfile.filename, ':t')
    local file_path_relative = string.format('./%s', filename)

    local line = string.format('  [[%s::* ', file_path_relative)
    helpers.load_file_content({ line })

    vim.fn.cursor({ 1, #line })
    local result = Omni.get_completions('')
    assert.are.same({
      { menu = '[Org]', word = '*Item for work 1' },
      { menu = '[Org]', word = '*Item for work 2' },
    }, result)
  end)

  it('should complete custom_ids', function()
    local orgfile = helpers.load_as_agenda_file({
      '* Item for work 1',
      ':PROPERTIES:',
      ':CUSTOM_ID: ID_1',
      ':END:',
      '* Item for work 2',
      ':PROPERTIES:',
      ':CUSTOM_ID: ID_2',
      ':END:',
    })
    local filename = vim.fn.fnamemodify(orgfile.filename, ':t')
    local file_path_relative = string.format('./%s', filename)

    local line = string.format('  [[%s::# ', file_path_relative)
    helpers.load_file_content({ line })

    vim.fn.cursor({ 1, #line })
    local result = Omni.get_completions('')
    assert.are.same({
      { menu = '[Org]', word = '#ID_1' },
      { menu = '[Org]', word = '#ID_2' },
    }, result)
  end)

  it('should complete fuzzy titles', function()
    helpers.load_as_agenda_file({
      '* Title with an <<some anchor>>',
      'line1',
      'line2',
      'line3',
      '* This headline should not be found',
      'line1',
      '... <<some other anchor>> ...',
      'line3',
      '* Title without anchor',
      'line1',
      'line2',
      'line3',
      '',
      '  [[Tit ',
    })
    vim.fn.cursor({ 14, 8 })

    local result = Omni.get_completions('Tit')

    assert.are.same({
      { menu = '[Org]', word = 'Title with an <<some anchor>>' },
      { menu = '[Org]', word = 'Title without anchor' },
    }, result)
  end)
end)
