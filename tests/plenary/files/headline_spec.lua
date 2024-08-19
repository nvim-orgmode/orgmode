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

  describe('get_all_dates', function()
    it('should properly parse dates from the headline and body', function()
      local file = helpers.create_file({
        '* TODO testing <2024-08-17 Sat>',
        'DEADLINE: <2024-08-19 Mon>',
        '* stuff <2024-01-17 Wed>',
        '  <2024-02-17 Sat>',
        '  <2024-03-18 Sun>',
      })

      local assert_range = function(date, expected_range)
        assert.are.same(expected_range[1], date.range.start_line, 'Start line is not matching')
        assert.are.same(expected_range[2], date.range.start_col, 'Start col is not matching')
        assert.are.same(expected_range[3], date.range.end_line, 'End line is not matching')
        assert.are.same(expected_range[4], date.range.end_col, 'End col is not matching')
      end

      local first_headline_dates = file:get_headlines()[1]:get_all_dates()
      assert.are.same(2, #first_headline_dates)
      assert_range(first_headline_dates[1], { 2, 11, 2, 26 })
      assert_range(first_headline_dates[2], { 1, 16, 1, 31 })

      local second_headline_dates = file:get_headlines()[2]:get_all_dates()
      assert.are.same(3, #second_headline_dates)
      -- First date in the list is is always a plan date
      assert_range(second_headline_dates[1], { 4, 3, 4, 18 })
      assert_range(second_headline_dates[2], { 3, 9, 3, 24 })
      assert_range(second_headline_dates[3], { 5, 3, 5, 18 })
    end)
  end)
end)
