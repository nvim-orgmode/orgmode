local helpers = require('tests.plenary.ui.helpers')

describe('Date mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should increase the date by provided number of days (org_timestamp_up_day)', function()
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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

end)
