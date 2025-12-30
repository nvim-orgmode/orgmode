local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')
local org = require('orgmode')
local api = vim.api

describe('foldtext highlighter', function()
  local ns_id = api.nvim_create_namespace('org_custom_highlighter')

  local function setup_file_with_folds(content)
    -- Enable colored folds so foldtext extmarks are used
    config.ui.folds.colored = true
    helpers.create_file(content)
    -- Disable ephemeral mode so extmarks persist and are queryable
    -- Must be set after create_file initializes the highlighter
    ---@diagnostic disable-next-line: invisible
    org.highlighter._ephemeral = false
  end

  ---Get the column position of the foldtext ellipsis extmark on a line.
  ---@param bufnr number
  ---@param line number 0-indexed line number
  ---@return number|nil col The column position, or nil if no extmark found
  local function get_ellipsis_col(bufnr, line)
    local extmarks = api.nvim_buf_get_extmarks(bufnr, ns_id, { line, 0 }, { line, -1 }, { details = true })
    for _, mark in ipairs(extmarks) do
      local details = mark[4]
      -- Foldtext extmarks have virt_text with the ellipsis
      if details and details.virt_text then
        return mark[3] -- col is the 3rd element (0-indexed)
      end
    end
    return nil
  end

  after_each(function()
    api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
    vim.cmd([[%bw!]])
    config.ui.folds.colored = false
    ---@diagnostic disable-next-line: invisible
    if org.highlighter then
      org.highlighter._ephemeral = true
    end
  end)

  describe('ellipsis position', function()
    it('updates when folded headline content changes', function()
      setup_file_with_folds({
        '* This is a very long headline with many words',
        'Some body text under the headline',
      })
      local bufnr = api.nvim_get_current_buf()

      -- Fold the headline
      vim.cmd('1')
      vim.cmd('normal! zc')
      vim.cmd('redraw!')

      -- Verify extmark reflects long headline
      local original_col = get_ellipsis_col(bufnr, 0)
      assert.is_not_nil(original_col, 'Expected extmark for folded line')
      assert.is_true(original_col > 40, 'Expected col > 40 for long headline, got ' .. tostring(original_col))

      -- Change headline to shorter content
      api.nvim_buf_set_lines(bufnr, 0, 1, false, { '* Short' })
      vim.cmd('redraw!')

      -- Extmark should reflect new shorter line
      local new_col = get_ellipsis_col(bufnr, 0)
      if new_col ~= nil then
        assert.is_true(
          new_col < 10,
          'Extmark should reflect shorter line - col is ' .. tostring(new_col) .. ', expected < 10'
        )
      end
    end)

    it('keeps ellipsis position within line bounds after content shortening', function()
      setup_file_with_folds({
        '* This is a very long headline with many words here',
        'Body text',
      })
      local bufnr = api.nvim_get_current_buf()

      -- Fold and trigger extmark creation
      vim.cmd('1')
      vim.cmd('normal! zc')
      vim.cmd('redraw!')

      local original_col = get_ellipsis_col(bufnr, 0)
      assert.is_not_nil(original_col, 'Expected extmark')
      assert.is_true(original_col > 45, 'Expected col > 45 for long line')

      -- Shorten the content significantly
      api.nvim_buf_set_lines(bufnr, 0, 1, false, { '* Short' })
      local new_line_length = #'* Short'
      vim.cmd('redraw!')

      local new_col = get_ellipsis_col(bufnr, 0)

      -- Ellipsis position must be within new line bounds
      if new_col ~= nil then
        assert.is_true(
          new_col <= new_line_length,
          'Ellipsis col (' .. tostring(new_col) .. ') exceeds line length (' .. new_line_length .. ')'
        )
      end
    end)

    it('maintains correct ellipsis position through fold toggle cycles', function()
      setup_file_with_folds({
        '* TODO This is a task with a long description here',
        'Body text with details',
        '* Another headline',
      })
      local bufnr = api.nvim_get_current_buf()

      -- Close all folds
      vim.cmd('normal! zM')
      vim.cmd('redraw!')

      local col_before = get_ellipsis_col(bufnr, 0)
      assert.is_not_nil(col_before, 'Expected extmark before change')

      -- Change content while folded (simulates TODO state change)
      api.nvim_buf_set_lines(bufnr, 0, 1, false, { '* DONE Short' })

      -- Toggle folds open and closed
      vim.cmd('normal! za')
      vim.cmd('normal! za')
      vim.cmd('redraw!')

      local col_after = get_ellipsis_col(bufnr, 0)

      -- Ellipsis position should reflect new content
      if col_after ~= nil then
        local new_line_length = #'* DONE Short'
        assert.is_true(
          col_after <= new_line_length,
          'Ellipsis col ' .. tostring(col_after) .. ' exceeds line length ' .. new_line_length
        )
      end
    end)

    it('updates ellipsis position when TODO state change adds CLOSED timestamp', function()
      setup_file_with_folds({
        '* TODO A task headline',
        'Some body content here',
        '** Nested headline',
        'More content',
      })
      local bufnr = api.nvim_get_current_buf()

      -- Close all folds
      vim.cmd('normal! zM')
      vim.cmd('redraw!')

      local col_before = get_ellipsis_col(bufnr, 0)
      assert.is_not_nil(col_before, 'Expected extmark for TODO headline')

      -- Simulate TODO -> DONE with CLOSED timestamp insertion
      api.nvim_buf_set_lines(bufnr, 0, 2, false, {
        '* DONE A task headline',
        'CLOSED: [2025-12-29 Sun 10:00]',
        'Some body content here',
      })
      vim.cmd('redraw!')

      local col_after = get_ellipsis_col(bufnr, 0)
      if col_after ~= nil then
        local new_line_length = #'* DONE A task headline'
        assert.is_true(
          col_after <= new_line_length,
          'Ellipsis col ' .. tostring(col_after) .. ' exceeds line length ' .. new_line_length
        )
      end
    end)

    it('recomputes ellipsis position after zx fold reset', function()
      setup_file_with_folds({
        '* First headline with lots of text here',
        'Body content',
        '** Nested section',
        'More body',
        '* Second headline',
      })
      local bufnr = api.nvim_get_current_buf()

      -- Close all folds
      vim.cmd('normal! zM')
      vim.cmd('redraw!')

      local col_before = get_ellipsis_col(bufnr, 0)
      assert.is_not_nil(col_before, 'Expected initial extmark')

      -- Change content to shorter headline
      api.nvim_buf_set_lines(bufnr, 0, 1, false, { '* Short' })

      -- Reset folds with zx
      vim.cmd('normal! zx')
      vim.cmd('redraw!')

      local col_after = get_ellipsis_col(bufnr, 0)
      if col_after ~= nil then
        local new_line_length = #'* Short'
        assert.is_true(
          col_after <= new_line_length,
          'Ellipsis col ' .. tostring(col_after) .. ' exceeds line length ' .. new_line_length
        )
      end
    end)

    it('handles content changes in complex org files with property drawers', function()
      setup_file_with_folds({
        '#+TITLE: Project Planning Document',
        '#+STARTUP: overview',
        '#+PROPERTY: header-args :results output',
        '',
        '* TODO Phase 1: Foundation [1/3]',
        ':PROPERTIES:',
        ':ID: phase-1-foundation',
        ':CREATED: [2025-01-01 Wed]',
        ':END:',
        'Initial setup and configuration tasks.',
        '',
        '** DONE Setup development environment',
        ':PROPERTIES:',
        ':ID: setup-dev-env',
        ':EFFORT: 2h',
        ':END:',
        'CLOSED: [2025-01-15 Wed 14:30]',
        '- [X] Install dependencies',
        '- [X] Configure linters',
        '- [X] Setup pre-commit hooks',
        '',
        '** TODO Configure CI/CD pipeline',
        ':PROPERTIES:',
        ':ID: setup-cicd',
        ':EFFORT: 4h',
        ':END:',
        'Need to setup GitHub Actions workflow.',
        '',
        '#+begin_src yaml',
        'name: CI',
        'on: [push, pull_request]',
        'jobs:',
        '  test:',
        '    runs-on: ubuntu-latest',
        '#+end_src',
        '',
        '** TODO Write documentation',
        ':PROPERTIES:',
        ':ID: write-docs',
        ':END:',
        '',
        '* PROGRESS Phase 2: Implementation [0/2]',
        ':PROPERTIES:',
        ':ID: phase-2-impl',
        ':END:',
        '',
        '** TODO Core features',
        'Main implementation work.',
        '',
        '| Feature | Status | Priority |',
        '|---------+--------+----------|',
        '| Auth    | TODO   | High     |',
        '| API     | TODO   | High     |',
        '| UI      | TODO   | Medium   |',
        '',
        '** TODO Testing',
        ':PROPERTIES:',
        ':ID: testing',
        ':END:',
        '',
        '* Phase 3: Deployment',
        ':PROPERTIES:',
        ':ID: phase-3-deploy',
        ':END:',
        'Final deployment and monitoring setup.',
        '',
        '* Resources',
        '- [[https://example.com][Documentation]]',
        '- [[file:notes.org][Project Notes]]',
      })
      local bufnr = api.nvim_get_current_buf()

      -- Close all folds to simulate overview mode
      vim.cmd('normal! zM')
      vim.cmd('redraw!')

      -- Verify extmarks exist for folded headlines
      -- Line 4 (0-indexed) is "* TODO Phase 1: Foundation [1/3]"
      local phase1_col = get_ellipsis_col(bufnr, 4)
      assert.is_not_nil(phase1_col, 'Expected extmark for Phase 1 headline')

      -- Mark Phase 1 as DONE
      local new_line = '* DONE Phase 1: Foundation [3/3]'
      api.nvim_buf_set_lines(bufnr, 4, 5, false, { new_line })

      -- Add CLOSED timestamp (shifts content down)
      local lines = api.nvim_buf_get_lines(bufnr, 5, 6, false)
      api.nvim_buf_set_lines(bufnr, 5, 6, false, {
        'CLOSED: [2025-12-29 Sun 15:00]',
        lines[1],
      })

      vim.cmd('redraw!')

      local new_col = get_ellipsis_col(bufnr, 4)
      if new_col ~= nil then
        local new_line_length = #new_line
        assert.is_true(
          new_col <= new_line_length,
          'Ellipsis col ' .. tostring(new_col) .. ' exceeds line length ' .. new_line_length
        )
      end

      -- Verify zx fold reset also works
      vim.cmd('normal! zx')
      vim.cmd('redraw!')

      local after_zx_col = get_ellipsis_col(bufnr, 4)
      if after_zx_col ~= nil then
        assert.is_true(
          after_zx_col <= #new_line,
          'Ellipsis col ' .. tostring(after_zx_col) .. ' exceeds line length after zx'
        )
      end
    end)

    it('updates ellipsis position when line gets longer', function()
      setup_file_with_folds({
        '* Short',
        'Body text here.',
      })
      local bufnr = api.nvim_get_current_buf()

      -- Fold the short headline
      vim.cmd('1')
      vim.cmd('normal! zc')
      vim.cmd('redraw!')

      local original_col = get_ellipsis_col(bufnr, 0)
      assert.is_not_nil(original_col, 'Expected extmark')
      assert.is_true(original_col < 10, 'Expected col < 10 for short headline')

      -- Make headline much longer
      api.nvim_buf_set_lines(bufnr, 0, 1, false, { '* TODO This is now a very long headline with lots of text' })
      vim.cmd('redraw!')

      local new_col = get_ellipsis_col(bufnr, 0)

      -- Ellipsis must move to end of longer line
      if new_col ~= nil then
        assert.is_true(
          new_col > 40,
          'Ellipsis should move to end of longer line - col is ' .. tostring(new_col) .. ', expected > 40'
        )
      end
    end)

    it('updates ellipsis position when headline and property drawer both change', function()
      setup_file_with_folds({
        '* A headline with a very long title that spans quite a bit',
        ':PROPERTIES:',
        ':ID: some-id',
        ':END:',
        'Body content here.',
        '** Nested section',
        'More content.',
      })
      local bufnr = api.nvim_get_current_buf()

      -- Fold everything
      vim.cmd('normal! zM')
      vim.cmd('redraw!')

      local original_col = get_ellipsis_col(bufnr, 0)
      assert.is_not_nil(original_col, 'Expected extmark for headline')

      -- Shorten the headline
      api.nvim_buf_set_lines(bufnr, 0, 1, false, { '* Short' })

      -- Add more properties
      api.nvim_buf_set_lines(bufnr, 2, 3, false, {
        ':ID: some-id',
        ':CUSTOM_ID: custom-123',
        ':CREATED: [2025-12-29]',
      })

      vim.cmd('redraw!')

      local new_col = get_ellipsis_col(bufnr, 0)
      if new_col ~= nil then
        assert.is_true(new_col <= #'* Short', 'Ellipsis col ' .. tostring(new_col) .. ' exceeds line length')
      end
    end)
  end)
end)
