local orgmode = require('orgmode')
local config = require('orgmode.config')

local get_normal_mode_mapping_in_org_buffer = function(lhs)
  local current_buffer = vim.api.nvim_buf_get_name(0)

  local refile_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org'
  vim.cmd('edit ' .. refile_file)

  local normal_mode_mappings_in_org_buffer = vim.api.nvim_buf_get_keymap(0, 'n')

  for _, keymap in ipairs(normal_mode_mappings_in_org_buffer) do
    if keymap then
      if keymap['lhs'] then
        if keymap['lhs'] == lhs then
          vim.cmd('edit ' .. current_buffer)
          return keymap
        end
      end
    end
  end

  vim.cmd('edit ' .. current_buffer)
  return nil
end

describe('Config', function()
  local refile_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org'

  it('should parse an absolute archive location for a file', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd() .. '/tests/plenary/fixtures/*',
      org_default_notes_file = refile_file,
      org_archive_location = vim.fn.getcwd() .. '/tests/plenary/fixtures/archive/%s_archive::',
    })
    assert.are.same(
      config:parse_archive_location(refile_file),
      vim.fn.getcwd() .. '/tests/plenary/fixtures/archive/refile.org_archive'
    )
  end)

  it('should parse a relative archive location for a file', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd() .. '/tests/plenary/fixtures/*',
      org_default_notes_file = refile_file,
      org_archive_location = 'archives_relative/%s_archive::',
    })
    assert.are.same(
      config:parse_archive_location(refile_file),
      vim.fn.getcwd() .. '/tests/plenary/fixtures/archives_relative/refile.org_archive'
    )
  end)

  ---@diagnostic disable: need-check-nil
  it('should use the default key mapping when no override is provided', function()
    local org = orgmode.setup({})

    local mapping = get_normal_mode_mapping_in_org_buffer('g{')
    assert.are.same('<Cmd>lua require("orgmode").action("org_mappings.outline_up_heading")<CR>', mapping['rhs'])
    assert.are.same('org goto parent headline', mapping['desc'])
  end)

  it('should use the provided key mapping when the override is provided as a string', function()
    local org = orgmode.setup({
      mappings = {
        org = {
          outline_up_heading = { 'gouh' },
        },
      },
    })

    local mapping = get_normal_mode_mapping_in_org_buffer('gouh')
    assert.are.same('<Cmd>lua require("orgmode").action("org_mappings.outline_up_heading")<CR>', mapping['rhs'])
    assert.are.same('org goto parent headline', mapping['desc'])
  end)

  it('should use the provided key mapping when the override is provided as a table', function()
    local org = orgmode.setup({
      mappings = {
        org = {
          outline_up_heading = { 'gouh' },
        },
      },
    })

    local mapping = get_normal_mode_mapping_in_org_buffer('gouh')
    assert.are.same('<Cmd>lua require("orgmode").action("org_mappings.outline_up_heading")<CR>', mapping['rhs'])
    assert.are.same('org goto parent headline', mapping['desc'])
  end)

  it('should use the provided key mapping when the override is provided as a table including a new desc', function()
    local org = orgmode.setup({
      mappings = {
        org = {
          outline_up_heading = { 'gouh', desc = 'Go To Parent Headline' },
        },
      },
    })

    local mapping = get_normal_mode_mapping_in_org_buffer('gouh')
    assert.are.same('<Cmd>lua require("orgmode").action("org_mappings.outline_up_heading")<CR>', mapping['rhs'])
    assert.are.same('Go To Parent Headline', mapping['desc'])
  end)

  it('should add no-op group mappings for multi key leader prefixes', function()
    orgmode.setup({})

    for _, group in ipairs({
      { ',oi', 'org insert' },
      { ',ox', 'org clock' },
      { ',ol', 'org links' },
      { ',on', 'org notes' },
      { ',ob', 'org babel' },
      { ',od', 'org timestamp' },
    }) do
      local mapping = get_normal_mode_mapping_in_org_buffer(group[1])
      assert.are.same('', mapping['rhs'])
      assert.are.same(group[2], mapping['desc'])
      -- Group mappings must not be "nowait" so the longer mappings still win
      assert.are.same(0, mapping['nowait'])
    end
  end)

  it('should allow overriding a group mapping description', function()
    orgmode.setup({
      mappings = {
        org = {
          org_group_insert = { '<prefix>i', desc = 'Add' },
        },
      },
    })

    local mapping = get_normal_mode_mapping_in_org_buffer(',oi')
    assert.are.same('', mapping['rhs'])
    assert.are.same('Add', mapping['desc'])
  end)

  it('should allow disabling a group mapping', function()
    orgmode.setup({
      mappings = {
        org = {
          org_group_insert = false,
        },
      },
    })

    -- Use a fresh buffer so previously registered mappings don't leak in
    require('tests.plenary.helpers').create_file({ '* Test' })
    local mapping = nil
    for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      if keymap['lhs'] == ',oi' then
        mapping = keymap
      end
    end
    assert.is_nil(mapping)
  end)

  it('should add no-op group mappings for agenda leader prefixes', function()
    orgmode.setup({})
    require('tests.plenary.helpers').create_file({ '* Test' })
    config:setup_mappings('agenda', 0)

    local mappings = {}
    for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(0, 'n')) do
      mappings[keymap['lhs']] = keymap
    end

    assert.are.same('', mappings[',oi']['rhs'])
    assert.are.same('org insert', mappings[',oi']['desc'])
    assert.are.same('', mappings[',ox']['rhs'])
    assert.are.same('org clock', mappings[',ox']['desc'])
    assert.are.same('', mappings[',on']['rhs'])
    assert.are.same('org notes', mappings[',on']['desc'])
  end)

  it('should add a global root group mapping with the org mode description', function()
    orgmode.setup({})
    config:setup_mappings('global')

    local mapping = nil
    for _, keymap in ipairs(vim.api.nvim_get_keymap('n')) do
      if keymap['lhs'] == ',o' then
        mapping = keymap
      end
    end

    assert.are.same('', mapping['rhs'])
    assert.are.same('org mode', mapping['desc'])
    assert.are.same(0, mapping['nowait'])
    assert.are.same(0, mapping['buffer'])
  end)
  ---@diagnostic enable: need-check-nil
end)
