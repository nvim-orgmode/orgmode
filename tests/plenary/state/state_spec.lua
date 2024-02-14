local utils = require('orgmode.utils')
---@type OrgState
local state = nil
local spy = require('luassert.spy')

describe('State', function()
  local cache_path = vim.fs.normalize(vim.fn.stdpath('cache') .. '/org-cache.json', { expand_env = false })

  before_each(function()
    -- Ensure the cache file is removed before each run
    state = require('orgmode.state.state')
    state:wipe()
    vim.fn.delete(cache_path, 'rf')
  end)

  it("should create a state file if it doesn't exist", function()
    local stat = vim.loop.fs_stat(cache_path)
    if stat then
      error('Cache file existed before it should! Ensure it is deleted before each test run!')
    end

    -- This creates the cache file on new instances of `State`
    state:load()

    -- wait until the state has been saved
    vim.wait(50, function()
      return state._ctx.saved
    end, 10)

    local stat, err, _ = vim.loop.fs_stat(cache_path)
    if not stat then
      error(err)
    end
  end)

  it('should save the cache file as valid json', function()
    local data = nil
    local read_f_err = nil
    state:save():next(function()
      utils
        .readfile(cache_path, { raw = true })
        :next(function(state_data)
          data = state_data
        end)
        :catch(function(err)
          read_f_err = err
        end)
    end)

    -- wait until the newly saved state file has been read
    vim.wait(50, function()
      return data ~= nil or read_f_err ~= nil
    end, 10)
    if read_f_err then
      error(read_f_err)
    end

    local success, decoded = pcall(vim.json.decode, data, {
      luanil = { object = true, array = true },
    })
    if not success then
      error('Cache file did not contain valid json after saving! Error: ' .. vim.inspect(decoded))
    end
  end)

  it('should be able to save and load state data', function()
    -- Set a variable into the state object
    state.my_var = 'hello world'
    -- Save the state
    state:save_sync()
    -- Wipe the variable and "unload" the State
    state.my_var = nil
    state._ctx.loaded = false

    -- Ensure the state can be loaded from the file now by ignoring the previous load
    state:load_sync()
    -- These should be the same after the wipe. We just loaded it back in from the state cache.
    assert.are.equal('hello world', state.my_var)
  end)

  it('should set the dirty state when a variable is set', function()
    -- By default it's dirty
    assert.is.True(state._ctx.dirty)
    state:save_sync()
    assert.is.False(state._ctx.dirty)

    state.my_var = 'hello world'
    assert.is.True(state._ctx.dirty)
    state:save_sync()
    assert.is.False(state._ctx.dirty)

    -- Ensure writefile is not called if state is not dirty
    local s = spy.on(utils, 'writefile')
    state:save_sync()
    assert.spy(s).was.called(0)

    -- Ensure writefile is not called if state was not changed
    state:save_sync()
    state.my_var = 'hello world'
    assert.spy(s).was.called(0)

    -- Ensure writefile is called if state prop was changed
    state.my_var = 'hello worlds'
    state:save_sync()
    assert.spy(s).was.called(1)

    s:revert()
  end)

  it('should be able to self-heal from an invalid state file', function()
    vim.fn.writefile({ '[ invalid json!' }, cache_path)

    -- Ensure we reload the state from its cache file (this should also "heal" the cache)
    state._ctx.loaded = false
    state._ctx.saved = false
    state:load_sync()
    vim.wait(500, function()
      return state._ctx.saved
    end)
    -- Wait a little longer to ensure the data is flushed into the cache
    vim.wait(100)

    -- Now attempt to read the file and check that it is, in fact, "healed"
    local cache_data = nil
    local read_f_err = nil
    utils
      .readfile(cache_path, { raw = true })
      :next(function(state_data)
        cache_data = state_data
      end)
      :catch(function(reject)
        read_f_err = reject
      end)
      :finally(function()
        read_file = true
      end)

    vim.wait(500, function()
      return cache_data ~= nil or read_f_err ~= nil
    end, 20)

    if read_f_err then
      error('Unable to read the healed state cache! Error: ' .. vim.inspect(read_f_err))
    end

    local success, decoded = pcall(vim.json.decode, cache_data, {
      luanil = { object = true, array = true },
    })

    if not success then
      error(
        'Unable to self-heal from an invalid state! Error: '
          .. vim.inspect(decoded)
          .. '\n\t-> Got cache content as '
          .. vim.inspect(cache_data)
      )
    end
  end)
end)
