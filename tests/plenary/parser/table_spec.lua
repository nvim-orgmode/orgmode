local Table = require('orgmode.parser.table')

describe('Table', function()
  it('should calculate column width', function()
    local data = {
      { 'one', 'two', 'three' },
      { 'four', 'five', 'six', 'seven' },
      {},
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

    local data_with_long_names = {
      { 'one', 'two', 'three' },
      {},
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
