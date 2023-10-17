local Url = require('orgmode.objects.url')
describe('Url', function()
  it('should detect dedicated target for internal links', function()
    local anchor_examples = {
      'some anchor',
      'x',
      '_12 ABC',
      '123-456-2342',
    }
    for _, url_str in ipairs(anchor_examples) do
      local url = Url.new(url_str)
      local anchor = url:get_dedicated_target()
      assert(url_str ~= nil, string.format('Expected %q to be not nil', url_str))
      assert(anchor ~= nil, string.format('Expected dedicated anchor of %q to be not nil', url_str))
      assert(anchor == url_str, string.format('Expected %q, actual %q', url_str, anchor))
    end
  end)

  it('should classify dedicated target or internal titel correctly', function()
    local anchor_examples = {
      'some anchor',
      '_12 ABC',
      '123-456-2342',
      'x',
    }
    for _, url_str in ipairs(anchor_examples) do
      local url = Url.new(url_str)
      local is_title_or_anchor = url:is_dedicated_anchor_or_internal_title()
      assert(is_title_or_anchor, string.format('Expected %q to be true, actual false', url_str))
    end
  end)

  it('should detect a headline within a file url', function()
    local headline_examples = {
      {
        'file:./../parent_path/sibling_folder/somefile.org::*some headline',
        './../parent_path/sibling_folder/somefile.org',
        'some headline',
      },
    }
    for _, item in ipairs(headline_examples) do
      local input, expected_file, expected_hl = item[1], item[2], item[3]
      local url = Url.new(input)
      local filepath = url:get_filepath()
      local headline = url:get_headline()
      assert(url:is_file_headline(), "Expect to be a file with headline, but isn't")
      assert(filepath == expected_file, string.format('Expected %q, actual %q', expected_file, filepath))
      assert(headline == expected_hl, string.format('Expected %q, actual %q', expected_hl, headline))
    end
  end)

  it('should not detect too funky characters', function()
    local anchor_examples = {
      'a != b',
      '!bang',
      'a/file/path',
      '#custom_id',
      '*headline',
    }
    for _, url_str in ipairs(anchor_examples) do
      local url = Url.new(url_str)
      local anchor = url:get_dedicated_target()
      assert.is.falsy(anchor, nil, string.format('Expected %q to be resolved to nil, actual %q', url_str, anchor))
    end
  end)

  it('should handle different file paths', function()
    local filepath_examples = {
      { url_str = 'file:./../some_file', exp = './../some_file' },
      { url_str = './../some_file.txt', exp = './../some_file.txt' },
      { url_str = '/some/path/some_file', exp = '/some/path/some_file' },
      { url_str = 'file:./../some_file.org::*headline', exp = './../some_file.org' },
      { url_str = 'file:./../some_file.org::#custom_id', exp = './../some_file.org' },
      { url_str = 'file:./../some_file.org::an anchor', exp = './../some_file.org' },
      { url_str = 'file:./../some_file.org::123', exp = './../some_file.org' },
      { url_str = 'file:./../some_file.org +123', exp = './../some_file.org' },
      { url_str = './../some_file.org::*headline', exp = './../some_file.org' },
      { url_str = './../some_file.org::#custom_id', exp = './../some_file.org' },
      { url_str = './../some_file.org::an anchor', exp = './../some_file.org' },
      { url_str = './../some_file.org::123', exp = './../some_file.org' },
      { url_str = './../some_file.org +123', exp = './../some_file.org' },
      { url_str = '/some/path/some_file.org::*headline', exp = '/some/path/some_file.org' },
      { url_str = '/some/path/some_file.org::#custom_id', exp = '/some/path/some_file.org' },
      { url_str = '/some/path/some_file.org::an anchor', exp = '/some/path/some_file.org' },
      { url_str = '/some/path/some_file.org::123', exp = '/some/path/some_file.org' },
      { url_str = '/some/path/some_file.org +123', exp = '/some/path/some_file.org' },
    }
    for _, tc in ipairs(filepath_examples) do
      local url = Url.new(tc.url_str)
      local filepath = url:get_filepath()
      assert.is.same(tc.exp, filepath, string.format('Failed for url %q:', tc.url_str))
    end
  end)
end)
