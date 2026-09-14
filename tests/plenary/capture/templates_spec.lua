local Template = require('orgmode.capture.template')
local Date = require('orgmode.objects.date')
local helpers = require('tests.plenary.helpers')
local Input = require('orgmode.ui.input')
local Promise = require('orgmode.utils.promise')

describe('Capture template', function()
  it('should compile expression', function()
    ---Backup and restore the clipboard
    local clip_backup = vim.fn.getreg('+')
    vim.fn.setreg('+', 'test')
    local template = Template:new({
      template = '* TODO\n%<%Y-%m-%d>\n%t\n%T--%T\n%<%H:%M>\n%<%A>\n%x\n%(return string.format("hello %s", "world"))',
    })

    assert.are.same({
      '* TODO',
      os.date('%Y-%m-%d'),
      '<' .. os.date('%Y-%m-%d %a') .. '>',
      '<' .. os.date('%Y-%m-%d %a %H:%M') .. '>--<' .. os.date('%Y-%m-%d %a %H:%M') .. '>',
      os.date('%H:%M'),
      os.date('%A'),
      'test',
      'hello world',
    }, template:compile():wait())

    vim.fn.setreg('+', clip_backup)
  end)

  it('should escape the compiled content', function()
    ---Backup and restore the clipboard
    local clip_backup = vim.fn.getreg('+')
    vim.fn.setreg('+', 'nvim-orgmode%20is%20great!')
    local template = Template:new({
      template = '* TODO [[%x][]]\n',
    })

    assert.are.same({
      '* TODO [[nvim-orgmode%20is%20great!][]]',
      '',
    }, template:compile():wait())
    vim.fn.setreg('+', clip_backup)
  end)

  it('gets current date and time for datetree enabled with true', function()
    local template = Template:new({
      template = '* %?',
      datetree = true,
    })

    assert.are.same(Date.now():to_string(), template:get_datetree_opts().date:to_string())
  end)

  it('gets a proper date for datetree enabled as time prompt', function()
    local date = Date.today():subtract({ month = 2 })
    local template = Template:new({
      template = '* %?',
      datetree = {
        time_prompt = true,
        date = date,
      },
    })

    assert.are.same(date:to_string(), template:get_datetree_opts().date:to_string())
  end)

  it('should process custom compile hooks', function()
    local template = Template:new({
      template = '* This is a test {title} and {slug} in headline',
    })
    template:on_compile(function(content)
      content = content:gsub('{title}', 'Org Test')
      content = content:gsub('{slug}', 'org-test')
      return content
    end)
    assert.are.same({ '* This is a test Org Test and org-test in headline' }, template:compile():wait())
  end)

  it('should return nil if custom compile hooks return nil', function()
    local template = Template:new({
      template = '* This is a test {title} and {slug} in headline',
    })
    template:on_compile(function(content)
      content = content:gsub('{title}', 'Org Test')
      content = content:gsub('{slug}', 'org-test')
      return content
    end)
    template:on_compile(function()
      return nil
    end)
    assert.is.Nil(template:compile():wait())
  end)

  it('should prompt for single tag with %^g', function()
    helpers.with_var(Input, 'open', function(_prompt, _default, _completion)
      return Promise.resolve('mytag')
    end, function()
      local template = Template:new({
        template = '* TODO %^g',
      })
      assert.are.same({ '* TODO :mytag:' }, template:compile():wait())
    end)
  end)

  it('should prompt for multiple tags with %^G', function()
    helpers.with_var(Input, 'open', function(_prompt, _default, _completion)
      return Promise.resolve('tag1:tag2')
    end, function()
      local template = Template:new({
        template = '* TODO %^G',
      })
      assert.are.same({ '* TODO :tag1:tag2:' }, template:compile():wait())
    end)
  end)

  it('should prompt for restricted tags with %^{tag1|tag2}G', function()
    helpers.with_var(Input, 'open', function(_prompt, _default, _completion)
      return Promise.resolve('tag1')
    end, function()
      local template = Template:new({
        template = '* TODO %^{tag1|tag2}G',
      })
      assert.are.same({ '* TODO :tag1:' }, template:compile():wait())
    end)
  end)

  it('should not cancel capture when %^g input is empty', function()
    helpers.with_var(Input, 'open', function(_prompt, _default, _completion)
      return Promise.resolve('')
    end, function()
      local template = Template:new({
        template = '* TODO %^g',
      })
      assert.are.same({ '* TODO ' }, template:compile():wait())
    end)
  end)
  it('should complete %^g from target file tags only', function()
    local fixtures, org_files = helpers.create_agenda_files({
      {
        filename = 'target.org',
        content = {
          '#+FILETAGS: :target_file:',
          '* TODO target item :target_headline:',
        },
      },
      {
        filename = 'other.org',
        content = {
          '* TODO other item :other_headline:',
        },
      },
    })

    helpers.with_var(Input, 'open', function(_prompt, _default, completion)
      assert.are.same({ 'target_file', 'target_headline' }, completion(''))
      return Promise.resolve('target_headline')
    end, function()
      local template = Template:new({
        template = '* TODO %^g',
        target = fixtures['target.org'],
      })
      template.files = org_files
      assert.are.same({ '* TODO :target_headline:' }, template:compile():wait())
    end)
  end)

  it('should complete %^G from all loaded agenda file tags', function()
    local _, org_files = helpers.create_agenda_files({
      {
        filename = 'target.org',
        content = {
          '#+FILETAGS: :target_file:',
          '* TODO target item :target_headline:',
        },
      },
      {
        filename = 'other.org',
        content = {
          '* TODO other item :other_headline:',
        },
      },
    })

    helpers.with_var(Input, 'open', function(_prompt, _default, completion)
      assert.are.same({ 'other_headline', 'target_file', 'target_headline' }, completion(''))
      return Promise.resolve('target_headline:other_headline')
    end, function()
      local template = Template:new({
        template = '* TODO %^G',
      })
      template.files = org_files
      assert.are.same({ '* TODO :target_headline:other_headline:' }, template:compile():wait())
    end)
  end)
end)
