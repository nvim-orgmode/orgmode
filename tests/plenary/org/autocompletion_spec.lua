local mock = require('luassert.mock')
local Omni = require('orgmode.org.autocompletion.omni')
local Files = require('orgmode.parser.files')
local fs = require('orgmode.utils.fs')

local function mock_line(api, content)
  api.nvim_get_current_line.returns(content)
  api.nvim_call_function.returns(content:len() + 5)
end

describe('Autocompletion', function()
  it('should properly find start offset for omni autocompletion', function()
    local api = mock(vim.api, true)
    mock_line(api, '')
    local result = Omni.find_start()
    assert.are.same(0, result)

    mock_line(api, '* ')
    result = Omni.find_start()
    assert.are.same(2, result)

    mock_line(api, '* TO')
    result = Omni.find_start()
    assert.are.same(2, result)

    mock_line(api, '* TODO')
    result = Omni.find_start()
    assert.are.same(2, result)

    mock_line(api, '* TODO some text ')
    result = Omni.find_start()
    assert.are.same(17, result)

    mock_line(api, '* TODO tags goes at the end :')
    result = Omni.find_start()
    assert.are.same(28, result)

    mock_line(api, '* TODO tags goes at the end :SOMET')
    result = Omni.find_start()
    assert.are.same(28, result)
    mock_line(api, '* TODO tags goes at the end :SOMETAG:')
    result = Omni.find_start()
    assert.are.same(36, result)

    mock_line(api, '#')
    result = Omni.find_start()
    assert.are.same(0, result)

    mock_line(api, '#+')
    result = Omni.find_start()
    assert.are.same(0, result)

    mock_line(api, '#+ar')
    result = Omni.find_start()
    assert.are.same(0, result)

    mock_line(api, ':')
    result = Omni.find_start()
    assert.are.same(0, result)

    mock_line(api, '  :')
    result = Omni.find_start()
    assert.are.same(2, result)

    mock_line(api, '  :PROP')
    result = Omni.find_start()
    assert.are.same(2, result)

    mock_line(api, '  :PROPERTI')
    result = Omni.find_start()
    assert.are.same(2, result)

    mock_line(api, '  [[')
    result = Omni.find_start()
    assert.are.same(4, result)

    mock_line(api, '  [[*some')
    result = Omni.find_start()
    assert.are.same(4, result)

    mock_line(api, '  [[#val')
    result = Omni.find_start()
    assert.are.same(4, result)

    mock_line(api, '  [[test')
    result = Omni.find_start()
    assert.are.same(4, result)

    mock_line(api, '  [[file:')
    result = Omni.find_start()
    assert.are.same(4, result)

    mock.revert(api)
  end)
end)

describe('Autocompletion', function()
  local api
  before_each(function()
    api = mock(vim.api, true)
    mock_line(api, '')
  end)

  after_each(function()
    mock.revert(api)
  end)

  it('should return an empty table when base is empty', function()
    api = mock(vim.api, true)
    mock_line(api, '')
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

describe('Autocompletion', function()
  local api
  before_each(function()
    api = mock(vim.api, true)
    mock_line(api, '* ')
  end)

  after_each(function()
    mock.revert(api)
  end)

  it('should find and filter down TODO keywords at the beginning of a headline', function()
    local result = Omni.get_completions('')
    assert.are.same({
      { menu = '[Org]', word = 'TODO' },
      { menu = '[Org]', word = 'DONE' },
    }, result)

    mock_line(api, '* T')
    result = Omni.get_completions('T')
    assert.are.same({
      { menu = '[Org]', word = 'TODO' },
    }, result)
  end)

  it('should find defined tags', function()
    Files.tags = { 'OFFICE', 'PRIVATE' }
    mock_line(api, '* TODO tags go at the end :')
    local result = Omni.get_completions(':')
    assert.are.same({
      { menu = '[Org]', word = ':OFFICE:' },
      { menu = '[Org]', word = ':PRIVATE:' },
    }, result)

    mock_line(api, '* TODO tags go at the end :')
    result = Omni.get_completions(':OFF')
    assert.are.same({
      { menu = '[Org]', word = ':OFFICE:' },
    }, result)

    mock_line(api, '* TODO tags go at the end :OFFICE:')
    result = Omni.get_completions(':')
    assert.are.same({
      { menu = '[Org]', word = ':OFFICE:' },
      { menu = '[Org]', word = ':PRIVATE:' },
    }, result)

    mock_line(api, '#+filetags: ')
    result = Omni.get_completions('')
    assert.are.same({}, result)

    mock_line(api, '#+filetags: :')
    result = Omni.get_completions(':')
    assert.are.same({
      { menu = '[Org]', word = ':OFFICE:' },
      { menu = '[Org]', word = ':PRIVATE:' },
    }, result)
  end)
end)

describe('Autocompletion in hyperlinks', function()
  local api
  local MockFiles
  local MockFs

  before_each(function()
    api = mock(vim.api, true)
    MockFiles = mock(Files, true)
    MockFs = mock(fs, true)
  end)

  after_each(function()
    mock.revert(MockFiles)
    mock.revert(MockFs)
    mock.revert(api)
  end)

  it('should complete headlines', function()
    local filename = 'work.org'
    local file_dir_absolute = '/some/path'
    local file_path_relative = string.format('./%s', filename)
    local file_path_absolute = string.format('/%s/%s', file_dir_absolute, filename)
    local headlines = {
      { title = 'Item for work 1' },
      { title = 'Item for work 2' },
    }

    mock_line(api, string.format('  [[%s::*', file_path_relative))

    MockFs.get_real_path.returns(file_path_absolute)
    MockFs.get_current_file_dir.returns(file_dir_absolute)
    MockFiles.filenames.returns({ file_path_absolute })
    MockFiles.get.returns({
      filename = file_path_absolute,
      find_headlines_by_title = function()
        return headlines
      end,
    })

    local result = Omni.get_completions('*')
    assert.are.same({
      { menu = '[Org]', word = '*' .. headlines[1].title },
      { menu = '[Org]', word = '*' .. headlines[2].title },
    }, result)
  end)

  it('should complete custom_ids', function()
    local filename = 'work.org'
    local file_dir_absolute = '/some/path'
    local file_path_relative = string.format('./%s', filename)
    local file_path_absolute = string.format('/%s/%s', file_dir_absolute, filename)
    -- properties.items.custom_id
    local custom_ids = {
      { properties = { items = { custom_id = 'ID_1' } } },
      { properties = { items = { custom_id = 'ID_2' } } },
    }

    mock_line(api, string.format('  [[%s::#', file_path_relative))

    MockFs.get_real_path.returns(file_path_absolute)
    MockFs.get_current_file_dir.returns(file_dir_absolute)
    MockFiles.filenames.returns({ file_path_absolute })
    MockFiles.get.returns({
      filename = file_path_absolute,
      find_headlines_with_property_matching = function()
        return custom_ids
      end,
    })

    local result = Omni.get_completions('#')
    assert.are.same({
      { menu = '[Org]', word = '#' .. custom_ids[1].properties.items.custom_id },
      { menu = '[Org]', word = '#' .. custom_ids[2].properties.items.custom_id },
    }, result)
  end)

  it('should complete fuzzy titles', function()
    local filename = 'work.org'
    local file_dir_absolute = '/some/path'
    local file_path_relative = string.format('./%s', filename)
    local file_path_absolute = string.format('/%s/%s', file_dir_absolute, filename)

    local sections = {
      { title = 'Title with an <<some anchor>>', content = { 'line1', 'line2', 'line3' } },
      {
        title = 'This headline should not be found',
        content = { 'line1', '... <<some other anchor>> ...', 'line3' },
      },
      { title = 'Title without anchor', content = { 'line1', 'line2', 'line3' } },
    }

    MockFs.get_real_path.returns(file_path_absolute)
    MockFs.get_current_file_dir.returns(file_dir_absolute)
    MockFiles.filenames.returns({ file_path_absolute })
    MockFiles.get_current_file.returns({
      filename = file_path_absolute,
      find_headlines_matching_search_term = function()
        return sections
      end,
      find_headlines_by_title = function()
        return {}
      end,
    })
    MockFiles.get.returns({
      find_headlines_by_title = function()
        return {}
      end,
    })

    mock_line(api, string.format('  [[Tit', file_path_relative))

    local result = Omni.get_completions('Tit')

    assert.are.same({
      { menu = '[Org]', word = 'Title with an <<some anchor>>' },
      { menu = '[Org]', word = 'Title without anchor' },
    }, result)
  end)
end)
