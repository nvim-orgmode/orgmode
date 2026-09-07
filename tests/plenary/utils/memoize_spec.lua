local OrgFile = require('orgmode.files.file')

describe('Memoize', function()
  ---@return OrgFile
  local new_file = function(content, filename)
    content = content or {}
    filename = filename or vim.fn.tempname() .. '.org'
    return OrgFile:new({ filename = filename, lines = content })
  end

  local function collect()
    collectgarbage('collect')
    collectgarbage('collect')
  end

  it('does not keep a file alive once nothing else references it', function()
    local weak = setmetatable({}, { __mode = 'v' })

    do
      local file = new_file({ '* Headline 1', '  body' })
      weak.file = file
      file:get_headlines()
      assert.is_not_nil(weak.file)
    end

    collect()

    assert.is_nil(weak.file)
  end)
end)
