local helpers = require('tests.plenary.helpers')
local Date = require('orgmode.objects.date')

describe('Date mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should increase the date by provided number of days (org_timestamp_up_day)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 21)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same('  DEADLINE: <2021-07-22 Thu 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 5\<S-UP>"]])
    assert.are.same('  DEADLINE: <2021-07-27 Tue 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease the date by provided number of days (org_timestamp_down_day)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 21)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<S-DOWN>"]])
    assert.are.same('  DEADLINE: <2021-07-20 Tue 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 5\<S-DOWN>"]])
    assert.are.same('  DEADLINE: <2021-07-15 Thu 22:02>', vim.fn.getline('.'))
  end)

  it('should increase year part of the date (org_timestamp_up)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 15)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2022-07-21 Thu 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2026-07-21 Tue 22:02>', vim.fn.getline('.'))
  end)

  it('should increase month part of the date (org_timestamp_up)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 20)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-08-21 Sat 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2021-12-21 Tue 22:02>', vim.fn.getline('.'))
  end)

  it('should increase day part of the date (org_timestamp_up)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 22)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-22 Thu 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-26 Mon 22:02>', vim.fn.getline('.'))
  end)

  it('should increase hour part of the date (org_timestamp_up)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 29)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 23:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-22 Thu 03:02>', vim.fn.getline('.'))
  end)

  it('should increase minute part of the date (org_timestamp_up)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 32)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:07>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:27>', vim.fn.getline('.'))
  end)

  it('should toggle active/inactive state of date (org_timestamp_up)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 13)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: [2021-07-21 Wed 22:02]', vim.fn.getline('.'))
    vim.fn.cursor(4, 34)
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease year part of the date (org_timestamp_down)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 15)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2020-07-21 Tue 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2016-07-21 Thu 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease month part of the date (org_timestamp_down)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 20)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-06-21 Mon 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2021-02-21 Sun 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease day part of the date (org_timestamp_down)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 22)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-20 Tue 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-16 Fri 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease hour part of the date (org_timestamp_down)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 29)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 21:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 17:02>', vim.fn.getline('.'))
  end)

  it('should decrease minute part of the date (org_timestamp_down)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 32)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 21:57>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 21:37>', vim.fn.getline('.'))
  end)

  it('should add/update deadline date for a headline (org_deadline)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
    })

    vim.fn.cursor(6, 1)
    -- Set to today
    vim.cmd('norm ,oid')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('   DEADLINE: <' .. Date.today():to_string() .. '>', vim.fn.getline(6))

    -- Increase by one day
    vim.fn.cursor(6, 16)
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same('   DEADLINE: <' .. Date.today():add({ day = 1 }):to_string() .. '>', vim.fn.getline(6))

    -- Update back to today
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,oid.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('   DEADLINE: <' .. Date.today():to_string() .. '>', vim.fn.getline(6))
  end)

  it('should add/update schedule date for a headline (org_schedule)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      '  DEADLINE: <2021-09-15 Wed 22:02>',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
    })

    vim.fn.cursor(6, 1)
    -- Set to today
    vim.cmd('norm ,ois')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same(
      '  DEADLINE: <2021-09-15 Wed 22:02> SCHEDULED: <' .. Date.today():to_string() .. '>',
      vim.fn.getline(6)
    )

    -- Increase by one day
    vim.fn.cursor(6, 51)
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same(
      '  DEADLINE: <2021-09-15 Wed 22:02> SCHEDULED: <' .. Date.today():add({ day = 1 }):to_string() .. '>',
      vim.fn.getline(6)
    )
    --
    -- Update back to today
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,ois.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same(
      '  DEADLINE: <2021-09-15 Wed 22:02> SCHEDULED: <' .. Date.today():to_string() .. '>',
      vim.fn.getline(6)
    )
  end)

  it('should insert plain timestamp under cursor (org_time_stamp)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '',
      '*** NEXT [#1] Level 3',
    })
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,oi.')
    vim.cmd([[exe "norm \<CR>"]])
    -- date inserted
    assert.are.same('<' .. Date.today():to_string() .. '>', vim.fn.getline(7))
    -- increase by 1 day
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same('<' .. Date.today():add({ day = 1 }):to_string() .. '>', vim.fn.getline(7))
    -- make sure it updated back to todays date by opening the calendar and pressing . to go to today's date
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,oi..')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('<' .. Date.today():to_string() .. '>', vim.fn.getline(7))
  end)

  it('should append an end date range when plain timestamp is added right after another date', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '<2021-09-16 Thu> ',
      '*** NEXT [#1] Level 3',
    })
    vim.fn.cursor(7, 17)
    vim.cmd('norm ,oi.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('<2021-09-16 Thu>--<' .. Date.today():to_string() .. '>', vim.fn.getline(7))
  end)

  it('should insert plain inactive timestamp under cursor (org_time_stamp)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '',
      '*** NEXT [#1] Level 3',
    })
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,oi!')
    vim.cmd([[exe "norm \<CR>"]])
    -- date inserted
    assert.are.same('[' .. Date.today():to_string() .. ']', vim.fn.getline(7))
    -- increase by 1 day
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same('[' .. Date.today():add({ day = 1 }):to_string() .. ']', vim.fn.getline(7))
    -- make sure it updated back to todays date by opening the calendar and pressing . to go to today's date
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,oi!.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('[' .. Date.today():to_string() .. ']', vim.fn.getline(7))
  end)

  it('should append an end date range when inactive plain timestamp is added right after another date', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '[2021-09-16 Thu] ',
      '*** NEXT [#1] Level 3',
    })
    vim.fn.cursor(7, 17)
    vim.cmd('norm ,oi!')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('[2021-09-16 Thu]--[' .. Date.today():to_string() .. ']', vim.fn.getline(7))
  end)
end)
