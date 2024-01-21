local helpers = require('tests.plenary.ui.helpers')

describe('Hyperlink mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should follow link to given headline in given org file', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** target headline',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    vim.cmd([[norm w]])
    helpers.load_file_content({
      string.format('This link should lead to [[file:%s::*target headline][target]]', target_path),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** target headline', vim.api.nvim_get_current_line())
  end)

  it('should follow link to headline of given custom_id in given org file', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** headline of target custom_id',
      '   :PROPERTIES:',
      '   :CUSTOM_ID: target',
      '   :END:',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    vim.cmd([[norm w]])
    helpers.load_file_content({
      string.format('This link should lead to [[file:%s::#target][target]]', target_path),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of target custom_id', vim.api.nvim_get_current_line())
  end)

  it('should follow link to id', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** headline of target id',
      '   :PROPERTIES:',
      '   :ID: 8ce79e8c-0b5d-4fd6-9eea-ab47c93398ba',
      '   :END:',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    local source_path = helpers.load_file_content({
      'This link should lead to [[id:8ce79e8c-0b5d-4fd6-9eea-ab47c93398ba][headline of target with id]]',
    })
    local org = require('orgmode').setup({
      org_agenda_files = {
        vim.fn.fnamemodify(target_path, ':p:h')..'**/*',
      }
    })
    org:init()
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    vim.print(vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.is.same('** headline of target id', vim.api.nvim_get_current_line())
  end)

  it('should follow link to headline of given custom_id in given org file (no "file:" prefix)', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** headline of target custom_id',
      '   :PROPERTIES:',
      '   :CUSTOM_ID: target',
      '   :END:',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    assert.is.truthy(target_path)
    if not target_path then
      return
    end
    local dir = vim.fs.dirname(target_path)
    local url = target_path:gsub(dir, '.')
    vim.cmd([[norm w]])
    helpers.load_file_content({
      string.format('This link should lead to [[%s::#target][target]]', url),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of target custom_id', vim.api.nvim_get_current_line(), string.format('in file %s', url))
  end)

  it('should follow link to headline of given dedicated target', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      '  an [[target][internal link]]',
      '  - some',
      '  - boiler',
      '  - plate',
      '** headline of a deticated anchor',
      '   - more',
      '   - boiler',
      '   - plate <<target>>',
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(2, 30)
    assert.is.same('  an [[target][internal link]]', vim.api.nvim_get_current_line())
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of a deticated anchor', vim.api.nvim_get_current_line())
  end)

  it('should follow link to certain line (orgmode standard notation)', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      '  - some',
      '  - boiler',
      '  - plate',
      '** some headline',
      '   - more',
      '   - boiler',
      '   - plate',
      ' ->   9',
      ' ->  10',
      ' --> eleven <--',
      ' ->  12',
      ' ->  13',
      ' ->  14',
      ' ->  15 <--',
    })
    vim.cmd([[norm w]])
    assert.is.truthy(target_path)
    if not target_path then
      return
    end
    local dir = vim.fs.dirname(target_path)
    local url = target_path:gsub(dir, '.')
    helpers.load_file_content({
      string.format('This [[%s::11][link]] should bring us to the 11th line.', url),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 10)
    vim.cmd([[norm ,oo]])
    assert.is.same(' --> eleven <--', vim.api.nvim_get_current_line())
  end)

  it('should follow link to certain line (nvim-orgmode compatibility)', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      '  - some',
      '  - boiler',
      '  - plate',
      '** some headline',
      '   - more',
      '   - boiler',
      '   - plate',
      ' ->   9',
      ' ->  10',
      ' --> eleven <--',
      ' ->  12',
      ' ->  13',
      ' ->  14',
      ' ->  15 <--',
    })
    vim.cmd([[norm w]])
    assert.is.truthy(target_path)
    if not target_path then
      return
    end
    local dir = vim.fs.dirname(target_path)
    local url = target_path:gsub(dir, '.')
    helpers.load_file_content({
      string.format('This [[%s +11][link]] should bring us to the 11th line.', url),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 10)
    vim.cmd([[norm ,oo]])
    assert.is.same(' --> eleven <--', vim.api.nvim_get_current_line())
  end)
end)
