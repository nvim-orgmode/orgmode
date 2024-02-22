local Url = require('orgmode.org.hyperlinks.url')
describe('Url', function()
  describe('File url', function()
    it('should parse absolute url', function()
      local result = Url:new('/path/to/some/file.org')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.is.Nil(result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse relative url', function()
      local result = Url:new('./path/to/relative/file.org')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.is.Nil(result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse absolute url with protocol', function()
      local result = Url:new('file:/path/to/some/file.org')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.is.Nil(result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should parse relative url with protocol', function()
      local result = Url:new('file:./path/to/relative/file.org')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.is.Nil(result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should return proper checks', function()
      local result = Url:new('file:./path/to/relative/file.org')
      assert.is.True(result:is_file())
      assert.is.False(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.False(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.False(result:is_file_line_number())

      assert.is.False(result:is_plain())

      assert.are.same('./path/to/relative/file.org', result:get_file())
    end)
  end)

  describe('Headline url', function()
    it('should parse absolute url and headline', function()
      local result = Url:new('/path/to/some/file.org::*Headline')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'headline', value = 'Headline' }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse relative url and headline', function()
      local result = Url:new('./path/to/relative/file.org::*Headline')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'headline', value = 'Headline' }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse absolute url with protocol and headline', function()
      local result = Url:new('file:/path/to/some/file.org::*Headline')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'headline', value = 'Headline' }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should parse relative url with protocol and headline', function()
      local result = Url:new('file:./path/to/relative/file.org::*Headline')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'headline', value = 'Headline' }, result.target)
      assert.are.same('file', result.protocol)
    end)

    it('should return proper checks', function()
      local result = Url:new('file:./path/to/relative/file.org::*Headline')
      assert.is.True(result:is_file())

      assert.is.True(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.True(result:is_file_headline())

      assert.is.False(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.False(result:is_file_line_number())
      assert.is.False(result:is_plain())
      assert.is.False(result:is_id())

      assert.are.same('./path/to/relative/file.org', result:get_file())
      assert.are.same('Headline', result:get_headline())
    end)
  end)

  describe('Custom id url', function()
    it('should parse absolute url and custom id', function()
      local result = Url:new('/path/to/some/file.org::#some-custom-id')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'custom-id', value = 'some-custom-id' }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse relative url and custom id', function()
      local result = Url:new('./path/to/relative/file.org::#some-custom-id')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'custom-id', value = 'some-custom-id' }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse absolute url with protocol and custom id', function()
      local result = Url:new('file:/path/to/some/file.org::#some-custom-id')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'custom-id', value = 'some-custom-id' }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should parse relative url with protocol and custom id', function()
      local result = Url:new('file:./path/to/relative/file.org::#some-custom-id')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'custom-id', value = 'some-custom-id' }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should return proper checks', function()
      local result = Url:new('file:./path/to/relative/file.org::#some-custom-id')
      assert.is.True(result:is_file())
      assert.is.False(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.True(result:is_custom_id())
      assert.is.True(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.False(result:is_file_line_number())
      assert.is.False(result:is_plain())
      assert.is.False(result:is_id())

      assert.are.same('./path/to/relative/file.org', result:get_file())
      assert.are.same('some-custom-id', result:get_custom_id())
    end)
  end)

  describe('Line number url', function()
    it('should parse absolute url and line number', function()
      local result = Url:new('/path/to/some/file.org::125')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'line-number', value = 125 }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse relative url and line number', function()
      local result = Url:new('./path/to/relative/file.org::125')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'line-number', value = 125 }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse absolute url with protocol and line number', function()
      local result = Url:new('file:/path/to/some/file.org::125')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'line-number', value = 125 }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should parse relative url with protocol and line number', function()
      local result = Url:new('file:./path/to/relative/file.org::125')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'line-number', value = 125 }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should return proper checks', function()
      local result = Url:new('file:./path/to/relative/file.org::125')
      assert.is.True(result:is_file())
      assert.is.False(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.False(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.True(result:is_file_line_number())
      assert.is.False(result:is_plain())
      assert.is.False(result:is_id())

      assert.are.same('./path/to/relative/file.org', result:get_file())
      assert.are.same(125, result:get_line_number())
    end)
  end)

  describe('Legacy line number url', function()
    it('should parse absolute url and legacy line number', function()
      local result = Url:new('/path/to/some/file.org +125')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'line-number', value = 125 }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse relative url and legacy line number', function()
      local result = Url:new('./path/to/relative/file.org   +125')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'line-number', value = 125 }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse absolute url with protocol and legacy line number', function()
      local result = Url:new('file:/path/to/some/file.org +125')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'line-number', value = 125 }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should parse relative url with protocol and legacy line number', function()
      local result = Url:new('file:./path/to/relative/file.org +125')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'line-number', value = 125 }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should return proper checks', function()
      local result = Url:new('file:./path/to/relative/file.org::125')
      assert.is.True(result:is_file())
      assert.is.False(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.False(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.True(result:is_file_line_number())

      assert.is.False(result:is_plain())

      assert.is.False(result:is_id())

      assert.are.same('./path/to/relative/file.org', result:get_file())
      assert.are.same(125, result:get_line_number())
    end)
  end)

  describe('Unknown target file url', function()
    it('should parse absolute url and unknown target', function()
      local result = Url:new('/path/to/some/file.org::some target')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'unknown', value = 'some target' }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse relative url and plain target', function()
      local result = Url:new('./path/to/relative/file.org::some target')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'unknown', value = 'some target' }, result.target)
      assert.is.Nil(result.protocol)
    end)
    it('should parse absolute url with protocol and plain target', function()
      local result = Url:new('file:/path/to/some/file.org::some target')
      assert.are.same('/path/to/some/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'unknown', value = 'some target' }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should parse relative url with protocol and plain target', function()
      local result = Url:new('file:./path/to/relative/file.org::some target')
      assert.are.same('./path/to/relative/file.org', result.path)
      assert.are.same('file', result.path_type)
      assert.are.same({ type = 'unknown', value = 'some target' }, result.target)
      assert.are.same('file', result.protocol)
    end)
    it('should return proper checks', function()
      local result = Url:new('file:./path/to/relative/file.org::some target')
      assert.is.True(result:is_file())
      assert.is.False(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.False(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.False(result:is_file_line_number())

      assert.is.False(result:is_plain())

      assert.is.False(result:is_id())

      assert.are.same('./path/to/relative/file.org', result:get_file())
    end)
  end)

  describe('Internal headline url', function()
    it('should parse internal headline', function()
      local result = Url:new('*Some headline')
      assert.are.same('Some headline', result.path)
      assert.are.same('headline', result.path_type)
      assert.is.Nil(result.target)
      assert.is.Nil(result.protocol)
      assert.are.same('headline', result.path_type)
    end)

    it('should return proper checks', function()
      local result = Url:new('*Some headline')
      assert.is.False(result:is_file())
      assert.is.True(result:is_headline())
      assert.is.True(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.False(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.False(result:is_file_line_number())

      assert.is.False(result:is_plain())

      assert.is.False(result:is_id())

      assert.are.same('Some headline', result:get_headline())
    end)
  end)

  describe('Internal custom id url', function()
    it('should parse internal custom id', function()
      local result = Url:new('#some-custom-id')
      assert.are.same('some-custom-id', result.path)
      assert.are.same('custom-id', result.path_type)
      assert.is.Nil(result.target)
      assert.is.Nil(result.protocol)
      assert.are.same('custom-id', result.path_type)
    end)

    it('should return proper checks', function()
      local result = Url:new('#some-custom-id')
      assert.is.False(result:is_file())
      assert.is.False(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.True(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.True(result:is_internal_custom_id())

      assert.is.False(result:is_file_line_number())

      assert.is.False(result:is_plain())

      assert.is.False(result:is_id())

      assert.are.same('some-custom-id', result:get_custom_id())
    end)
  end)

  describe('Plain url', function()
    it('should parse plain url', function()
      local result = Url:new('something url')
      assert.are.same('something url', result.path)
      assert.are.same('plain', result.path_type)
      assert.is.Nil(result.target)
      assert.is.Nil(result.protocol)
      assert.are.same('plain', result.path_type)
    end)

    it('should return proper checks', function()
      local result = Url:new('something url')
      assert.is.False(result:is_file())
      assert.is.False(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.False(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.False(result:is_file_line_number())

      assert.is.True(result:is_plain())

      assert.is.False(result:is_id())

      assert.are.same('something url', result:get_plain())
    end)
  end)

  describe('Id url', function()
    it('should parse id as path', function()
      local result = Url:new('id:6f48b815-9d7a-413f-80b3-e52fb50f97d8')
      assert.are.same('6f48b815-9d7a-413f-80b3-e52fb50f97d8', result.path)
      assert.is.Nil(result.target)
      assert.are.same('id', result.protocol)
    end)

    it('should return proper checks', function()
      local result = Url:new('id:6f48b815-9d7a-413f-80b3-e52fb50f97d8')
      assert.is.False(result:is_file())
      assert.is.False(result:is_headline())
      assert.is.False(result:is_internal_headline())
      assert.is.False(result:is_file_headline())

      assert.is.False(result:is_custom_id())
      assert.is.False(result:is_file_custom_id())
      assert.is.False(result:is_internal_custom_id())

      assert.is.False(result:is_file_line_number())

      assert.is.False(result:is_plain())

      assert.is.True(result:is_id())

      assert.are.same('6f48b815-9d7a-413f-80b3-e52fb50f97d8', result:get_id())
    end)
  end)
end)
