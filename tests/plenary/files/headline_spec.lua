local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

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

  describe('use_property_inheritance', function()
    local file = helpers.create_file_instance({
      '#+CATEGORY: file_category',
      '* Headline 1',
      ':PROPERTIES:',
      ':DIR: some/dir/',
      ':THING: 0',
      ':COLUMNS:',
      ':END:',
      '** Headline 2',
      '   some body text',
    }, 'category.org')
    after_each(function()
      config:extend({ org_use_property_inheritance = false })
    end)
    it('is false by default', function()
      assert.is.Nil(file:get_headlines()[2]:get_property('dir'))
    end)
    it('is active if true', function()
      config:extend({ org_use_property_inheritance = true })
      assert.are.same('some/dir/', file:get_headlines()[2]:get_property('dir'))
      assert.are.same('0', file:get_headlines()[2]:get_property('thing'))
    end)
    it('is selective if a list', function()
      config:extend({ org_use_property_inheritance = { 'dir' } })
      assert.are.same('some/dir/', file:get_headlines()[2]:get_property('dir'))
      assert.is.Nil(file:get_headlines()[2]:get_property('thing'))
    end)
    it('is selective if a regex', function()
      config:extend({ org_use_property_inheritance = '^di.$' })
      assert.are.same('some/dir/', file:get_headlines()[2]:get_property('dir'))
      assert.is.Nil(file:get_headlines()[2]:get_property('thing'))
    end)
    it('can be overridden with true', function()
      assert.is.Nil(file:get_headlines()[2]:get_property('dir'))
      assert.are.same('some/dir/', file:get_headlines()[2]:get_property('dir', true))
    end)
    it('can be overridden with false', function()
      config:extend({ org_use_property_inheritance = true })
      assert.are.same('some/dir/', file:get_headlines()[2]:get_property('dir'))
      assert.is.Nil(file:get_headlines()[2]:get_property('dir', false))
    end)
    it('does not affect get_own_properties', function()
      config:extend({ org_use_property_inheritance = true })
      file.metadata.mtime = file.metadata.mtime + 1 -- invalidate cache
      assert.are.same({}, file:get_headlines()[2]:get_own_properties())
    end)
    it('affects get_properties', function()
      config:extend({ org_use_property_inheritance = true })
      file.metadata.mtime = file.metadata.mtime + 1 -- invalidate cache
      local expected = { dir = 'some/dir/', thing = '0', columns = '' }
      assert.are.same(expected, file:get_headlines()[2]:get_properties())
    end)
    it('makes get_properties selective if a list', function()
      config:extend({ org_use_property_inheritance = { 'dir' } })
      file.metadata.mtime = file.metadata.mtime + 1 -- invalidate cache
      local expected = { dir = 'some/dir/' }
      assert.are.same(expected, file:get_headlines()[2]:get_properties())
    end)
    it('makes get_properties selective if a regex', function()
      config:extend({ org_use_property_inheritance = '^th...$' })
      file.metadata.mtime = file.metadata.mtime + 1 -- invalidate cache
      local expected = { thing = '0' }
      assert.are.same(expected, file:get_headlines()[2]:get_properties())
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

  describe('tags', function()
    ---@type OrgFile
    local file
    local orig_tags_column

    before_each(function()
      -- Put tags flush to headlines for shorter tests.
      if not orig_tags_column then
        orig_tags_column = config.org_tags_column
      end
      config:extend({ org_tags_column = 0 })
      -- Reinitialize test file to same state.
      if not file then
        file = helpers.load_file(vim.fn.tempname() .. '.org')
      end
      local bufnr = file:get_valid_bufnr()
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, {
        '* Headline 1',
        '* Headline 2 :other:',
        '* Headline 3 :other:more:ARCHIVE:',
      })
      file:reload_sync()
    end)

    after_each(function()
      config:extend({ org_tags_column = orig_tags_column })
    end)

    describe('toggling', function()
      it('adds a tag where there is none', function()
        file:get_headlines()[1]:toggle_tag('ARCHIVE')
        local expected = {
          '* Headline 1 :ARCHIVE:',
          '* Headline 2 :other:',
          '* Headline 3 :other:more:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)

      it('adds a tag if another already exists', function()
        file:get_headlines()[2]:toggle_tag('ARCHIVE')
        local expected = {
          '* Headline 1',
          '* Headline 2 :other:ARCHIVE:',
          '* Headline 3 :other:more:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)

      it('removes an existing tag', function()
        file:get_headlines()[2]:toggle_tag('other')
        local expected = {
          '* Headline 1',
          '* Headline 2',
          '* Headline 3 :other:more:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)

      it('keeps other tags when removing one', function()
        file:get_headlines()[3]:toggle_tag('more')
        local expected = {
          '* Headline 1',
          '* Headline 2 :other:',
          '* Headline 3 :other:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)
    end)

    describe('addition', function()
      it('adds a tag where there is none', function()
        file:get_headlines()[1]:add_tag('ARCHIVE')
        local expected = {
          '* Headline 1 :ARCHIVE:',
          '* Headline 2 :other:',
          '* Headline 3 :other:more:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)

      it('adds a tag if another already exists', function()
        file:get_headlines()[2]:add_tag('ARCHIVE')
        local expected = {
          '* Headline 1',
          '* Headline 2 :other:ARCHIVE:',
          '* Headline 3 :other:more:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)

      it('does not add the same tag twice', function()
        file:get_headlines()[2]:add_tag('other')
        local expected = {
          '* Headline 1',
          '* Headline 2 :other:',
          '* Headline 3 :other:more:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)
    end)

    describe('removal', function()
      it('removes an existing tag', function()
        file:get_headlines()[2]:remove_tag('other')
        local expected = {
          '* Headline 1',
          '* Headline 2',
          '* Headline 3 :other:more:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)

      it('keeps other tags when removing one', function()
        file:get_headlines()[3]:remove_tag('more')
        local expected = {
          '* Headline 1',
          '* Headline 2 :other:',
          '* Headline 3 :other:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)

      it('does nothing when removing a non-existent tag', function()
        file:get_headlines()[1]:remove_tag('other')
        local expected = {
          '* Headline 1',
          '* Headline 2 :other:',
          '* Headline 3 :other:more:ARCHIVE:',
        }
        assert.are.same(expected, file:reload_sync().lines)
      end)
    end)
  end)
end)
