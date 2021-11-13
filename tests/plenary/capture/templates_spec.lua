local Templates = require('orgmode.capture.templates')

describe('Capture template', function()
  local templates = Templates:new()
  it('should compile expression', function()
    ---Backup and restore the clipboard
    local clip_backup = vim.fn.getreg('+')
    vim.fn.setreg('+', 'test')
    local result = templates:compile({
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
    }, result)

    vim.fn.setreg('+', clip_backup)
  end)
end)
