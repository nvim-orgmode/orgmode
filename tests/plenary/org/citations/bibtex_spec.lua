local OrgCitationBibtex = require('orgmode.org.citations.bibtex')
local OrgCompletionCitations = require('orgmode.org.autocompletion.sources.citations')
local helpers = require('tests.plenary.helpers')

local fixture_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h:h') .. '/fixtures/citations'

local refs_bib = fixture_dir .. '/refs.bib'
local extra_bib = fixture_dir .. '/extra.bib'

describe('OrgCitationBibtex', function()
  describe('get_items from global bibliography config', function()
    it('should return keys from a configured .bib file', function()
      local source = OrgCitationBibtex:new({ files = nil })
      local config = require('orgmode.config')
      local old = config.citations.org_cite_global_bibliography
      config.citations.org_cite_global_bibliography = refs_bib
      local items = source:get_items()
      config.citations.org_cite_global_bibliography = old

      local keys = vim.tbl_map(function(i)
        return i.key
      end, items)
      assert.truthy(vim.tbl_contains(keys, 'smith2020'))
      assert.truthy(vim.tbl_contains(keys, 'jones2021'))
      assert.truthy(vim.tbl_contains(keys, 'doe2022'))
      assert.truthy(vim.tbl_contains(keys, 'wang-2019'))
      -- @string should be skipped
      assert.falsy(vim.tbl_contains(keys, 'acm'))
    end)

    it('should accept an array of bibliography paths', function()
      local source = OrgCitationBibtex:new({ files = nil })
      local config = require('orgmode.config')
      local old = config.citations.org_cite_global_bibliography
      config.citations.org_cite_global_bibliography = { refs_bib, extra_bib }
      local items = source:get_items()
      config.citations.org_cite_global_bibliography = old

      local keys = vim.tbl_map(function(i)
        return i.key
      end, items)
      assert.truthy(vim.tbl_contains(keys, 'smith2020'))
      assert.truthy(vim.tbl_contains(keys, 'extra2023'))
    end)

    it('should return empty list when no bibliography is configured', function()
      local source = OrgCitationBibtex:new({ files = nil })
      local config = require('orgmode.config')
      local old = config.citations.org_cite_global_bibliography
      config.citations.org_cite_global_bibliography = nil
      local items = source:get_items()
      config.citations.org_cite_global_bibliography = old
      assert.are.same(0, #items)
    end)
  end)

  describe('get_items from file-local #+bibliography: directive', function()
    it('should return keys from #+bibliography: path relative to the org file', function()
      -- Use an absolute path in #+bibliography: to avoid CWD issues in tests
      helpers.create_agenda_file({
        '#+bibliography: ' .. refs_bib,
        '',
        '* Headline',
      })

      local source = OrgCitationBibtex:new({ files = require('orgmode').files })

      local config = require('orgmode.config')
      local old = config.citations.org_cite_global_bibliography
      config.citations.org_cite_global_bibliography = nil
      local items = source:get_items()
      config.citations.org_cite_global_bibliography = old

      local keys = vim.tbl_map(function(i)
        return i.key
      end, items)
      assert.truthy(vim.tbl_contains(keys, 'smith2020'))
      assert.truthy(vim.tbl_contains(keys, 'jones2021'))
    end)

    it('should combine global and file-local bibliographies', function()
      helpers.create_agenda_file({
        '#+bibliography: ' .. refs_bib,
        '',
        '* Headline',
      })

      local source = OrgCitationBibtex:new({ files = require('orgmode').files })

      local config = require('orgmode.config')
      local old = config.citations.org_cite_global_bibliography
      config.citations.org_cite_global_bibliography = extra_bib
      local items = source:get_items()
      config.citations.org_cite_global_bibliography = old

      local keys = vim.tbl_map(function(i)
        return i.key
      end, items)
      assert.truthy(vim.tbl_contains(keys, 'smith2020')) -- from file-local
      assert.truthy(vim.tbl_contains(keys, 'extra2023')) -- from global
    end)
  end)

  describe('follow', function()
    it('should open the .bib file and jump to the entry line', function()
      local source = OrgCitationBibtex:new({ files = nil })
      local config = require('orgmode.config')
      local old = config.citations.org_cite_global_bibliography
      config.citations.org_cite_global_bibliography = refs_bib
      local result = source:follow('jones2021')
      config.citations.org_cite_global_bibliography = old

      assert.is_true(result)
      -- Verify the current buffer is the bib file and cursor is on the entry
      assert.are.same(refs_bib, vim.api.nvim_buf_get_name(0))
      local line = vim.fn.getline('.')
      assert.truthy(line:match('jones2021'))

      vim.cmd('bwipeout!')
    end)

    it('should return false for an unknown key', function()
      local source = OrgCitationBibtex:new({ files = nil })
      local config = require('orgmode.config')
      local old = config.citations.org_cite_global_bibliography
      config.citations.org_cite_global_bibliography = refs_bib
      local result = source:follow('nosuchkey_xyz')
      config.citations.org_cite_global_bibliography = old
      assert.is_false(result)
    end)
  end)
end)

describe('OrgCompletionCitations regex', function()
  it('should be instantiable', function()
    local completion_mock = { citations = nil }
    local ok, result = pcall(OrgCompletionCitations.new, OrgCompletionCitations, {
      completion = completion_mock,
    })
    assert.is_true(ok, result)
    assert.truthy(result.pattern)
  end)

  it('should match a citation line and return the @ offset', function()
    local completion_mock = { citations = nil }
    local source = OrgCompletionCitations:new({ completion = completion_mock })
    local context = { line = '[cite:@smith' }
    local start = source:get_start(context)
    assert.truthy(start)
    assert.are.same(7, start)
  end)

  it('should match a styled citation line', function()
    local completion_mock = { citations = nil }
    local source = OrgCompletionCitations:new({ completion = completion_mock })
    local context = { line = '[cite/t:@doe' }
    local start = source:get_start(context)
    assert.truthy(start)
    assert.are.same(9, start)
  end)

  it('should not match plain text', function()
    local completion_mock = { citations = nil }
    local source = OrgCompletionCitations:new({ completion = completion_mock })
    local context = { line = 'some @text here' }
    local start = source:get_start(context)
    assert.falsy(start)
  end)
end)
