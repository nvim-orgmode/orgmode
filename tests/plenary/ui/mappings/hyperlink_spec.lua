local helpers = require('tests.plenary.helpers')
local OrgId = require('orgmode.org.id')

describe('Hyperlink mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should follow link to given headline in given org file', function()
    local orgfile = helpers.create_agenda_file({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** target headline',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    helpers.create_agenda_file({
      string.format('This link should lead to [[file:%s::*target headline][target]]', orgfile.filename),
    })
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** target headline', vim.api.nvim_get_current_line())
  end)

  it('should follow link to headline of given custom_id in given org file', function()
    local target_file = helpers.create_file({
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
    helpers.create_file({
      string.format('This link should lead to [[file:%s::#target][target]]', target_file.filename),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of target custom_id', vim.api.nvim_get_current_line())
  end)

  it('should follow link to id in headline', function()
    local target_file = helpers.create_agenda_file({
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
    helpers.create_agenda_file({
      'This link should lead to [[id:8ce79e8c-0b5d-4fd6-9eea-ab47c93398ba][headline of target with id]]',
    })
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of target id', vim.api.nvim_get_current_line())
  end)

  it('should follow link to id in file', function()
    local target_file = helpers.create_agenda_file({
      ':PROPERTIES:',
      ':ID: add6b93c-9e0e-4922-a4f5-c00926787197',
      ':END:',
      '* Test hyperlink to file',
      ' - some',
      ' - boiler',
      ' - plate',
    })
    helpers.create_agenda_file({
      'This link should lead to [[id:add6b93c-9e0e-4922-a4f5-c00926787197][target file]]',
    })
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.are.same(target_file.filename, vim.api.nvim_buf_get_name(0))
    assert.is.same(':PROPERTIES:', vim.api.nvim_get_current_line())
  end)

  it('should store link to a headline', function()
    local target_file = helpers.create_agenda_file({
      '* Test hyperlink',
      ' - some',
      '** headline of target id',
      '   - more',
      '   - boiler',
      '   - plate',
      '* Test hyperlink 2',
    })
    vim.fn.cursor(4, 10)
    vim.cmd([[norm ,ols]])
    assert.are.same({
      [('file:%s::*headline of target id'):format(target_file.filename)] = 'headline of target id',
    }, require('orgmode.org.hyperlinks').stored_links)
  end)

  it('should store link to a headline with id', function()
    require('orgmode.org.hyperlinks').stored_links = {}
    local org = require('orgmode').setup({
      org_id_link_to_org_use_id = true,
    })
    helpers.create_file({
      '* Test hyperlink',
      ' - some',
      '** headline of target id',
      '   - more',
      '   - boiler',
      '   - plate',
      '* Test hyperlink 2',
    })

    org:init()
    vim.fn.cursor(4, 10)
    vim.cmd([[norm ,ols]])
    local stored_links = require('orgmode.org.hyperlinks').stored_links
    local keys = vim.tbl_keys(stored_links)
    local values = vim.tbl_values(stored_links)
    assert.is.True(keys[1]:match('^id:' .. OrgId.uuid_pattern .. '.*$') ~= nil)
    assert.is.True(vim.fn.getline(5):match('%s+:ID: ' .. OrgId.uuid_pattern .. '$') ~= nil)
    assert.is.same(values[1], 'headline of target id')
  end)

  it('should follow link to headline of given custom_id in given org file (no "file:" prefix)', function()
    local target_file = helpers.create_file({
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
    local dir = vim.fs.dirname(target_file.filename)
    local url = target_file.filename:gsub(dir, '.')
    vim.cmd([[norm w]])
    helpers.create_file({
      string.format('This link should lead to [[%s::#target][target]]', url),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of target custom_id', vim.api.nvim_get_current_line(), string.format('in file %s', url))
  end)

  it('should follow link to headline of given dedicated target', function()
    helpers.create_file({
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
    local target_file = helpers.create_file({
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
    local dir = vim.fs.dirname(target_file.filename)
    local url = target_file.filename:gsub(dir, '.')
    helpers.create_file({
      string.format('This [[%s::11][link]] should bring us to the 11th line.', url),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 10)
    vim.cmd([[norm ,oo]])
    assert.is.same(' --> eleven <--', vim.api.nvim_get_current_line())
  end)

  it('should follow link to certain line (nvim-orgmode compatibility)', function()
    local target_file = helpers.create_file({
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
    assert.is.truthy(target_file)
    if not target_file then
      return
    end
    local dir = vim.fs.dirname(target_file.filename)
    local url = target_file.filename:gsub(dir, '.')
    helpers.create_file({
      string.format('This [[%s +11][link]] should bring us to the 11th line.', url),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 10)
    vim.cmd([[norm ,oo]])
    assert.is.same(' --> eleven <--', vim.api.nvim_get_current_line())
  end)
end)
