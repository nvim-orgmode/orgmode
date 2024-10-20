local Range = require('orgmode.files.elements.range')
local Table = require('orgmode.files.elements.table')

describe('Table', function()
  it('should calculate column width', function()
    local data = {
      { 'one', 'two', 'three' },
      { 'four', 'five', 'six', 'seven' },
      'hr',
      { 'eight' },
      { 'nine', 'ten' },
    }

    local tbl = Table.from_list(data)
    assert.are.same({ 5, 4, 5, 5 }, tbl.cols_width)
    assert.are.same({
      '| one   | two  | three |       |',
      '| four  | five | six   | seven |',
      '|-------+------+-------+-------|',
      '| eight |      |       |       |',
      '| nine  | ten  |       |       |',
    }, tbl:draw())

    assert.are.same(tbl.rows[1].cells[1].range, Range:new({ start_line = 1, end_line = 1, start_col = 3, end_col = 5 }))
    assert.are.same(
      tbl.rows[1].cells[2].range,
      Range:new({ start_line = 1, end_line = 1, start_col = 11, end_col = 13 })
    )
    assert.are.same(
      tbl.rows[1].cells[3].range,
      Range:new({ start_line = 1, end_line = 1, start_col = 18, end_col = 22 })
    )
    assert.are.same(
      tbl.rows[1].cells[4].range,
      Range:new({ start_line = 1, end_line = 1, start_col = 26, end_col = 26 })
    )

    local data_with_long_names = {
      { 'one', 'two', 'three' },
      'hr',
      { 'four', 'five', 'six', 'seven longer long' },
      { 'eight', 'iamverylong' },
      { 'nine', 'ten', 'a' },
    }

    tbl = Table.from_list(data_with_long_names)
    assert.are.same({ 5, 11, 5, 17 }, tbl.cols_width)
    assert.are.same({
      '| one   | two         | three |                   |',
      '|-------+-------------+-------+-------------------|',
      '| four  | five        | six   | seven longer long |',
      '| eight | iamverylong |       |                   |',
      '| nine  | ten         | a     |                   |',
    }, tbl:draw())
  end)
end)
