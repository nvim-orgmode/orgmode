local helpers = require('tests.plenary.helpers')
local org = require('orgmode')

describe('Autocompletion', function()
  local function setup_file(content)
    -- Add space to the end of content because insert mode in
    -- tests doesn't pick up a proper cursor location
    helpers.create_agenda_file({ content .. ' ' })
    vim.cmd('norm!A')
  end

  describe('omni find start', function()
    it('for an empty line', function()
      setup_file('')
      local result = org.completion:omnifunc(1)
      assert.are.same(-1, result)
    end)
    it('for an empty headline', function()
      setup_file('* ')
      vim.cmd('norm!A')
      local result = org.completion:omnifunc(1)
      assert.are.same(2, result)
    end)
    it('within TODO in headline', function()
      setup_file('* TO')
      vim.cmd('norm!A')
      local result = org.completion:omnifunc(1)
      assert.are.same(2, result)

      setup_file('* TODO')
      vim.cmd('norm!A')
      result = org.completion:omnifunc(1)
      assert.are.same(2, result)
    end)
    it('in the middle of a headline', function()
      setup_file('* TODO some text ')
      vim.cmd('norm!A')
      local result = org.completion:omnifunc(1)
      assert.are.same(-1, result)
    end)
    it('within tag in headline', function()
      setup_file('* TODO tags goes at the end :')
      local result = org.completion:omnifunc(1)
      assert.are.same(28, result)

      setup_file('* TODO tags goes at the end :SOMET')
      result = org.completion:omnifunc(1)
      assert.are.same(28, result)
    end)
    it('after tag in headline', function()
      setup_file('* TODO tags goes at the end :SOMETAG:')
      local result = org.completion:omnifunc(1)
      assert.are.same(36, result)
    end)
    it('within special directives (#+)', function()
      setup_file('#')
      local result = org.completion:omnifunc(1)
      assert.are.same(0, result)

      setup_file('#+')
      result = org.completion:omnifunc(1)
      assert.are.same(0, result)

      setup_file('#+ar')
      result = org.completion:omnifunc(1)
      assert.are.same(0, result)
    end)

    it('within properties', function()
      setup_file(':')
      local result = org.completion:omnifunc(1)
      assert.are.same(0, result)

      setup_file('  :')
      result = org.completion:omnifunc(1)
      assert.are.same(2, result)

      setup_file('  :PROP')
      result = org.completion:omnifunc(1)
      assert.are.same(2, result)

      setup_file('  :PROPERTI')
      result = org.completion:omnifunc(1)
      assert.are.same(2, result)
    end)
    it('within hyperlinks', function()
      setup_file('  [[')
      local result = org.completion:omnifunc(1)
      assert.are.same(4, result)

      setup_file('  [[*some')
      result = org.completion:omnifunc(1)
      assert.are.same(4, result)

      setup_file('  [[#val')
      result = org.completion:omnifunc(1)
      assert.are.same(4, result)

      setup_file('  [[test')
      result = org.completion:omnifunc(1)
      assert.are.same(4, result)

      setup_file('  [[file:')
      result = org.completion:omnifunc(1)
      assert.are.same(4, result)
    end)
    it('within file hyperlink anchors (file: prefix)', function()
      setup_file('  [[file:./some/path/file.org::*')
      local result = org.completion:omnifunc(1)
      assert.are.same(4, result)

      setup_file('  [[file:./some/path/file.org::#')
      result = org.completion:omnifunc(1)
      assert.are.same(4, result)

      setup_file('  [[file:./some/path/file.org::')
      result = org.completion:omnifunc(1)
      assert.are.same(4, result)
    end)
    it('within file hyperlink anchors (./ prefix, headline)', function()
      setup_file('  [[./1-34_some/path/file.org::*')
      local result = org.completion:omnifunc(1)
      assert.are.same(4, result)
    end)
    --TODO These tests expose a bug. Actually the expected start should be 31 as in the tests before
    it('within file hyperlink anchors (./ prefix, custom_id)', function()
      setup_file('  [[./1-34_some/path/file.org::#')
      local result = org.completion:omnifunc(1)
      assert.are.same(4, result)
    end)
    it('within file hyperlink anchors (./ prefix, dedicated anchor)', function()
      setup_file('  [[./1-34_some/path/file.org::')
      local result = org.completion:omnifunc(1)
      assert.are.same(4, result)
    end)
  end)

  describe('omni complete', function()
    it('should return an empty table when base is empty', function()
      setup_file('')
      local result = org.completion:omnifunc(0, '')
      assert.are.same({}, result)
    end)

    it('should return DEADLINE: when base is D on second headline line', function()
      -- Metadata
      helpers.create_agenda_file({
        '* TODO test',
        '  A',
      })
      vim.fn.cursor({ 2, 1 })
      vim.cmd('norm!A')
      local result = org.completion:omnifunc(0, 'D')
      assert.are.same({
        { menu = '[Org]', word = 'DEADLINE:' },
      }, result)
    end)

    it('should return defined keywords when base is :', function()
      setup_file(':')
      local result = org.completion:omnifunc(0, ':')
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
      setup_file(':')
      local result = org.completion:omnifunc(0, ':C')
      assert.are.same({
        { menu = '[Org]', word = ':CUSTOM_ID:' },
        { menu = '[Org]', word = ':CATEGORY:' },
      }, result)

      result = org.completion:omnifunc(0, ':CA')
      assert.are.same({
        { menu = '[Org]', word = ':CATEGORY:' },
      }, result)
    end)

    it('should find and filter down export options when base is #', function()
      setup_file('#')
      -- Directives
      local result = org.completion:omnifunc(0, '#')
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
        { menu = '[Org]', word = '#+begin_example' },
        { menu = '[Org]', word = '#+end_src' },
        { menu = '[Org]', word = '#+end_example' },
      }
      assert.are.same(directives, result)

      result = org.completion:omnifunc(0, '#+')
      assert.are.same(directives, result)

      result = org.completion:omnifunc(0, '#+b')
      assert.are.same({
        { menu = '[Org]', word = '#+begin_src' },
        { menu = '[Org]', word = '#+begin_example' },
      }, result)
    end)

    it('should find and filter down TODO keywords at the beginning of a headline', function()
      setup_file('* ')
      local result = org.completion:omnifunc(0, '')
      assert.are.same({
        { menu = '[Org]', word = 'TODO' },
        { menu = '[Org]', word = 'DONE' },
      }, result)

      setup_file('* T')
      result = org.completion:omnifunc(0, 'T')
      assert.are.same({
        { menu = '[Org]', word = 'TODO' },
      }, result)
    end)

    it('should find defined tags', function()
      local file = helpers.create_agenda_file({
        '#+filetags: :OFFICE:PRIVATE:',
      })
      setup_file('* TODO tags go at the end :')
      local result = org.completion:omnifunc(0, ':')
      assert.are.same({
        { menu = '[Org]', word = ':OFFICE:' },
        { menu = '[Org]', word = ':PRIVATE:' },
        { menu = '[Org]', word = ':SOMETAG:' },
      }, result)

      result = org.completion:omnifunc(0, ':OFF')
      assert.are.same({
        { menu = '[Org]', word = ':OFFICE:' },
      }, result)

      vim.fn.setline(1, '* TODO tags go at the end :OFFICE:')
      result = org.completion:omnifunc(0, ':')
      assert.are.same({
        { menu = '[Org]', word = ':OFFICE:' },
        { menu = '[Org]', word = ':PRIVATE:' },
        { menu = '[Org]', word = ':SOMETAG:' },
      }, result)

      setup_file('#+filetags: ')
      result = org.completion:omnifunc(0, '')
      assert.are.same({}, result)
      --
      setup_file('#+filetags: :')
      result = org.completion:omnifunc(0, ':')
      assert.are.same({
        { menu = '[Org]', word = ':OFFICE:' },
        { menu = '[Org]', word = ':PRIVATE:' },
        { menu = '[Org]', word = ':SOMETAG:' },
      }, result)
    end)

    describe('in hyperlinks', function()
      it('should complete headlines', function()
        local orgfile = helpers.create_agenda_file({
          '* Item for work 1',
          '* Item for work 2',
        })
        local filename = vim.fn.fnamemodify(orgfile.filename, ':t')
        local file_path_relative = string.format('./%s', filename)

        local line = string.format('  [[%s::* ', file_path_relative)
        helpers.create_file({ line })

        vim.fn.cursor({ 1, #line })
        local result = org.completion:omnifunc(0, ('%s::*'):format(file_path_relative))
        assert.are.same({
          { menu = '[Org]', word = ('%s::*Item for work 1'):format(file_path_relative) },
          { menu = '[Org]', word = ('%s::*Item for work 2'):format(file_path_relative) },
        }, result)
      end)

      it('should complete custom_ids', function()
        local orgfile = helpers.create_agenda_file({
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
        helpers.create_file({ line })

        vim.fn.cursor({ 1, #line })
        local result = org.completion:omnifunc(0, ('%s::#'):format(file_path_relative))
        assert.are.same({
          { menu = '[Org]', word = ('%s::#ID_1'):format(file_path_relative) },
          { menu = '[Org]', word = ('%s::#ID_2'):format(file_path_relative) },
        }, result)
      end)

      it('should complete fuzzy titles', function()
        helpers.create_agenda_file({
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

        local result = org.completion:omnifunc(0, 'Tit')

        assert.are.same({
          { menu = '[Org]', word = 'Title with an <<some anchor>>' },
          { menu = '[Org]', word = 'Title without anchor' },
        }, result)
      end)
    end)
  end)
end)
