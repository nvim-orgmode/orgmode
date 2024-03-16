local OrgFile = require('orgmode.files.file')
local config = require('orgmode.config')
local Range = require('orgmode.files.elements.range')

describe('OrgFile', function()
  ---@return OrgFile
  local load_file_sync = function(content, filename)
    content = content or {}
    filename = filename or vim.fn.tempname() .. '.org'
    vim.fn.writefile(content, filename)
    return OrgFile.load(filename):wait()
  end
  describe('load', function()
    it('should load a file', function()
      local filename = vim.fn.tempname() .. '.org'
      local file = load_file_sync({ '* Headline 1' }, filename)

      assert.are.same(filename, file.filename)
      assert.are.same({ '* Headline 1' }, file.lines)
      assert.are.same('* Headline 1', file.content)
      local stat = vim.loop.fs_stat(filename) or {}
      assert.are.same(stat.mtime.nsec, file.metadata.mtime)
      assert.are.same(0, file.metadata.changedtick)
    end)

    it('should not load a file that is not an org file', function()
      local filename = vim.fn.tempname() .. '.txt'
      local file = load_file_sync({ '* Headline 1' }, filename)
      assert.is.False(file)
    end)

    it('should load a buffer', function()
      local filename = vim.fn.tempname() .. '.org'
      local file = load_file_sync({ '* Headline 2' }, filename)
      vim.cmd('edit ' .. filename)

      assert.are.same(filename, file.filename)
      assert.are.same({ '* Headline 2' }, file.lines)
      assert.are.same('* Headline 2', file.content)
      local stat = vim.loop.fs_stat(filename) or {}
      assert.are.same(stat.mtime.nsec, file.metadata.mtime)
      assert.are.same(0, file.metadata.changedtick)
      vim.cmd('write!')
      file:reload_sync()
      assert.are.same(4, file.metadata.changedtick)
    end)
  end)

  describe('reload', function()
    it('should reload a file if its modified', function()
      local filename = vim.fn.tempname() .. '.org'
      local file = load_file_sync({ '* Headline 3' }, filename)
      local old_mtime = file.metadata.mtime
      vim.wait(100)
      vim.fn.writefile({ '* Headline 3 edited' }, filename)
      assert.are.same(old_mtime, file.metadata.mtime)
      file = file:reload_sync()
      assert.are.not_same(old_mtime, file.metadata.mtime)
      assert.are.same({ '* Headline 3 edited' }, file.lines)
      assert.are.same('* Headline 3 edited', file.content)
    end)

    it('should reload a buffer if its modified', function()
      local file = load_file_sync({ '* Headline 3' })
      vim.cmd('edit ' .. file.filename)
      local old_mtime = file.metadata.mtime
      local old_changedtick = file.metadata.changedtick
      vim.wait(100)
      vim.fn.append(1, '* Headline 4')
      assert.are.same(old_mtime, file.metadata.mtime)
      assert.are.same(old_changedtick, file.metadata.changedtick)
      file = file:reload_sync()
      assert.are.same(old_mtime, file.metadata.mtime)
      assert.are.not_same(old_changedtick, file.metadata.changedtick)
      assert.are.same({ '* Headline 3', '* Headline 4' }, file.lines)
      assert.are.same('* Headline 3\n* Headline 4', file.content)
    end)
  end)

  describe('get_headlines', function()
    it('should get all headlines of a file', function()
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      })
      local headlines = file:get_headlines()
      assert.are.same(8, #headlines)
      assert.are.same('* TODO Headline 3', headlines[3]:get_headline_line_content())
      assert.are.same('Headline 3', headlines[3]:get_title())
    end)

    it('should not return any headlines if file is an archive file', function()
      local filename = vim.fn.tempname() .. '.org_archive'
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local headlines = file:get_headlines()
      assert.are.same(0, #headlines)
    end)
  end)

  describe('get_headlines_including_archived', function()
    it('should get all headlines of a file even if archive file', function()
      local filename = vim.fn.tempname() .. '.org_archive'
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local headlines = file:get_headlines_including_archived()
      assert.are.same(8, #headlines)
      assert.are.same('* TODO Headline 3', headlines[3]:get_headline_line_content())
      assert.are.same('Headline 3', headlines[3]:get_title())
    end)
  end)

  describe('find_headlines_by_title', function()
    it('should find headlines by partial title', function()
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      })
      local headlines = file:find_headlines_by_title('headline 3.1')
      assert.are.same(3, #headlines)
      assert.are.same('Headline 3.1', headlines[1]:get_title())
      assert.are.same('Headline 3.1.1', headlines[2]:get_title())
      assert.are.same('Headline 3.1.2', headlines[3]:get_title())
    end)

    it('should find headlines by exact title', function()
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      })
      local headlines = file:find_headlines_by_title('headline 3.1', true)
      assert.are.same(1, #headlines)
      assert.are.same('Headline 3.1', headlines[1]:get_title())
    end)
  end)

  describe('find_headline_by_title', function()
    it('should find single headline by title', function()
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      })
      local headline = file:find_headline_by_title('headline 3.1')
      assert.are.same('Headline 3.1', headline and headline:get_title())
    end)
  end)

  describe('get_unfinished_todo_entries', function()
    it('should return todo entires that are not archived', function()
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2 :ARCHIVE:',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** TODO Headline 3.1.2',
        '** TODO Headline 3.2 :ARCHIVE:',
        '* DONE Headline 4',
      })
      local headlines = file:get_unfinished_todo_entries()
      assert.are.same(3, #headlines)
      assert.are.same('Headline 1', headlines[1]:get_title())
      assert.are.same('Headline 3', headlines[2]:get_title())
      assert.are.same('Headline 3.1.2', headlines[3]:get_title())
    end)

    it('should not return any todo entires that are in archive file', function()
      local filename = vim.fn.tempname() .. '.org_archive'
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2 :ARCHIVE:',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** TODO Headline 3.1.2',
        '** TODO Headline 3.2 :ARCHIVE:',
        '* DONE Headline 4',
      }, filename)
      local headlines = file:get_unfinished_todo_entries()
      assert.are.same(0, #headlines)
    end)
  end)

  describe('find_headlines_matching_search_term', function()
    it('should return headlines that matches the provided search term in non archive files', function()
      local content = {
        '* TODO Headline 1',
        '* TODO Headline 2 :ARCHIVE:',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** TODO Headline 3.1.2',
        '** TODO Headline 3.2 :ARCHIVE:',
        '* DONE Headline 4',
      }
      local file = load_file_sync(content)
      local headlines = file:find_headlines_matching_search_term('Headline 3')
      assert.are.same(5, #headlines)

      local archive_filename = vim.fn.tempname() .. '.org_archive'
      local archive_file = load_file_sync(content, archive_filename)
      headlines = archive_file:find_headlines_matching_search_term('Headline 3')
      assert.are.same(0, #headlines)
    end)

    it('should return headlines that matches the provided search even in archive files if requested', function()
      local content = {
        '* TODO Headline 1',
        '* TODO Headline 2 :ARCHIVE:',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** TODO Headline 3.1.2',
        '** TODO Headline 3.2 :ARCHIVE:',
        '* DONE Headline 4',
      }
      local archive_filename = vim.fn.tempname() .. '.org_archive'
      local archive_file = load_file_sync(content, archive_filename)
      local headlines = archive_file:find_headlines_matching_search_term('Headline 3', false, true)
      assert.are.same(5, #headlines)
    end)
  end)

  describe('find_headlines_with_property_matching', function()
    it('should return headlines with matching property', function()
      local content = {
        '* TODO Headline 1',
        '* TODO Headline 2',
        '  :PROPERTIES:',
        '  :INCLUDED: yes',
        '  :END:',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** TODO Headline 3.1.2',
        '    :PROPERTIES:',
        '    :INCLUDED: yes',
        '    :END:',
        '** TODO Headline 3.2',
        '* DONE Headline 4',
      }
      local file = load_file_sync(content)
      local headlines = file:find_headlines_with_property_matching('included', 'yes')
      assert.are.same(2, #headlines)
      assert.are.same('Headline 2', headlines[1]:get_title())
      assert.are.same('Headline 3.1.2', headlines[2]:get_title())
    end)
  end)

  describe('get_opened_headlines', function()
    it('should return only non archived archived headlines', function()
      local content = {
        '* TODO Headline 1',
        '* TODO Headline 2 :ARCHIVE:',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** TODO Headline 3.1.2',
        '** TODO Headline 3.2 :ARCHIVE:',
        '* DONE Headline 4',
      }
      local file = load_file_sync(content)
      local headlines = file:get_opened_headlines()
      assert.are.same(6, #headlines)

      local archive_filename = vim.fn.tempname() .. '.org_archive'
      local archive_file = load_file_sync(content, archive_filename)
      headlines = archive_file:get_opened_headlines()
      assert.are.same(0, #headlines)
    end)
  end)

  describe('is_archive_file', function()
    it('should return true if file has org_archive extension', function()
      local file = load_file_sync({ '* Headline' })
      assert.is.False(file:is_archive_file())

      local archive_filename = vim.fn.tempname() .. '.org_archive'
      local archive_file = load_file_sync({ '* Headline' }, archive_filename)
      assert.is.True(archive_file:is_archive_file())
    end)
  end)

  describe('closest_headline_node', function()
    local content = {
      '* TODO Headline 1',
      '* TODO Headline 2 :ARCHIVE:',
      '* TODO Headline 3',
      '  Content',
      '** Headline 3.1',
      '   Content 3',
      '*** Headline 3.1.1',
    }
    local file = load_file_sync(content)

    it('should return closest headline node from current position by default', function()
      vim.cmd('edit ' .. file.filename)
      vim.fn.cursor({ 4, 3 })
      local headline_node = file:closest_headline_node()
      assert(headline_node)
      local start = headline_node:start()
      assert.are.same(2, start) -- 0 indexed
    end)

    it('should return closest headline node from the provided cursor position', function()
      vim.fn.cursor({ 4, 3 })
      local headline_node = file:closest_headline_node({ 6, 3 })
      assert(headline_node)
      local start = headline_node:start()
      assert.are.same(4, start) -- 0 indexed
    end)
  end)

  describe('get_closest_headline', function()
    local content = {
      '* TODO Headline 1',
      '* TODO Headline 2 :ARCHIVE:',
      '* TODO Headline 3',
      '  Content',
      '** Headline 3.1',
      '   Content 3',
      '*** Headline 3.1.1',
    }
    local file = load_file_sync(content)

    it('should return closest headline as OrgHeadline', function()
      vim.cmd('edit ' .. file.filename)
      vim.fn.cursor({ 4, 3 })
      local headline = file:get_closest_headline()
      assert.are.same('Headline 3', headline:get_title())
    end)

    it('should return closest headline node from the provided cursor position', function()
      local headline = file:get_closest_headline({ 6, 3 })
      assert.are.same('Headline 3.1', headline:get_title())
    end)

    it('should report error if it cannot find any headlines', function()
      local no_headline_file = load_file_sync({ 'Not a headline' })
      assert.is.error_matches(function()
        return no_headline_file:get_closest_headline()
      end, 'No headline found')
    end)
  end)

  describe('get_closest_headline_or_nil', function()
    local content = {
      '* TODO Headline 1',
      '* TODO Headline 2 :ARCHIVE:',
      '* TODO Headline 3',
      '  Content',
      '** Headline 3.1',
      '   Content 3',
      '*** Headline 3.1.1',
    }
    local file = load_file_sync(content)

    it('should return closest headline as OrgHeadline', function()
      vim.cmd('edit ' .. file.filename)
      vim.fn.cursor({ 4, 3 })
      local headline = file:get_closest_headline_or_nil()
      assert(headline)
      assert.are.same('Headline 3', headline:get_title())
    end)

    it('should return closest headline node from the provided cursor position', function()
      local headline = file:get_closest_headline_or_nil({ 6, 3 })
      assert(headline)
      assert.are.same('Headline 3.1', headline:get_title())
    end)

    it('should return nil if it cannot find any headlines', function()
      local no_headline_file = load_file_sync({ 'Not a headline' })
      local no_headline = no_headline_file:get_closest_headline_or_nil()
      assert.is.Nil(no_headline)
    end)
  end)

  describe('get_node_at_cursor', function()
    it('should return node at current cursor position', function()
      local file = load_file_sync({ '* Headline 1 :TAG:' })
      vim.fn.cursor({ 1, 15 })
      local node_at_cursor = file:get_node_at_cursor()
      assert.are.same('tag', node_at_cursor:type())

      local node_at_custom_cursor = file:get_node_at_cursor({ 1, 0 })
      assert.are.same('stars', node_at_custom_cursor:type())

      node_at_custom_cursor = file:get_node_at_cursor({ 1, 2 })
      assert.are.same('expr', node_at_custom_cursor:type())
    end)
  end)

  describe('get_node_text', function()
    local file = load_file_sync({
      '* Headline 1 :TAG:',
      '  The content',
      '  Multi line',
    })
    it('should return provided node text as string', function()
      vim.fn.cursor({ 2, 3 })
      local paragraph_node = file:get_node_at_cursor():parent() -- get paragraph
      assert.are.same(file:get_node_text(paragraph_node), 'The content\n  Multi line')
    end)

    it('should return empty string for nil nodes', function()
      assert.are.same(file:get_node_text(nil), '')
    end)
  end)

  describe('get_node_text_list', function()
    local file = load_file_sync({
      '* Headline 1 :TAG:',
      '  The content',
      '  Multi line',
    })
    it('should return provided node text as list', function()
      vim.fn.cursor({ 2, 3 })
      local paragraph_node = file:get_node_at_cursor():parent() -- get paragraph
      assert.are.same(file:get_node_text_list(paragraph_node), { 'The content', '  Multi line' })
    end)

    it('should return empty table for nil nodes', function()
      assert.are.same(file:get_node_text_list(nil), {})
    end)
  end)

  describe('set_node_text', function()
    it('should not do anything if file is not loaded in buffer', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      local paragraph_node = file:get_node_at_cursor():parent()
      local result = file:set_node_text(paragraph_node, 'New Text')
      assert.is.False(result)
    end)

    it('should set node text', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      vim.cmd('edit ' .. file.filename)
      vim.fn.cursor({ 2, 3 })
      local expr_node = file:get_node_at_cursor():parent()
      local result = file:set_node_text(expr_node, 'New Text')
      assert.is.True(result)
      assert.are.same({
        '* Headline 1 :TAG:',
        '  New Text',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it('should remove the node text if set to empty string', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      vim.cmd('edit ' .. file.filename)
      vim.fn.cursor({ 2, 3 })
      local paragraph_node = file:get_node_at_cursor():parent()
      local result = file:set_node_text(paragraph_node, '')
      assert.is.True(result)
      assert.are.same({
        '* Headline 1 :TAG:',
        '  ',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it('should apply front trimming when removing the node text with empty string', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      vim.cmd('edit ' .. file.filename)
      vim.fn.cursor({ 2, 3 })
      local paragraph_node = file:get_node_at_cursor():parent()
      local result = file:set_node_text(paragraph_node, '', true)
      assert.is.True(result)
      assert.are.same({
        '* Headline 1 :TAG:',
        ' ',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end)

  describe('bufnr', function()
    it('should return -1 if there is no buffer', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      assert.are.same(-1, file:bufnr())
    end)

    it('should return buffer number if file is loaded', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      vim.cmd('edit ' .. file.filename)
      assert.is.True(file:bufnr() > 0)
    end)

    it('should return -1 if file is loaded in buffer but buffer is not loaded', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      vim.cmd('edit ' .. file.filename)
      assert.is.True(file:bufnr() > 0)
      vim.cmd('bdelete')
      assert.are.same(-1, file:bufnr())
      assert.is.True(vim.fn.bufnr(file.filename) > 0)
    end)
  end)

  describe('get_filetags', function()
    it('returns all tags defined in #+filetags', function()
      local file = load_file_sync({
        '#+filetags: :FIRST:SECOND:',
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      assert.are.same({ 'FIRST', 'SECOND' }, file:get_filetags())
    end)

    it('returns empty list if there is no filetags', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      assert.are.same({}, file:get_filetags())
    end)
  end)

  describe('get_category', function()
    it('returns category defined in #+category', function()
      local file = load_file_sync({
        '#+category: myfile',
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      assert.are.same('myfile', file:get_category())
    end)

    it('returns file name as category if there is no #+category directive', function()
      local file = load_file_sync({
        '* Headline 1 :TAG:',
        '  The content',
        '  Multi line',
      })
      assert.are.same(vim.fn.fnamemodify(file.filename, ':t:r'), file:get_category())
    end)
  end)

  describe('get_opened_unfinished_headlines', function()
    it('should return headlines that are not archived or done', function()
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2 :ARCHIVE:',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      })
      local headlines = file:get_opened_unfinished_headlines()
      assert.are.same(6, #headlines)
      assert.are.same('Headline 1', headlines[1]:get_title())
      assert.are.same('Headline 3.2', headlines[6]:get_title())
    end)

    it('should not return any headlines if file is an archive file', function()
      local filename = vim.fn.tempname() .. '.org_archive'
      local file = load_file_sync({
        '* TODO Headline 1',
        '* TODO Headline 2 :ARCHIVE:',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local headlines = file:get_opened_unfinished_headlines()
      assert.are.same(0, #headlines)
    end)
  end)

  describe('get_archive_file_location', function()
    it('should return archive location from #+archive directive', function()
      local file = load_file_sync({
        '#+archive: %s_archive.org_archive',
        '* TODO Headline 1',
      })
      local archive_location = file:get_archive_file_location()
      assert.are.same(file.filename .. '_archive.org_archive', archive_location)
    end)

    it('should return default archive location from config', function()
      local file = load_file_sync({
        '* TODO Headline 1',
      })
      local archive_location = file:get_archive_file_location()
      assert.are.same(file.filename .. '_archive', archive_location)
    end)
  end)

  describe('get_properties', function()
    it('should return all properties in a file', function()
      local file = load_file_sync({
        '#+property: header-args :tangle no',
        '#+property: todo-keywords todo ok done',
        '* TODO Headline 1',
      })
      local directive_properties = file:get_directive_properties()
      assert.are.same({
        ['header-args'] = ':tangle no',
        ['todo-keywords'] = 'todo ok done',
      }, directive_properties)
    end)

    it('should return single property from a file', function()
      local file = load_file_sync({
        '#+property: header-args :tangle no',
        '#+property: todo-keywords todo ok done',
        '* TODO Headline 1',
      })
      local directive_property = file:get_directive_property('header-args')
      assert.are.same(':tangle no', directive_property)
    end)
  end)

  describe('get_header_args', function()
    it('should get config header args if file does no have any', function()
      config:extend({
        org_babel_default_header_args = {
          [':tangle'] = 'no',
          [':noweb'] = 'yes',
        },
      })
      local file = load_file_sync({
        '* TODO Headline 1',
      })
      assert.are.same({ [':tangle'] = 'no', [':noweb'] = 'yes' }, file:get_header_args())
    end)

    it('should get config header args if file does no have any', function()
      config:extend({
        org_babel_default_header_args = {
          [':tangle'] = 'no',
          [':noweb'] = 'no',
        },
      })
      local file = load_file_sync({
        '#+property: header-args :tangle yes',
        '* TODO Headline 1',
      })
      assert.are.same({ [':tangle'] = 'yes', [':noweb'] = 'no' }, file:get_header_args())
    end)
  end)

  describe('get_properties', function()
    it('should get file level properties', function()
      local file = load_file_sync({
        ':PROPERTIES:',
        ':ID: 443355',
        ':END:',
        '#+title: test',
        '* TODO Headline 1',
      })
      assert.are.same({
        id = '443355',
      }, file:get_properties())
    end)

    it('should get file level property', function()
      local file = load_file_sync({
        ':PROPERTIES:',
        ':ID: 443355',
        ':CUSTOM_ID: 112233',
        ':END:',
        '#+title: test',
        '* TODO Headline 1',
      })
      assert.are.same('112233', file:get_property('custom_id'))
    end)
  end)

  describe('get_links', function()
    it('should get all links from a file', function()
      local file = load_file_sync({
        'Top level [[https://google.com]]',
        '',
        '* TODO Headline link to file [[./some-file.org]]',
        '  - list item link to [[https://duckduckgo.com][duck]]',
        '',
        '  :LOGBOOK:',
        '  :TEST: And link in drawer [[https://github.com][github link]]',
        '  :END:',
      })
      local links = file:get_links()

      assert.are.same(4, #links)
      assert.are.same('https://google.com', links[1].url:to_string())
      assert.are.same(
        Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 11,
          end_col = 32,
        }),
        links[1].range
      )
      assert.is.Nil(links[1].desc)

      assert.are.same('./some-file.org', links[2].url:to_string())
      assert.is.Nil(links[2].desc)
      assert.are.same(
        Range:new({
          start_line = 3,
          end_line = 3,
          start_col = 30,
          end_col = 48,
        }),
        links[2].range
      )

      assert.are.same('https://duckduckgo.com', links[3].url:to_string())
      assert.are.same('duck', links[3].desc)
      assert.are.same(
        Range:new({
          start_line = 4,
          end_line = 4,
          start_col = 23,
          end_col = 54,
        }),
        links[3].range
      )

      assert.are.same('https://github.com', links[4].url:to_string())
      assert.are.same('github link', links[4].desc)
      assert.are.same(
        Range:new({
          start_line = 7,
          end_line = 7,
          start_col = 29,
          end_col = 63,
        }),
        links[4].range
      )
    end)

    it('should get file level property', function()
      local file = load_file_sync({
        ':PROPERTIES:',
        ':ID: 443355',
        ':CUSTOM_ID: 112233',
        ':END:',
        '#+title: test',
        '* TODO Headline 1',
      })
      assert.are.same('112233', file:get_property('custom_id'))
    end)
  end)
end)
