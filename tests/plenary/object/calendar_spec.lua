local helpers = require('tests.plenary.helpers')
local Calendar = require('orgmode.objects.calendar')
local Date = require('orgmode.objects.date')

local close_all_buffers = function()
  vim.cmd([[silent! %bw!]])
end

local feed = function(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true), 'x', true)
end

describe('Calendar', function()
  after_each(close_all_buffers)
  it('should open a calendar at plain headline', function()
    helpers.create_agenda_file({
      '#+TITLE: Test',
      '',
      '* Some Headline',
    })
    vim.fn.cursor(3, 1)
    vim.cmd('norm ,oid')
  end)

  it('should change a deadline', function()
    helpers.create_agenda_file({
      '#+TITLE: Test',
      '',
      '* Some Headline',
      '  DEADLINE: <2024-06-01 Sat>',
    })
    vim.fn.cursor(3, 1)
    vim.cmd('norm ,oid')
    feed('l<CR>')

    assert.are.same({
      '* Some Headline',
      '  DEADLINE: <2024-06-02 Sun>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
  end)

  it('should render the month correctly', function()
    helpers.create_agenda_file({
      '#+TITLE: Test',
      '',
      '* Some Headline',
      '  DEADLINE: <2024-05-31 Fri>',
    })
    vim.fn.cursor(3, 1)
    vim.cmd('norm ,oid')

    assert.are.same({
      ' Mon  Tue  Wed  Thu  Fri  Sat  Sun',
      '           01   02   03   04   05 ',
      ' 06   07   08   09   10   11   12 ',
      ' 13   14   15   16   17   18   19 ',
      ' 20   21   22   23   24   25   26 ',
      ' 27   28   29   30   31 ',
      '  ',
      '               --:--              ',
      '',
    }, vim.api.nvim_buf_get_lines(0, 1, 10, false))
  end)

  it('should render at the end of a long month', function()
    local date = Date.from_string('2024-05-31')
    local cal_instance = Calendar.new({ date = date, title = date:to_string() })
    cal_instance:open()
    local cal_date = cal_instance.date
    assert.are.same('2024-05-31 Fri', cal_date and cal_date:to_string())
  end)

  it('should handle the end of the month correctly', function()
    local date = Date.from_string('2024-05-31')
    local cal_instance = Calendar.new({ date = date, title = date:to_string() })
    cal_instance:open()
    feed('>')
    vim.wait(50)
    feed('<CR>')
    local cal_date = cal_instance.date
    assert.are.same('2024-06-01 Sat', cal_date and cal_date:to_string())
  end)
end)
