local orgmode = require('orgmode')
local OrgFiles = require('orgmode.files')

local fixtures = vim.fn.getcwd() .. '/tests/plenary/fixtures/*'

describe('OrgFiles load', function()
  it('should not block when load is called while loading is in progress', function()
    local files = OrgFiles:new({ paths = fixtures })
    files:load()
    assert.are.same('loading', files.load_state)

    files:load()
    assert.are.same('loading', files.load_state)

    files:ensure_loaded()
    assert.are.same('loaded', files.load_state)
  end)

  it('should load the agenda files in the background on init', function()
    local org = orgmode.setup({
      org_agenda_files = fixtures,
    })
    org:init()
    assert.are.same('loading', org.files.load_state)

    org.files:ensure_loaded()
    assert.are.same('loaded', org.files.load_state)
    assert.is.True(#org.files:all() > 0)
  end)
end)
