local utils = require('orgmode.utils')
local state_mod = require('orgmode.state.state')
local cache_path = vim.fs.normalize(vim.fn.stdpath('cache') .. '/org-cache.json', { expand_env = false })

describe('State', function()
  before_each(function()
    -- Ensure the cache file is removed before each run
    vim.fn.delete(cache_path, 'rf')
  end)
  it("should create a state file if it doesn't exist", function()
    -- Ensure the file doesn't exist
    local err, stat = pcall(vim.loop.fs_stat, cache_path)
    if not err then
      error('Cache file existed before it should! Ensure it is deleted before each test run!')
    end

    -- This creates the cache file on new instances of `State`
    local state = state_mod()
    state:load():finally(function()
      ---@diagnostic disable-next-line: redefined-local
      local err, stat = pcall(vim.loop.fs_stat, cache_path)
      if err then
        if type(stat) == 'string' and stat:match([[^ENOENT.*]]) then
          error('Cache file did not exist')
        end
      end
    end)
  end)

  it('should save the cache file as valid json', function()
    local state = state_mod()
    state:save():finally(function()
      utils.readfile(cache_path, { raw = true }):next(function(cache_content)
        local err, err_msg = vim.json.decode(cache_content, {
          luanil = { object = true, array = true },
        })

        if err then
          error('Cache file did not contain valid json after saving! Error: ' .. vim.inspect(err_msg))
        end
      end)
    end)
  end)

  it('should be able to save and load state data', function()
    local state = state_mod()

    -- Set a variable into the state object
    state.my_var = 'hello world'
    state:save():finally(function()
      -- "Wipe" the variable
      state.my_var = nil
      state:load():finally(function()
        -- These should be the same after the wipe. We just loaded it back in from the state cache.
        assert.are.equal(state.my_var, 'hello world')
      end)
    end)
  end)
end)
