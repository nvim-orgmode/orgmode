local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')
local org = require('orgmode')
local api = vim.api

describe('highlighter', function()
  local ns_id = api.nvim_create_namespace('org_custom_highlighter')
  local get_extmarks = function(content)
    ---@diagnostic disable-next-line: inject-field
    config.ts_hl_enabled = true
    helpers.create_file(content)
    ---@diagnostic disable-next-line: invisible
    org.highlighter._ephemeral = false
    vim.cmd([[redraw!]])

    return api.nvim_buf_get_extmarks(api.nvim_get_current_buf(), ns_id, 0, -1, {
      details = true,
    })
  end

  local assert_extmark = function(extmark, opts)
    opts = opts or {}
    local details = extmark[4]
    assert.are.same(opts.line, extmark[2], 'line is not matching')
    assert.are.same(opts.start_col, extmark[3], 'start col is not matching')
    assert.are.same(opts.end_col, details.end_col, 'end col is not matching')
    if opts.hl_group ~= nil then
      assert.are.same(opts.hl_group, details.hl_group, 'hl group is not matching')
    end
    if opts.conceal ~= nil then
      assert.are.same(opts.conceal, details.conceal, 'conceal is not matching')
    end
    if opts.spell ~= nil then
      assert.are.same(opts.spell, details.spell, 'spell is not matching')
    end
  end

  after_each(function()
    vim.cmd([[%bw!]])
    ---@diagnostic disable-next-line: inject-field
    config.ts_hl_enabled = false
    ---@diagnostic disable-next-line: invisible
    org.highlighter._ephemeral = true
  end)

  describe('emphasis', function()
    it('should highlight bold', function()
      local extmarks = get_extmarks({
        'I am *bold* text',
      })
      assert.are.same(3, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 5, end_col = 6, hl_group = '@org.bold.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 6, end_col = 10, hl_group = '@org.bold' })
      assert_extmark(extmarks[3], { line = 0, start_col = 10, end_col = 11, hl_group = '@org.bold.delimiter' })
    end)

    it('should highlight italic', function()
      local extmarks = get_extmarks({
        'I am /italic/ text',
      })
      assert.are.same(3, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 5, end_col = 6, hl_group = '@org.italic.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 6, end_col = 12, hl_group = '@org.italic' })
      assert_extmark(extmarks[3], { line = 0, start_col = 12, end_col = 13, hl_group = '@org.italic.delimiter' })
    end)

    it('should highlight underline', function()
      local extmarks = get_extmarks({
        'I am _underline_ text',
      })
      assert.are.same(3, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 5, end_col = 6, hl_group = '@org.underline.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 6, end_col = 15, hl_group = '@org.underline' })
      assert_extmark(extmarks[3], { line = 0, start_col = 15, end_col = 16, hl_group = '@org.underline.delimiter' })
    end)

    it('should highlight strikethrough', function()
      local extmarks = get_extmarks({
        'I am +strikethrough+ text',
      })
      assert.are.same(3, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 5, end_col = 6, hl_group = '@org.strikethrough.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 6, end_col = 19, hl_group = '@org.strikethrough' })
      assert_extmark(extmarks[3], { line = 0, start_col = 19, end_col = 20, hl_group = '@org.strikethrough.delimiter' })
    end)

    it('should highlight dode', function()
      local extmarks = get_extmarks({
        'I am ~code~ text',
      })
      assert.are.same(3, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 5, end_col = 6, hl_group = '@org.code.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 6, end_col = 10, hl_group = '@org.code' })
      assert_extmark(extmarks[3], { line = 0, start_col = 10, end_col = 11, hl_group = '@org.code.delimiter' })
    end)

    it('should highlight verbatim', function()
      local extmarks = get_extmarks({
        'I am =verbatim= text',
      })
      assert.are.same(3, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 5, end_col = 6, hl_group = '@org.verbatim.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 6, end_col = 14, hl_group = '@org.verbatim' })
      assert_extmark(extmarks[3], { line = 0, start_col = 14, end_col = 15, hl_group = '@org.verbatim.delimiter' })
    end)

    it('should highlight mix of emphasis that is nestable', function()
      local extmarks = get_extmarks({
        'I am *bold /italic and _underline_/* text',
      })
      assert.are.same(9, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 5, end_col = 6, hl_group = '@org.bold.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 6, end_col = 35, hl_group = '@org.bold' })
      assert_extmark(extmarks[3], { line = 0, start_col = 11, end_col = 12, hl_group = '@org.italic.delimiter' })
      assert_extmark(extmarks[4], { line = 0, start_col = 12, end_col = 34, hl_group = '@org.italic' })
      assert_extmark(extmarks[5], { line = 0, start_col = 23, end_col = 24, hl_group = '@org.underline.delimiter' })
      assert_extmark(extmarks[6], { line = 0, start_col = 24, end_col = 33, hl_group = '@org.underline' })
      assert_extmark(extmarks[7], { line = 0, start_col = 33, end_col = 34, hl_group = '@org.underline.delimiter' })
      assert_extmark(extmarks[8], { line = 0, start_col = 34, end_col = 35, hl_group = '@org.italic.delimiter' })
      assert_extmark(extmarks[9], { line = 0, start_col = 35, end_col = 36, hl_group = '@org.bold.delimiter' })
    end)

    it('should conceal markers if org_hide_emphasis_markers is true', function()
      config.opts.org_hide_emphasis_markers = true
      local extmarks = get_extmarks({
        'Text with *bold /italic/* text',
      })

      assert.are.same(6, #extmarks)
      assert_extmark(
        extmarks[1],
        { line = 0, start_col = 10, end_col = 11, hl_group = '@org.bold.delimiter', conceal = '' }
      )
      assert_extmark(extmarks[2], { line = 0, start_col = 11, end_col = 24, hl_group = '@org.bold' })
      assert_extmark(
        extmarks[3],
        { line = 0, start_col = 16, end_col = 17, hl_group = '@org.italic.delimiter', conceal = '' }
      )
      assert_extmark(extmarks[4], { line = 0, start_col = 17, end_col = 23, hl_group = '@org.italic' })
      assert_extmark(
        extmarks[5],
        { line = 0, start_col = 23, end_col = 24, hl_group = '@org.italic.delimiter', conceal = '' }
      )
      assert_extmark(
        extmarks[6],
        { line = 0, start_col = 24, end_col = 25, hl_group = '@org.bold.delimiter', conceal = '' }
      )
      config.opts.org_hide_emphasis_markers = false
    end)

    it('should highlight emphasis in headline', function()
      local extmarks = get_extmarks({
        '* Headline with *bold /italic/* text',
        '- list item',
        '- list item',
      })
      assert.are.same(6, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 16, end_col = 17, hl_group = '@org.bold.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 17, end_col = 30, hl_group = '@org.bold' })
      assert_extmark(extmarks[3], { line = 0, start_col = 22, end_col = 23, hl_group = '@org.italic.delimiter' })
      assert_extmark(extmarks[4], { line = 0, start_col = 23, end_col = 29, hl_group = '@org.italic' })
      assert_extmark(extmarks[5], { line = 0, start_col = 29, end_col = 30, hl_group = '@org.italic.delimiter' })
      assert_extmark(extmarks[6], { line = 0, start_col = 30, end_col = 31, hl_group = '@org.bold.delimiter' })
    end)

    it('should highlight emphasis in list item', function()
      local extmarks = get_extmarks({
        '- list item',
        '- note with *bold /italic/* text',
        '- list item',
      })
      assert.are.same(6, #extmarks)
      assert_extmark(extmarks[1], { line = 1, start_col = 12, end_col = 13, hl_group = '@org.bold.delimiter' })
      assert_extmark(extmarks[2], { line = 1, start_col = 13, end_col = 26, hl_group = '@org.bold' })
      assert_extmark(extmarks[3], { line = 1, start_col = 18, end_col = 19, hl_group = '@org.italic.delimiter' })
      assert_extmark(extmarks[4], { line = 1, start_col = 19, end_col = 25, hl_group = '@org.italic' })
      assert_extmark(extmarks[5], { line = 1, start_col = 25, end_col = 26, hl_group = '@org.italic.delimiter' })
      assert_extmark(extmarks[6], { line = 1, start_col = 26, end_col = 27, hl_group = '@org.bold.delimiter' })
    end)

    it('should not render emphasis that is nested in non-nestable emphasis', function()
      local extmarks = get_extmarks({
        'I am =verbatim and *not bold* part= of text',
      })
      assert.are.same(3, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 5, end_col = 6, hl_group = '@org.verbatim.delimiter' })
      assert_extmark(extmarks[2], { line = 0, start_col = 6, end_col = 34, hl_group = '@org.verbatim' })
      assert_extmark(extmarks[3], { line = 0, start_col = 34, end_col = 35, hl_group = '@org.verbatim.delimiter' })
    end)

    it('should not render emphasis if pre-chars are not valid', function()
      local extmarks = get_extmarks({
        'I am v*bold* text',
      })
      assert.are.same(0, #extmarks)
    end)

    it('should not render emphasis if post-chars are not valid', function()
      local extmarks = get_extmarks({
        'I am *not bold*v text',
      })
      assert.are.same(0, #extmarks)
    end)
  end)

  describe('links', function()
    it('should highlight links without label', function()
      local extmarks = get_extmarks({
        'I have [[https://google.com]] link',
      })
      assert.are.same(4, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 7, end_col = 29, hl_group = '@org.hyperlink' })
      assert_extmark(extmarks[2], { line = 0, start_col = 7, end_col = 9, conceal = '' })
      assert_extmark(extmarks[3], { line = 0, start_col = 9, end_col = 27, spell = false })
      assert_extmark(extmarks[4], { line = 0, start_col = 27, end_col = 29, conceal = '' })
    end)

    it('should highlight links with label', function()
      local extmarks = get_extmarks({
        'I have [[https://google.com][google]] link',
      })
      assert.are.same(4, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 7, end_col = 37, hl_group = '@org.hyperlink' })
      assert_extmark(extmarks[2], { line = 0, start_col = 7, end_col = 29, conceal = '' })
      assert_extmark(extmarks[3], { line = 0, start_col = 9, end_col = 27, spell = false })
      assert_extmark(extmarks[4], { line = 0, start_col = 35, end_col = 37, conceal = '' })
    end)

    it('should highlight links with label and not render any markup inside', function()
      local extmarks = get_extmarks({
        'I have [[https://google.com][google I am *not bold*]] link',
      })
      assert.are.same(4, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 7, end_col = 53, hl_group = '@org.hyperlink' })
      assert_extmark(extmarks[2], { line = 0, start_col = 7, end_col = 29, conceal = '' })
      assert_extmark(extmarks[3], { line = 0, start_col = 9, end_col = 27, spell = false })
      assert_extmark(extmarks[4], { line = 0, start_col = 51, end_col = 53, conceal = '' })
    end)

    it('should not highlight invalid link', function()
      local extmarks = get_extmarks({
        'I am not a [[https://google.com] link',
      })
      assert.are.same(0, #extmarks)
    end)
  end)

  describe('latex', function()
    it('should highlight latex with backslash only', function()
      local extmarks = get_extmarks({
        [[this is \latex text]],
        [[this is \latex{} text]],
        [[this is \latex{inside} text]],
        [[this is \latex[] text]],
        [[this is \latex[inside] text]],
        [[this is \latex() text]],
        [[this is \latex(inside) text]],
      })
      assert.are.same(7, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 8, end_col = 14, hl_group = '@org.latex' })
      assert_extmark(extmarks[2], { line = 1, start_col = 8, end_col = 16, hl_group = '@org.latex' })
      assert_extmark(extmarks[3], { line = 2, start_col = 8, end_col = 15, hl_group = '@org.latex' })
      assert_extmark(extmarks[4], { line = 3, start_col = 8, end_col = 16, hl_group = '@org.latex' })
      assert_extmark(extmarks[5], { line = 4, start_col = 8, end_col = 15, hl_group = '@org.latex' })
      assert_extmark(extmarks[6], { line = 5, start_col = 8, end_col = 16, hl_group = '@org.latex' })
      assert_extmark(extmarks[7], { line = 6, start_col = 8, end_col = 15, hl_group = '@org.latex' })
    end)

    it('should highlight latex with backslash brackets', function()
      local extmarks = get_extmarks({
        [[this is \(1 + 1\) math]],
        [[this is \[1 + 1\] math]],
        [[this is \{1 + 1\} math]],
      })
      assert.are.same(3, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 8, end_col = 17, hl_group = '@org.latex' })
      assert_extmark(extmarks[2], { line = 1, start_col = 8, end_col = 17, hl_group = '@org.latex' })
      assert_extmark(extmarks[3], { line = 2, start_col = 8, end_col = 17, hl_group = '@org.latex' })
    end)
  end)

  describe('dates', function()
    it('should highlight active dates', function()
      local extmarks = get_extmarks({
        'the date <2024-02-16>',
        'the date <2024-02-16 Fri>',
        'the date <2024-02-16 Fri 12:30>',
        'the date <2024-02-16 Fri 12:30 +1m>',
        'the date <2024-02-16 Fri 12:30 +1m -1d>',
      })
      assert.are.same(5, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 9, end_col = 21, hl_group = '@org.timestamp.active' })
      assert_extmark(extmarks[2], { line = 1, start_col = 9, end_col = 25, hl_group = '@org.timestamp.active' })
      assert_extmark(extmarks[3], { line = 2, start_col = 9, end_col = 31, hl_group = '@org.timestamp.active' })
      assert_extmark(extmarks[4], { line = 3, start_col = 9, end_col = 35, hl_group = '@org.timestamp.active' })
      assert_extmark(extmarks[5], { line = 4, start_col = 9, end_col = 39, hl_group = '@org.timestamp.active' })
    end)

    it('should highlight inactive dates', function()
      local extmarks = get_extmarks({
        'the date [2024-02-16]',
        'the date [2024-02-16 Fri]',
        'the date [2024-02-16 Fri 12:30]',
        'the date [2024-02-16 Fri 12:30 +1m]',
        'the date [2024-02-16 Fri 12:30 +1m -1d]',
      })
      assert.are.same(5, #extmarks)
      assert_extmark(extmarks[1], { line = 0, start_col = 9, end_col = 21, hl_group = '@org.timestamp.inactive' })
      assert_extmark(extmarks[2], { line = 1, start_col = 9, end_col = 25, hl_group = '@org.timestamp.inactive' })
      assert_extmark(extmarks[3], { line = 2, start_col = 9, end_col = 31, hl_group = '@org.timestamp.inactive' })
      assert_extmark(extmarks[4], { line = 3, start_col = 9, end_col = 35, hl_group = '@org.timestamp.inactive' })
      assert_extmark(extmarks[5], { line = 4, start_col = 9, end_col = 39, hl_group = '@org.timestamp.inactive' })
    end)

    it('should not highlight invalid dates', function()
      local extmarks = get_extmarks({
        'the date [2024-02-16 .]',
        'the date <2024-02-16 Fri <>',
      })
      assert.are.same(0, #extmarks)
    end)
  end)
end)
