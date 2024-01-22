local OrgFile = require('orgmode.files.file')

describe('OrgFile', function()
  local load_file_sync = function(filename)
    ---@type OrgFile
    local file = nil
    local co = coroutine.running()
    OrgFile.load(filename):next(function(orgfile)
      file = orgfile
      coroutine.resume(co)
      return orgfile
    end)
    coroutine.yield()
    return file
  end
  describe('load', function()
    it('should load a file', function()
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({ '* Headline 1' }, filename)

      local file = load_file_sync(filename)

      assert.are.same(filename, file.filename)
      assert.are.same({ '* Headline 1' }, file.lines)
      assert.are.same('* Headline 1', file.content)
      local stat = vim.loop.fs_stat(filename) or {}
      assert.are.same(stat.mtime.nsec, file.metadata.mtime)
      assert.are.same(0, file.metadata.changedtick)
    end)

    it('should not load a file that is not an org file', function()
      local filename = vim.fn.tempname() .. '.txt'
      vim.fn.writefile({ '* Headline 1' }, filename)
      local file = load_file_sync(filename)
      assert.is.False(file)
    end)

    it('should load a buffer', function()
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({ '* Headline 2' }, filename)
      vim.cmd('edit ' .. filename)
      local file = load_file_sync(filename)

      assert.are.same(filename, file.filename)
      assert.are.same({ '* Headline 2' }, file.lines)
      assert.are.same('* Headline 2', file.content)
      local stat = vim.loop.fs_stat(filename) or {}
      assert.are.same(stat.mtime.nsec, file.metadata.mtime)
      assert.are.same(4, file.metadata.changedtick)
    end)
  end)

  describe('reload', function()
    it('should reload a file if its modified', function()
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({ '* Headline 3' }, filename)
      local file = load_file_sync(filename)
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
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({ '* Headline 3' }, filename)
      vim.cmd('edit ' .. filename)
      local file = load_file_sync(filename)
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
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local file = load_file_sync(filename)
      local headlines = file:get_headlines()
      assert.are.same(8, #headlines)
      assert.are.same('* TODO Headline 3', headlines[3]:get_headline_line_content())
      assert.are.same('Headline 3', headlines[3]:get_title())
    end)

    it('should not return any headlines if file is an archive file', function()
      local filename = vim.fn.tempname() .. '.org_archive'
      vim.fn.writefile({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local file = load_file_sync(filename)
      local headlines = file:get_headlines()
      assert.are.same(0, #headlines)
    end)
  end)

  describe('get_headlines', function()
    it('should get all headlines of a file', function()
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local file = load_file_sync(filename)
      local headlines = file:get_headlines()
      assert.are.same(8, #headlines)
      assert.are.same('* TODO Headline 3', headlines[3]:get_headline_line_content())
      assert.are.same('Headline 3', headlines[3]:get_title())
    end)

    it('should not return any headlines if file is an archive file', function()
      local filename = vim.fn.tempname() .. '.org_archive'
      vim.fn.writefile({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local file = load_file_sync(filename)
      local headlines = file:get_headlines()
      assert.are.same(0, #headlines)
    end)
  end)

  describe('get_headlines_including_archived', function()
    it('should get all headlines of a file even if archive file', function()
      local filename = vim.fn.tempname() .. '.org_archive'
      vim.fn.writefile({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local file = load_file_sync(filename)
      local headlines = file:get_headlines_including_archived()
      assert.are.same(8, #headlines)
      assert.are.same('* TODO Headline 3', headlines[3]:get_headline_line_content())
      assert.are.same('Headline 3', headlines[3]:get_title())
    end)
  end)

  describe('find_headlines_by_title', function()
    it('should find headlines by partial title', function()
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local file = load_file_sync(filename)
      local headlines = file:find_headlines_by_title('headline 3.1')
      assert.are.same(3, #headlines)
      assert.are.same('Headline 3.1', headlines[1]:get_title())
      assert.are.same('Headline 3.1.1', headlines[2]:get_title())
      assert.are.same('Headline 3.1.2', headlines[3]:get_title())
    end)

    it('should find headlines by exact title', function()
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local file = load_file_sync(filename)
      local headlines = file:find_headlines_by_title('headline 3.1', true)
      assert.are.same(1, #headlines)
      assert.are.same('Headline 3.1', headlines[1]:get_title())
    end)
  end)

  describe('find_headline_by_title', function()
    it('should find single headline by title', function()
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile({
        '* TODO Headline 1',
        '* TODO Headline 2',
        '* TODO Headline 3',
        '** Headline 3.1',
        '*** Headline 3.1.1',
        '*** Headline 3.1.2',
        '** Headline 3.2',
        '* DONE Headline 4',
      }, filename)
      local file = load_file_sync(filename)
      local headline = file:find_headline_by_title('headline 3.1')
      assert.are.same('Headline 3.1', headline and headline:get_title())
    end)
  end)
end)
