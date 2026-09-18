local OrgFile = require('orgmode.files.file')

describe('Memoize', function()
  ---@return OrgFile
  local new_file = function(content, filename)
    content = content or {}
    filename = filename or vim.fn.tempname() .. '.org'
    return OrgFile:new({ filename = filename, lines = content })
  end

  ---Number of per-node buckets held for a file. Bookkeeping keys are not
  ---buckets.
  ---@param file OrgFile
  local function buckets(file)
    local count = 0
    for key in pairs(file.memoize_cache or {}) do
      if not tostring(key):match('^__') then
        count = count + 1
      end
    end
    return count
  end

  local function collect()
    collectgarbage('collect')
    collectgarbage('collect')
  end

  local function create_weak_file()
    local weak = setmetatable({}, { __mode = 'v' })

    local file = new_file({ '* Headline 1', '  body' })
    weak.file = file
    file:get_headlines()
    -- On older Neovim versions the parser can survive long enough to keep a
    -- strong reference chain into the file object even though memoization does
    -- not. Clear the parser so the test only verifies memoize behavior.
    file.parser = nil
    file.root = nil

    assert.is_not_nil(weak.file)
    return weak
  end

  it('does not keep a file alive once nothing else references it', function()
    local weak = create_weak_file()

    -- Neovim can keep parser-related objects around for a few GC rounds.
    for _ = 1, 10 do
      if weak.file == nil then
        break
      end
      collect()
    end

    assert.is_nil(weak.file)
  end)

  it('does not accumulate buckets when the tree is replaced', function()
    local file = new_file({ '* Headline 1', '  body' })
    file:get_headlines()

    local baseline = buckets(file)

    -- Rewrite the body five times. The headline count never changes, so the
    -- number of live buckets must not change either.
    -- Dropping the parser forces a fresh tree on each round, which is what an
    -- edit in a loaded buffer does; without it the parser is reused and the
    -- node ids stay identical.
    for i = 1, 5 do
      file.parser = nil
      file:_update_lines({ '* Headline 1', '  body ' .. i })
      file:get_headlines()
    end

    assert.are.same(baseline, buckets(file))
  end)
end)
