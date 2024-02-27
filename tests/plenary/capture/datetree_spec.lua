---@diagnostic disable: invisible
local helpers = require('tests.plenary.helpers')
local Template = require('orgmode.capture.template')
local Date = require('orgmode.objects.date')

describe('Datetree', function()
  local org = require('orgmode')

  describe('When not reversed', function()
    ---@param date OrgDate
    ---@return OrgProcessCaptureOpts
    local get_template = function(date, content)
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile(content or {}, filename)
      return {
        destination_file = org.files:get(filename),
        template = Template:new({
          target = filename,
          template = '* %?',
          datetree = {
            time_prompt = true,
            date = date,
          },
        }),
      }
    end
    describe('When datetree does not exist', function()
      it('creates a whole datetree', function()
        local date = Date.today()
        local opts = get_template(date)
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a whole datetree before an existing future date', function()
        local in_two_years = Date.today():add({ year = 2 })
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. in_two_years:format('%Y'),
          '** ' .. in_two_years:format('%Y-%m %B'),
          '*** ' .. in_two_years:format('%Y-%m-%d %A'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '* ' .. in_two_years:format('%Y'),
          '** ' .. in_two_years:format('%Y-%m %B'),
          '*** ' .. in_two_years:format('%Y-%m-%d %A'),
        }, opts.destination_file.lines)
      end)

      it('creates a whole datetree after a past date', function()
        local two_years_ago = Date.today():subtract({ year = 2 })
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. two_years_ago:format('%Y'),
          '** ' .. two_years_ago:format('%Y-%m %B'),
          '*** ' .. two_years_ago:format('%Y-%m-%d %A'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. two_years_ago:format('%Y'),
          '** ' .. two_years_ago:format('%Y-%m %B'),
          '*** ' .. two_years_ago:format('%Y-%m-%d %A'),
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a whole datetree between a past and future date', function()
        local two_years_ago = Date.today():subtract({ year = 2 })
        local in_two_years = Date.today():add({ year = 2 })
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. two_years_ago:format('%Y'),
          '** ' .. two_years_ago:format('%Y-%m %B'),
          '*** ' .. two_years_ago:format('%Y-%m-%d %A'),
          '* ' .. in_two_years:format('%Y'),
          '** ' .. in_two_years:format('%Y-%m %B'),
          '*** ' .. in_two_years:format('%Y-%m-%d %A'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. two_years_ago:format('%Y'),
          '** ' .. two_years_ago:format('%Y-%m %B'),
          '*** ' .. two_years_ago:format('%Y-%m-%d %A'),
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '* ' .. in_two_years:format('%Y'),
          '** ' .. in_two_years:format('%Y-%m %B'),
          '*** ' .. in_two_years:format('%Y-%m-%d %A'),
        }, opts.destination_file.lines)
      end)
    end)

    describe('When only datetree year exist', function()
      it('creates a month datetree', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a month datetree before an existing future month', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:add({ month = 2 }):format('%Y-%m %B'),
          '*** ' .. date:add({ month = 2 }):format('%Y-%m-%d %A'),
          '**** future month note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '** ' .. date:add({ month = 2 }):format('%Y-%m %B'),
          '*** ' .. date:add({ month = 2 }):format('%Y-%m-%d %A'),
          '**** future month note',
        }, opts.destination_file.lines)
      end)

      it('creates a month datetree after a past month', function()
        local date = Date.from_string('2024-05-10')
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:subtract({ month = 1 }):format('%Y-%m %B'),
          '*** ' .. date:subtract({ month = 1 }):format('%Y-%m-%d %A'),
          '**** one month ago',
          '** ' .. date:subtract({ month = 2 }):format('%Y-%m %B'),
          '*** ' .. date:subtract({ month = 2 }):format('%Y-%m-%d %A'),
          '**** two months ago',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:subtract({ month = 1 }):format('%Y-%m %B'),
          '*** ' .. date:subtract({ month = 1 }):format('%Y-%m-%d %A'),
          '**** one month ago',
          '** ' .. date:subtract({ month = 2 }):format('%Y-%m %B'),
          '*** ' .. date:subtract({ month = 2 }):format('%Y-%m-%d %A'),
          '**** two months ago',
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a month datetree between a past and future month', function()
        local date = Date.from_string('2023-05-05')
        local two_months_ago = date:subtract({ month = 2 })
        local in_two_months = date:add({ month = 2 })
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. two_months_ago:format('%Y-%m %B'),
          '*** ' .. two_months_ago:format('%Y-%m-%d %A'),
          '**** two months ago',
          '** ' .. in_two_months:format('%Y-%m %B'),
          '*** ' .. in_two_months:format('%Y-%m-%d %A'),
          '**** in two months',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. two_months_ago:format('%Y-%m %B'),
          '*** ' .. two_months_ago:format('%Y-%m-%d %A'),
          '**** two months ago',
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '** ' .. in_two_months:format('%Y-%m %B'),
          '*** ' .. in_two_months:format('%Y-%m-%d %A'),
          '**** in two months',
        }, opts.destination_file.lines)
      end)
    end)

    describe('When only datetree year and month exist', function()
      it('creates a day datetree', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a day datetree before an existing future day', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:add({ day = 2 }):format('%Y-%m-%d %A'),
          '**** future day note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '*** ' .. date:add({ day = 2 }):format('%Y-%m-%d %A'),
          '**** future day note',
        }, opts.destination_file.lines)
      end)

      it('creates a day datetree after a past day', function()
        local date = Date.from_string('2024-05-10')
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:subtract({ day = 2 }):format('%Y-%m-%d %A'),
          '**** past day note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:subtract({ day = 2 }):format('%Y-%m-%d %A'),
          '**** past day note',
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a day datetree between a past and future day', function()
        local date = Date.from_string('2023-05-05')
        local two_months_ago = date:subtract({ month = 2 })
        local in_two_months = date:add({ month = 2 })
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:subtract({ day = 2 }):format('%Y-%m-%d %A'),
          '**** past day note',
          '*** ' .. date:add({ day = 5 }):format('%Y-%m-%d %A'),
          '**** future day note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:subtract({ day = 2 }):format('%Y-%m-%d %A'),
          '**** past day note',
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '*** ' .. date:add({ day = 5 }):format('%Y-%m-%d %A'),
          '**** future day note',
        }, opts.destination_file.lines)
      end)
    end)

    describe('When whole datetree exists', function()
      it('it appends to the day tree', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** existing day note',
          '**** existing day second note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** existing day note',
          '**** existing day second note',
          '**** baz',
        }, opts.destination_file.lines)
      end)
    end)
  end)

  describe('When reversed', function()
    ---@param date OrgDate
    ---@return OrgProcessCaptureOpts
    local get_template = function(date, content)
      local filename = vim.fn.tempname() .. '.org'
      vim.fn.writefile(content or {}, filename)
      return {
        destination_file = org.files:get(filename),
        template = Template:new({
          target = filename,
          template = '* %?',
          datetree = {
            time_prompt = true,
            date = date,
            reversed = true,
          },
        }),
      }
    end
    describe('When datetree does not exist', function()
      it('creates a whole datetree', function()
        local date = Date.today()
        local opts = get_template(date)
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a whole datetree before an existing past date', function()
        local two_years_ago = Date.today():subtract({ year = 2 })
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. two_years_ago:format('%Y'),
          '** ' .. two_years_ago:format('%Y-%m %B'),
          '*** ' .. two_years_ago:format('%Y-%m-%d %A'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '* ' .. two_years_ago:format('%Y'),
          '** ' .. two_years_ago:format('%Y-%m %B'),
          '*** ' .. two_years_ago:format('%Y-%m-%d %A'),
        }, opts.destination_file.lines)
      end)

      it('creates a whole datetree after a future date', function()
        local in_two_years = Date.today():add({ year = 2 })
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. in_two_years:format('%Y'),
          '** ' .. in_two_years:format('%Y-%m %B'),
          '*** ' .. in_two_years:format('%Y-%m-%d %A'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. in_two_years:format('%Y'),
          '** ' .. in_two_years:format('%Y-%m %B'),
          '*** ' .. in_two_years:format('%Y-%m-%d %A'),
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a whole datetree between a past and future date', function()
        local two_years_ago = Date.today():subtract({ year = 2 })
        local in_two_years = Date.today():add({ year = 2 })
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. in_two_years:format('%Y'),
          '** ' .. in_two_years:format('%Y-%m %B'),
          '*** ' .. in_two_years:format('%Y-%m-%d %A'),
          '* ' .. two_years_ago:format('%Y'),
          '** ' .. two_years_ago:format('%Y-%m %B'),
          '*** ' .. two_years_ago:format('%Y-%m-%d %A'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. in_two_years:format('%Y'),
          '** ' .. in_two_years:format('%Y-%m %B'),
          '*** ' .. in_two_years:format('%Y-%m-%d %A'),
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '* ' .. two_years_ago:format('%Y'),
          '** ' .. two_years_ago:format('%Y-%m %B'),
          '*** ' .. two_years_ago:format('%Y-%m-%d %A'),
        }, opts.destination_file.lines)
      end)
    end)

    describe('When only datetree year exist', function()
      it('creates a month datetree', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a month datetree after an existing future month', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:add({ month = 2 }):format('%Y-%m %B'),
          '*** ' .. date:add({ month = 2 }):format('%Y-%m-%d %A'),
          '**** future month note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:add({ month = 2 }):format('%Y-%m %B'),
          '*** ' .. date:add({ month = 2 }):format('%Y-%m-%d %A'),
          '**** future month note',
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a month datetree before an existing past month', function()
        local date = Date.from_string('2024-05-10')
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:subtract({ month = 1 }):format('%Y-%m %B'),
          '*** ' .. date:subtract({ month = 1 }):format('%Y-%m-%d %A'),
          '**** one month ago',
          '** ' .. date:subtract({ month = 2 }):format('%Y-%m %B'),
          '*** ' .. date:subtract({ month = 2 }):format('%Y-%m-%d %A'),
          '**** two months ago',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '** ' .. date:subtract({ month = 1 }):format('%Y-%m %B'),
          '*** ' .. date:subtract({ month = 1 }):format('%Y-%m-%d %A'),
          '**** one month ago',
          '** ' .. date:subtract({ month = 2 }):format('%Y-%m %B'),
          '*** ' .. date:subtract({ month = 2 }):format('%Y-%m-%d %A'),
          '**** two months ago',
        }, opts.destination_file.lines)
      end)

      it('creates a month datetree between a past and future month', function()
        local date = Date.from_string('2023-05-05')
        local two_months_ago = date:subtract({ month = 2 })
        local in_two_months = date:add({ month = 2 })
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. in_two_months:format('%Y-%m %B'),
          '*** ' .. in_two_months:format('%Y-%m-%d %A'),
          '**** in two months',
          '** ' .. two_months_ago:format('%Y-%m %B'),
          '*** ' .. two_months_ago:format('%Y-%m-%d %A'),
          '**** two months ago',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. in_two_months:format('%Y-%m %B'),
          '*** ' .. in_two_months:format('%Y-%m-%d %A'),
          '**** in two months',
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '** ' .. two_months_ago:format('%Y-%m %B'),
          '*** ' .. two_months_ago:format('%Y-%m-%d %A'),
          '**** two months ago',
        }, opts.destination_file.lines)
      end)
    end)

    describe('When only datetree year and month exist', function()
      it('creates a day datetree', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a day datetree after an existing future day', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:add({ day = 2 }):format('%Y-%m-%d %A'),
          '**** future day note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:add({ day = 2 }):format('%Y-%m-%d %A'),
          '**** future day note',
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
        }, opts.destination_file.lines)
      end)

      it('creates a day datetree before a past day', function()
        local date = Date.from_string('2024-05-10')
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:subtract({ day = 2 }):format('%Y-%m-%d %A'),
          '**** past day note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '*** ' .. date:subtract({ day = 2 }):format('%Y-%m-%d %A'),
          '**** past day note',
        }, opts.destination_file.lines)
      end)

      it('creates a day datetree between a past and future day', function()
        local date = Date.from_string('2023-05-05')
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:add({ day = 5 }):format('%Y-%m-%d %A'),
          '**** future day note',
          '*** ' .. date:subtract({ day = 2 }):format('%Y-%m-%d %A'),
          '**** past day note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:add({ day = 5 }):format('%Y-%m-%d %A'),
          '**** future day note',
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '*** ' .. date:subtract({ day = 2 }):format('%Y-%m-%d %A'),
          '**** past day note',
        }, opts.destination_file.lines)
      end)
    end)

    describe('When whole datetree exists', function()
      it('it appends to the start of day tree', function()
        local date = Date.today()
        local opts = get_template(date, {
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** existing day note',
          '**** existing day second note',
        })
        local capture_lines = { '* baz' }
        local capture_file = helpers.create_file_instance(capture_lines)
        opts.source_file = capture_file
        opts.source_headline = capture_file:get_headlines()[1]

        org.capture:_refile_from_capture_buffer(opts)
        opts.destination_file:reload_sync()
        assert.are.same({
          '* ' .. date:format('%Y'),
          '** ' .. date:format('%Y-%m %B'),
          '*** ' .. date:format('%Y-%m-%d %A'),
          '**** baz',
          '**** existing day note',
          '**** existing day second note',
        }, opts.destination_file.lines)
      end)
    end)
  end)
end)
