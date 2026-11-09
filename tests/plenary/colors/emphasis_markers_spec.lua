local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

describe('emphasis markers', function()
  ---@return string[] concealed ranges as "row:start_col-end_col"
  local function get_concealed(content)
    helpers.create_file(content)
    local bufnr = vim.api.nvim_get_current_buf()
    local parser = vim.treesitter.get_parser(bufnr, 'org')
    local root = parser:parse()[1]:root()
    local query = vim.treesitter.query.get('org', 'highlights')
    local concealed = {}
    for id, node, metadata in query:iter_captures(root, bufnr) do
      local conceal = metadata.conceal or (metadata[id] and metadata[id].conceal)
      if conceal == '' then
        local row, start_col, _, end_col = node:range()
        table.insert(concealed, ('%d:%d-%d'):format(row, start_col, end_col))
      end
    end
    return concealed
  end

  ---@return string[] delimiter captures as "group row:start_col-end_col"
  local function get_delimiters(content)
    helpers.create_file(content)
    local bufnr = vim.api.nvim_get_current_buf()
    local parser = vim.treesitter.get_parser(bufnr, 'org')
    local root = parser:parse()[1]:root()
    local query = vim.treesitter.query.get('org', 'highlights')
    local delimiters = {}
    for id, node in query:iter_captures(root, bufnr) do
      local name = query.captures[id]
      if name:match('^org%.%a+%.delimiter$') and name ~= 'org.table.delimiter' then
        local row, start_col, _, end_col = node:range()
        table.insert(delimiters, ('%s %d:%d-%d'):format(name, row, start_col, end_col))
      end
    end
    return delimiters
  end

  after_each(function()
    config:extend({ org_hide_emphasis_markers = false })
    vim.cmd([[%bw!]])
  end)

  it('are concealed when org_hide_emphasis_markers is enabled', function()
    config:extend({ org_hide_emphasis_markers = true })
    local concealed = get_concealed({
      '*bold* /italic/ _underline_ +strike+ =code= ~verbatim~',
    })
    assert.are.same({
      '0:0-1',
      '0:5-6',
      '0:7-8',
      '0:14-15',
      '0:16-17',
      '0:26-27',
      '0:28-29',
      '0:35-36',
      '0:37-38',
      '0:42-43',
      '0:44-45',
      '0:53-54',
    }, concealed)
  end)

  it('are not concealed when org_hide_emphasis_markers is disabled', function()
    config:extend({ org_hide_emphasis_markers = false })
    local concealed = get_concealed({
      '*bold* /italic/ _underline_ +strike+ =code= ~verbatim~',
    })
    assert.are.same({}, concealed)
  end)

  -- Emacs (org-element--parse-generic-emphasis, Org 9.8.7) accepts any whitespace before
  -- the opening marker
  it('are concealed after a tab', function()
    config:extend({ org_hide_emphasis_markers = true })
    local concealed = get_concealed({
      'text\t*bold*',
    })
    assert.are.same({ '0:5-6', '0:10-11' }, concealed)
  end)

  it('get their own delimiter highlight groups', function()
    local delimiters = get_delimiters({
      '*bold* /italic/ _underline_ +strike+ =code= ~verbatim~',
    })
    assert.are.same({
      'org.bold.delimiter 0:0-1',
      'org.bold.delimiter 0:5-6',
      'org.italic.delimiter 0:7-8',
      'org.italic.delimiter 0:14-15',
      'org.underline.delimiter 0:16-17',
      'org.underline.delimiter 0:26-27',
      'org.strikethrough.delimiter 0:28-29',
      'org.strikethrough.delimiter 0:35-36',
      'org.verbatim.delimiter 0:37-38',
      'org.verbatim.delimiter 0:42-43',
      'org.code.delimiter 0:44-45',
      'org.code.delimiter 0:53-54',
    }, delimiters)
  end)

  it('get no delimiter highlight groups for invalid markup', function()
    assert.are.same({}, get_delimiters({ 'text a*bold* text' }))
  end)

  it('are not concealed for invalid markup', function()
    config:extend({ org_hide_emphasis_markers = true })
    local concealed = get_concealed({
      'text a*bold* text',
    })
    assert.are.same({}, concealed)
  end)
end)
