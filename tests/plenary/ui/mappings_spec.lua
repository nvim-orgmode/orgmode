local helpers = require('tests.plenary.ui.helpers')
local org = require('orgmode')
local config = require('orgmode.config')
local Files = require('orgmode.parser.files')
local Date = require('orgmode.objects.date')

describe('Mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should toggle archive tag on headline (org_toggle_archive_tag)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    })
    assert.are.same('* TODO Test orgmode', vim.fn.getline(3))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oA]])
    assert.are.same(
      '* TODO Test orgmode                                                    :ARCHIVE:',
      vim.fn.getline(3)
    )
  end)

  it('should add/update deadline date for a headline (org_deadline)', function()
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    vim.cmd('norm ,oi..')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('<' .. Date.today():to_string() .. '>', vim.fn.getline(7))
  end)

  it('should append an end date range when plain timestamp is added right after another date', function()
    helpers.load_file_content({
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
    assert.are.same('<2021-09-16 Thu>--<' .. Date.today():to_string() .. '> ', vim.fn.getline(7))
  end)

  it('should insert plain inactive timestamp under cursor (org_time_stamp)', function()
    helpers.load_file_content({
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
    vim.cmd('norm ,oi!.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('[' .. Date.today():to_string() .. ']', vim.fn.getline(7))
  end)

  it('should append an end date range when inactive plain timestamp is added right after another date', function()
    helpers.load_file_content({
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
    assert.are.same('[2021-09-16 Thu]--[' .. Date.today():to_string() .. '] ', vim.fn.getline(7))
  end)

  it('should increase the priority of the current headline', function()
    helpers.load_file_content({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ciR')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should decrease the priority of the current headline', function()
    helpers.load_file_content({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm cir')
    assert.are.same('* TODO [#C] Test orgmode', vim.fn.getline(1))
  end)

  it('should set the priority based on the input key', function()
    helpers.load_file_content({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should remove the priority if <Space> is pressed', function()
    helpers.load_file_content({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o, \r')
    assert.are.same('* TODO Test orgmode', vim.fn.getline(1))
  end)

  it('should add a priority if the item does not already have one', function()
    helpers.load_file_content({
      '* TODO Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should add a priority if the item has no todo keyword', function()
    helpers.load_file_content({
      '* Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should refile to headline that matches name exactly', function()
    local destination_file = helpers.load_file_content({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.load_file_content({
      '* to be refiled',
      '* not to be refiled',
    })

    source_file = Files.get_current_file()
    local item = source_file:get_closest_headline()
    org.instance().capture:refile_to_headline(destination_file, source_file:get_headline_lines(item), item, 'foo')
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foobar',
      '* baz',
      '** foo',
      '*** to be refiled',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)

  it('should refile to headline and properly demote', function()
    local destination_file = helpers.load_file_content({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.load_file_content({
      '* to be refiled',
      '* not to be refiled',
    })

    source_file = Files.get_current_file()
    local item = source_file:get_closest_headline()
    org.instance().capture:refile_to_headline(destination_file, source_file:get_headline_lines(item), item, 'foobar')
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foobar',
      '** to be refiled',
      '* baz',
      '** foo',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)

  it('should refile to headline and properly promote', function()
    local destination_file = helpers.load_file_content({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.load_file_content({
      '**** to be refiled',
      '* not to be refiled',
    })

    source_file = Files.get_current_file()
    local item = source_file:get_closest_headline()
    org.instance().capture:refile_to_headline(destination_file, source_file:get_headline_lines(item), item, 'foobar')
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foobar',
      '** to be refiled',
      '* baz',
      '** foo',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)

  it('should update the checklist cookies on a headline', function()
    helpers.load_file_content({
      '* Test orgmode [/]',
      '- [ ] checkbox item',
      '- [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('* Test orgmode [1/2]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies on a parent list', function()
    helpers.load_file_content({
      '- Test orgmode [/]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- Test orgmode [1/2]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies with a percentage within a headline', function()
    helpers.load_file_content({
      '* Test orgmode [%]',
      '- [ ] checkbox item',
      '- [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('* Test orgmode [50%]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies with a percentage within a nested list', function()
    helpers.load_file_content({
      '- Test orgmode [%]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- Test orgmode [33%]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies with when the cookie is not the first entry', function()
    helpers.load_file_content({
      '- Test orgmode',
      '- listitem with cookie [%]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(3, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- listitem with cookie [33%]', vim.fn.getline(2))
  end)

  it('should update the checklist cookies with when there are more than 9 items', function()
    helpers.load_file_content({
      '- Test orgmode [0/10]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(3, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- Test orgmode [1/10]', vim.fn.getline(1))
  end)

  it('should update nested cookies and checkboxes', function()
    helpers.load_file_content({
      '- [ ] Test orgmode [/]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item [/]',
      '    - [ ] checkbox item',
      '    - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same({
      '- [ ] Test orgmode [0/3]',
      '  - [ ] checkbox item',
      '  - [-] checkbox item [1/2]',
      '    - [X] checkbox item',
      '    - [ ] checkbox item',
      '  - [ ] checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))
    vim.fn.cursor(5, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same({
      '- [-] Test orgmode [1/3]',
      '  - [ ] checkbox item',
      '  - [X] checkbox item [2/2]',
      '    - [X] checkbox item',
      '    - [X] checkbox item',
      '  - [ ] checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))
  end)

  it('should update headline cookies when updating checkboxes', function()
    helpers.load_file_content({
      '* Test orgmode [/]',
      '- [ ] checkbox item',
      '- [-] checkbox item [1/2]',
      '  - [ ] checkbox item',
      '  - [X] checkbox item',
      '- [ ] checkbox item',
    })
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same({
      '* Test orgmode [1/3]',
      '- [ ] checkbox item',
      '- [X] checkbox item [2/2]',
      '  - [X] checkbox item',
      '  - [X] checkbox item',
      '- [ ] checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))
  end)

  it('should follow link to given headline in given org file', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** target headline',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    vim.cmd([[norm w]])
    helpers.load_file_content({
      string.format('This link should lead to [[file:%s::*target headline][target]]', target_path),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** target headline', vim.api.nvim_get_current_line())
  end)

  it('should follow link to headline of given custom_id in given org file', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** headline of target custom_id',
      '   :PROPERTIES:',
      '   :CUSTOM_ID: target',
      '   :END:',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    vim.cmd([[norm w]])
    helpers.load_file_content({
      string.format('This link should lead to [[file:%s::#target][target]]', target_path),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of target custom_id', vim.api.nvim_get_current_line())
  end)

  it('should follow link to headline of given custom_id in given org file', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      '  an [[target][internal link]]',
      '  - some',
      '  - boiler',
      '  - plate',
      '** headline of a deticated anchor',
      '   - more',
      '   - boiler',
      '   - plate <<target>>',
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(2, 30)
    assert.is.same('  an [[target][internal link]]', vim.api.nvim_get_current_line())
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of a deticated anchor', vim.api.nvim_get_current_line())
  end)

  it('should respect custom  mapping prefix', function()
    config:extend({
      mappings = {
        prefix = '<Leader>f',
      },
    })

    helpers.load_file_content({
      '* DONE top level todo :WORK:',
      'content for top level todo',
    })
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 2, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,fit]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '',
      '* TODO ',
    }, vim.api.nvim_buf_get_lines(0, 0, 4, false))
  end)
end)
