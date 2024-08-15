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
  ---@diagnostic enable: need-check-nil
end)
