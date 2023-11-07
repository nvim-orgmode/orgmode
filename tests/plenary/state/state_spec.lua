local utils = require('orgmode.utils')
local state = nil
local cache_path = vim.fs.normalize(vim.fn.stdpath('cache') .. '/org-cache.json', { expand_env = false })

describe('State', function()
  before_each(function()
    -- Ensure the cache file is removed before each run
    state = require('orgmode.state.state')
    vim.wait(50, function()
      return state._ctx.saved
    end, 10)
    state._ctx.saved = false
    state._ctx.loaded = false
    vim.fn.delete(cache_path, 'rf')
  end)

  after_each(function()
    state._ctx.saved = false
    state._ctx.loaded = false
    state = nil
    -- vim.fn.delete(cache_path, 'rf')
  end)

  it("should create a state file if it doesn't exist", function()
    -- Ensure the file doesn't exist
    vim.fn.delete(cache_path, 'rf')
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
    state:save()
    vim.wait(50, function()
      return state._ctx.saved
    end, 10)
    -- Wipe the variable and "unload" the State
    state.my_var = nil
    state._ctx.loaded = false

    -- Ensure the state can be loaded from the file now by ignoring the previous load
    state:load()
    -- wait until the state has been loaded
    vim.wait(50, function()
      return state._ctx.loaded
    end, 10)
    -- These should be the same after the wipe. We just loaded it back in from the state cache.
    assert.are.equal('hello world', state.my_var)
  end)

  it('should be able to self-heal from an invalid state file', function()
    local err = nil
    state.my_var = 'hello world'
    state:save():finally(function()
      vim.cmd.edit(cache_path)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { '[ invalid json!' })
      vim.cmd.write()
      state:load():catch(function(err)
        err = err
      end)
    end)
    vim.wait(50, function()
      return state._ctx.loaded
    end, 10)

    if err then
      error('Unable to self-heal from an invalid state! Error: ' .. vim.inspect(err_msg))
    end
  end)
end)
