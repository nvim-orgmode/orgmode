local Link = require('orgmode.org.hyperlinks.link')

describe('Link.at_pos', function()
  ---@param obj any sut
  ---@param col number cursor position in line
  local function assert_valid_link_at(obj, col)
    assert(obj, string.format('%q at pos %d', obj, col))
  end

  ---@param property string 'url' or 'desc'
  ---@param obj any sut
  ---@param col number cursor position in line
  ---@param exp any
  local function assert_valid_link_property_at(property, obj, col, exp)
    local msg = function(_exp)
      return string.format('%s: Expected to be %s at %s, actually %q.', property, _exp, col, obj)
    end
    if exp then
      assert(obj == exp, msg(exp))
    else
      assert(obj ~= nil, msg('valid'))
    end
  end

  ---@param property string 'url' or 'desc'
  ---@param line string line of an orgfile
  ---@param col number cursor position in line
  local function assert_empty_link_property_at(property, line, col)
    assert(line == nil, string.format("%s: Expected to be 'nil' at %s, actually %q.", property, col, line))
  end

  ---@param line string line of an orgfile
  ---@param lb number position of left outer bracket of the link within the line
  ---@param rb number position of right outer bracket of the link within the line
  local function assert_link_in_range(line, lb, rb, opt)
    for pos = lb, rb do
      local link = Link.at_pos(line, pos)
      assert_valid_link_at(link, pos)
      if not link then
        return
      end
      assert_valid_link_property_at('url', link.url, pos)
      assert_valid_link_property_at('url', link.url:to_string(), pos, opt and opt.url)
      if not opt or not opt.desc then
        assert_empty_link_property_at('desc', link.desc, pos)
      elseif opt and opt.desc then
        assert_valid_link_property_at('desc', link.desc, pos, opt.desc)
      else
        assert(false, string.format('invalid opt %s', opt))
      end
    end
  end

  local function assert_not_link_in_range(line, lb, rb)
    for pos = lb, rb do
      local nil_link = Link.at_pos(line, pos)
      assert(
        not nil_link,
        string.format('Expected no link between %s and %s, got actually %q', lb, rb, nil_link and nil_link:to_str())
      )
    end
  end

  it('should not be empty like [[]]', function()
    local line = '[[]]'
    assert_not_link_in_range(line, 1, #line)
  end)
  it('should not be empty like [[][]]', function()
    local line = '[[][]]'
    assert_not_link_in_range(line, 1, #line)
  end)
  it('should not have an empty url like [[][some description]]', function()
    local line = '[[][some description]]'
    assert_not_link_in_range(line, 1, #line)
  end)
  it('could have an empty description like [[someurl]]', function()
    local line = '[[someurl]]'
    assert_link_in_range(line, 1, #line)
    local link_str = Link.at_pos(line, 1):to_str()
    assert(link_str == line, string.format('Expected %q, actually %q', line, link_str))
  end)
  it('should parse valid [[somefile][Some Description]]', function()
    local line = '[[somefile][Some Description]]'
    assert_link_in_range(line, 1, #line, { url = 'somefile', desc = 'Some Description' })
  end)
  it('should find link at valid positions in "1...5[[u_1][desc_1]]21.[[u_2]]...35[[u_3][desc_2]]51......60"', function()
    local line = '1...5[[u_1][desc_1]]21.[[u_2]]...35[[u_3][desc_2]]51......60'
    assert_not_link_in_range(line, 1, 5)
    assert_link_in_range(line, 6, 20, { url = 'u_1', desc = 'desc_1' })
    assert_not_link_in_range(line, 21, 23)
    assert_link_in_range(line, 24, 30, { url = 'u_2' })
    assert_not_link_in_range(line, 33, 35)
    assert_link_in_range(line, 36, 50, { url = 'u_3', desc = 'desc_2' })
    assert_not_link_in_range(line, 51, 60)
  end)
  it('should resolve a relative file path', function()
    local examples = {
      {
        '- [ ] Look here: [[file:./../sibling-folder/somefile.org::*some headline][some description]]',
        { 3, 4, 5 },
        { 20, 90 },
      },
    }
    for _, o in ipairs(examples) do
      local line, valid_cols, invalid_cols = o[1], o[2], o[3]
      for _, valid_pos in ipairs(valid_cols) do
        assert_valid_link_at(line, valid_pos)
      end
      for _, invalid_pos in ipairs(invalid_cols) do
        assert_valid_link_at(line, invalid_pos)
      end
    end
  end)
end)
