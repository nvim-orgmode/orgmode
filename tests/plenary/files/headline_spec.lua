local helpers = require('tests.plenary.helpers')

describe('Headline', function()
  describe('get_category', function()
    it('should get category from file name', function()
      local file = helpers.create_file_instance({
        '* Headline 1',
        '* Headline 2',
      }, 'category.org')

      assert.are.same('category', file:get_headlines()[1]:get_category())
    end)

    it('should get category from category directive in file', function()
      local file = helpers.create_file_instance({
        '#+CATEGORY: file_category',
        '* Headline 1',
        '* Headline 2',
      }, 'category.org')
      file:reload_sync()

      assert.are.same('file_category', file:get_headlines()[1]:get_category())
    end)

    it('should get category from parent headline category prop', function()
      local file = helpers.create_file_instance({
        '#+CATEGORY: file_category',
        '* Headline 1',
        ':PROPERTIES:',
        ':CATEGORY: headline_category',
        ':END:',
        '** Headline 2',
      }, 'category.org')
      file:reload_sync()

      assert.are.same('headline_category', file:get_headlines()[2]:get_category())
    end)

    it('should get category from own category prop', function()
      local file = helpers.create_file_instance({
        '#+CATEGORY: file_category',
        '* Headline 1',
        ':PROPERTIES:',
        ':CATEGORY: headline_category',
        ':END:',
        '** Headline 2',
        ':PROPERTIES:',
        ':CATEGORY: headline_2_category',
        ':END:',
      }, 'category.org')
      file:reload_sync()

      assert.are.same('headline_2_category', file:get_headlines()[2]:get_category())
    end)
  end)
end)
