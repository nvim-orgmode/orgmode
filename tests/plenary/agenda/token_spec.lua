local AgendaLineToken = require('orgmode.agenda.view.token')
local Range = require('orgmode.files.elements.range')
local OrgFile = require('orgmode.files.file')
local config = require('orgmode.config')
local helpers = require('tests.plenary.helpers')

---@param title string
---@param from_buffer? boolean
---@return OrgAgendaLineToken
local function create_token(title, from_buffer)
  local file
  if from_buffer then
    file = helpers.create_file({ '* TODO ' .. title })
  else
    -- Agenda files are usually loaded from disk without a buffer, so the source is a string
    local fname = vim.fn.tempname() .. '.org'
    vim.fn.writefile({ '* TODO ' .. title }, fname)
    file = OrgFile.load(fname):wait()
  end
  local headline = file:get_headlines()[1]
  local content = headline:get_title()
  return AgendaLineToken:new({
    content = content,
    range = Range:new({ start_line = 1, end_line = 1, start_col = 10, end_col = 10 + #content }),
    add_markup_to_headline = headline,
  })
end

---@param highlights table[]
local function simplify(highlights)
  return vim.tbl_map(function(hl)
    return { hl.hlgroup, hl.range.start_col, hl.range.end_col, hl.conceal }
  end, highlights)
end

describe('Agenda line token', function()
  after_each(function()
    config:extend({ org_hide_emphasis_markers = false })
  end)

  it('should highlight all emphasis types', function()
    local token = create_token('a *b* /i/ _u_ +s+ ~c~ =v=')
    assert.are.same({
      { '@org.bold', 12, 15 },
      { '@org.bold.delimiter', 12, 13 },
      { '@org.bold.delimiter', 14, 15 },
      { '@org.italic', 16, 19 },
      { '@org.italic.delimiter', 16, 17 },
      { '@org.italic.delimiter', 18, 19 },
      { '@org.underline', 20, 23 },
      { '@org.underline.delimiter', 20, 21 },
      { '@org.underline.delimiter', 22, 23 },
      { '@org.strikethrough', 24, 27 },
      { '@org.strikethrough.delimiter', 24, 25 },
      { '@org.strikethrough.delimiter', 26, 27 },
      { '@org.code', 28, 31 },
      { '@org.code.delimiter', 28, 29 },
      { '@org.code.delimiter', 30, 31 },
      { '@org.verbatim', 32, 35 },
      { '@org.verbatim.delimiter', 32, 33 },
      { '@org.verbatim.delimiter', 34, 35 },
    }, simplify(token:get_highlights()))
  end)

  it('should highlight emphasis when the file is opened in a buffer', function()
    local token = create_token('a *b*', true)
    assert.are.same({
      { '@org.bold', 12, 15 },
      { '@org.bold.delimiter', 12, 13 },
      { '@org.bold.delimiter', 14, 15 },
    }, simplify(token:get_highlights()))
  end)

  it('should highlight nested emphasis', function()
    local token = create_token('*b /i/*')
    assert.are.same({
      { '@org.bold', 10, 17 },
      { '@org.bold.delimiter', 10, 11 },
      { '@org.bold.delimiter', 16, 17 },
      { '@org.italic', 13, 16 },
      { '@org.italic.delimiter', 13, 14 },
      { '@org.italic.delimiter', 15, 16 },
    }, simplify(token:get_highlights()))
  end)

  it('should not highlight emphasis inside a word', function()
    local token = create_token('a x*b* c')
    assert.are.same({}, simplify(token:get_highlights()))
  end)

  it('should conceal markers when org_hide_emphasis_markers is enabled', function()
    config:extend({ org_hide_emphasis_markers = true })
    local token = create_token('*b*')
    assert.are.same({
      { '@org.bold', 10, 13 },
      { '@org.bold.delimiter', 10, 11, '' },
      { '@org.bold.delimiter', 12, 13, '' },
    }, simplify(token:get_highlights()))
  end)
end)
