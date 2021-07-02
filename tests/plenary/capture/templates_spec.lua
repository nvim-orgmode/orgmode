local Templates = require('orgmode.capture.templates')

describe('Capture template', function()
  local templates = Templates:new()
  it('should compile expression', function()
    local result = templates:compile({
      template = '* TODO\n%<%Y-%m-%d>\n%t\n%T--%T\n%<%H:%M>\n%<%A>'
    })

    assert.are.same({
      '* TODO',
      os.date('%Y-%m-%d'),
      '<'..os.date('%Y-%m-%d %a')..'>',
      '<'..os.date('%Y-%m-%d %a %H:%M')..'>--<'..os.date('%Y-%m-%d %a %H:%M')..'>',
      os.date('%H:%M'),
      os.date('%A'),
    }, result)
  end)
end)
