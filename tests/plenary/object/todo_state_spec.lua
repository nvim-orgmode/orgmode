local config = require('orgmode.config')
local TodoState = require('orgmode.objects.todo_state')
local TodoKeyword = require('orgmode.objects.todo_keywords.todo_keyword')
local helpers = require('tests.plenary.helpers')

describe('Todo state', function()
  local todo_keywords = config:get_todo_keywords()
  it('should switch to next state', function()
    local state = TodoState:new({ current_state = 'TODO' })
    assert.are.same(todo_keywords:find('DONE'), state:get_next())
    assert.are.same(TodoKeyword:empty(), state:get_next())
    assert.are.same(todo_keywords:find('TODO'), state:get_next())
  end)

  it('should switch to prev state', function()
    local state = TodoState:new({ current_state = 'TODO' })
    assert.are.same(TodoKeyword:empty(), state:get_prev())
    assert.are.same(todo_keywords:find('DONE'), state:get_prev())
    assert.are.same(todo_keywords:find('TODO'), state:get_prev())
  end)

  it('should properly cycle through all defined custom states', function()
    config:extend({
      org_todo_keywords = {
        'TODO',
        'WAITING',
        'PROCESSING',
        'HYPHEN-KEYWORD',
        'MULTI-HYPHEN-KEYWORD',
        '|',
        'CONFIRM',
        'DONE',
      },
    })
    todo_keywords = config:get_todo_keywords()
    local next_state = TodoState:new({ current_state = 'TODO' })
    assert.are.same(todo_keywords:find('WAITING'), next_state:get_next())
    assert.are.same(todo_keywords:find('PROCESSING'), next_state:get_next())
    assert.are.same(todo_keywords:find('HYPHEN-KEYWORD'), next_state:get_next())
    assert.are.same(todo_keywords:find('MULTI-HYPHEN-KEYWORD'), next_state:get_next())
    assert.are.same(todo_keywords:find('CONFIRM'), next_state:get_next())
    assert.are.same(todo_keywords:find('DONE'), next_state:get_next())
    assert.are.same(TodoKeyword:empty(), next_state:get_next())

    local prev_state = TodoState:new({ current_state = 'WAITING' })
    assert.are.same(todo_keywords:find('TODO'), prev_state:get_prev())
    assert.are.same(TodoKeyword:empty(), prev_state:get_prev())
    assert.are.same(todo_keywords:find('DONE'), prev_state:get_prev())
    assert.are.same(todo_keywords:find('CONFIRM'), prev_state:get_prev())
    assert.are.same(todo_keywords:find('MULTI-HYPHEN-KEYWORD'), prev_state:get_prev())
    assert.are.same(todo_keywords:find('HYPHEN-KEYWORD'), prev_state:get_prev())
    assert.are.same(todo_keywords:find('PROCESSING'), prev_state:get_prev())
    assert.are.same(todo_keywords:find('WAITING'), prev_state:get_prev())
    assert.are.same(todo_keywords:find('TODO'), prev_state:get_prev())
  end)

  describe('Multiple todo sequences', function()
    after_each(function()
      vim.cmd([[silent! %bw!]])
    end)

    it('should properly parse multiple todo sequences from config', function()
      -- Setup config with multiple sequences
      config:extend({
        org_todo_keywords = {
          { 'TODO', 'NEXT', '|', 'DONE' },
          { 'MEETING', 'PHONE', '|', 'COMPLETED' },
        },
      })

      local file_todo_keywords = config:get_todo_keywords()

      -- Check if sequences were properly parsed
      assert.are.equal(2, #file_todo_keywords.sequences)

      -- First sequence
      assert.are.equal('TODO', file_todo_keywords.sequences[1][1].value)
      assert.are.equal('NEXT', file_todo_keywords.sequences[1][2].value)
      assert.are.equal('DONE', file_todo_keywords.sequences[1][3].value)
      assert.are.equal(1, file_todo_keywords.sequences[1][1].sequence_index)

      -- Second sequence
      assert.are.equal('MEETING', file_todo_keywords.sequences[2][1].value)
      assert.are.equal('PHONE', file_todo_keywords.sequences[2][2].value)
      assert.are.equal('COMPLETED', file_todo_keywords.sequences[2][3].value)
      assert.are.equal(2, file_todo_keywords.sequences[2][1].sequence_index)
    end)

    it('should properly cycle through states within the same sequence', function()
      config:extend({
        org_todo_keywords = {
          { 'TODO', 'NEXT', '|', 'DONE' },
          { 'MEETING', 'PHONE', '|', 'COMPLETED' },
        },
      })

      -- Create TodoState with 'TODO' current state (from sequence 1)
      local todo_state = TodoState:new({
        current_state = 'TODO',
        todos = config:get_todo_keywords(),
      })

      -- Cycling through sequence 1
      assert.are.equal('NEXT', todo_state:get_next().value)
      assert.are.equal('DONE', todo_state:get_next().value)
      assert.are.equal('', todo_state:get_next().value) -- Empty state after last one
      assert.are.equal('TODO', todo_state:get_next().value) -- Back to first

      -- Create TodoState with 'MEETING' current state (from sequence 2)
      local meeting_state = TodoState:new({
        current_state = 'MEETING',
        todos = config:get_todo_keywords(),
      })

      -- Cycling through sequence 2
      assert.are.equal('PHONE', meeting_state:get_next().value)
      assert.are.equal('COMPLETED', meeting_state:get_next().value)
      assert.are.equal('', meeting_state:get_next().value) -- Empty state after last one
      assert.are.equal('TODO', meeting_state:get_next().value) -- After empty, always go to first sequence
    end)

    it('should enable fast access mode for multiple sequences without explicit shortcuts', function()
      config:extend({
        org_todo_keywords = {
          { 'TODO', 'NEXT', '|', 'DONE' },
          { 'MEETING', 'PHONE', '|', 'COMPLETED' },
        },
      })

      local todos = config:get_todo_keywords()
      local todo_state = TodoState:new({
        current_state = '',
        todos = todos,
      })

      -- Verify fast access is enabled when multiple sequences exist
      assert.is_true(todo_state:has_fast_access())
    end)

    it('should parse multiple todo sequences from file directives', function()
      -- Create a test file with multiple TODO directives
      local file = helpers.create_file({
        '#+TITLE: Test Multiple Sequences',
        '#+TODO: TODO NEXT | DONE',
        '#+TODO: MEETING PHONE | COMPLETED',
        '',
        '* TODO Task one',
        '* MEETING Meeting with team',
      })

      local file_todo_keywords = file:get_todo_keywords()

      -- Check if sequences were properly parsed
      assert.are.equal(2, #file_todo_keywords.sequences)

      -- First sequence
      assert.are.equal('TODO', file_todo_keywords.sequences[1][1].value)
      assert.are.equal('NEXT', file_todo_keywords.sequences[1][2].value)
      assert.are.equal('DONE', file_todo_keywords.sequences[1][3].value)

      -- Second sequence
      assert.are.equal('MEETING', file_todo_keywords.sequences[2][1].value)
      assert.are.equal('PHONE', file_todo_keywords.sequences[2][2].value)
      assert.are.equal('COMPLETED', file_todo_keywords.sequences[2][3].value)
    end)

    it('should use the first todo of the same sequence when resetting repeatable task', function()
      config:extend({
        org_todo_keywords = {
          { 'TODO', 'NEXT', '|', 'DONE' },
          { 'MEETING', 'PHONE', '|', 'COMPLETED' },
        },
      })

      -- Create a test file with repeating tasks from different sequences
      local file = helpers.create_file({
        '#+TITLE: Test Repeatable Tasks',
        '',
        '* TODO Regular Task',
        '  SCHEDULED: <2023-05-03 Wed +1d>',
        '* MEETING Daily Meeting',
        '  SCHEDULED: <2023-05-03 Wed +1d>',
      })

      -- Test with task from sequence 1
      local headline1 = file:get_closest_headline({ 3, 0 })
      local todo_state1 = TodoState:new({
        current_state = headline1:get_todo(),
        todos = file:get_todo_keywords(),
      })
      local reset_state1 = todo_state1:get_reset_todo(headline1)

      -- It should reset to TODO, which is the first state in the first sequence
      assert.are.equal('TODO', reset_state1.value)

      -- Test with task from sequence 2
      local headline2 = file:get_closest_headline({ 5, 0 })
      local todo_state2 = TodoState:new({
        current_state = headline2:get_todo(),
        todos = file:get_todo_keywords(),
      })
      local reset_state2 = todo_state2:get_reset_todo(headline2)

      -- It should reset to MEETING, which is the first state in the second sequence
      assert.are.equal('MEETING', reset_state2.value)
    end)

    it('should auto-generate shortcuts from first letters when no shortcuts are defined', function()
      config:extend({
        org_todo_keywords = {
          { 'TODO', 'NEXT', '|', 'DONE' },
          { 'MEETING', 'PHONE', '|', 'COMPLETED' },
        },
      })

      local todos = config:get_todo_keywords()

      -- Check if auto-generated shortcuts are created properly
      -- They should be lowercase first letters of todo keywords
      assert.are.equal('t', todos:find('TODO').shortcut)
      assert.are.equal('n', todos:find('NEXT').shortcut)
      assert.are.equal('d', todos:find('DONE').shortcut)

      assert.are.equal('m', todos:find('MEETING').shortcut)
      assert.are.equal('p', todos:find('PHONE').shortcut)
      assert.are.equal('c', todos:find('COMPLETED').shortcut)
    end)

    it('should handle shortcut conflicts by giving priority to first sequence', function()
      config:extend({
        org_todo_keywords = {
          { 'TODO', 'NEXT', '|', 'DONE' },
          { 'TEST', 'NEW', '|', 'DROPPED' }, -- T conflicts with TODO, N conflicts with NEXT, D conflicts with DONE
        },
      })

      local todos = config:get_todo_keywords()

      -- Check that the first sequence gets the conflicting shortcuts
      assert.are.equal('t', todos:find('TODO').shortcut)
      assert.are.equal('n', todos:find('NEXT').shortcut)
      assert.are.equal('d', todos:find('DONE').shortcut)

      -- The second sequence should get some other shortcuts or possibly none
      -- but system shouldn't crash with duplicate shortcuts
      local test_keyword = todos:find('TEST')
      assert.is_truthy(test_keyword)

      -- Fast access mode should still be enabled with multiple sequences
      local todo_state = TodoState:new({
        current_state = '',
        todos = todos,
      })
      assert.is_true(todo_state:has_fast_access())
    end)

    it('should respect manually defined shortcuts', function()
      config:extend({
        org_todo_keywords = {
          { 'TODO(o)', 'NEXT(x)', '|', 'DONE(e)' }, -- Custom shortcuts, not first letters
          { 'MEETING(g)', 'PHONE(h)', '|', 'COMPLETED(i)' },
        },
      })

      local todos = config:get_todo_keywords()

      -- Check if explicitly defined shortcuts are used
      assert.are.equal('o', todos:find('TODO').shortcut)
      assert.are.equal('x', todos:find('NEXT').shortcut)
      assert.are.equal('e', todos:find('DONE').shortcut)

      assert.are.equal('g', todos:find('MEETING').shortcut)
      assert.are.equal('h', todos:find('PHONE').shortcut)
      assert.are.equal('i', todos:find('COMPLETED').shortcut)

      -- Confirm fast access is enabled
      local todo_state = TodoState:new({
        current_state = '',
        todos = todos,
      })
      assert.is_true(todo_state:has_fast_access())
    end)

    it('should handle mixed shortcut definition (some explicit, some auto-generated)', function()
      config:extend({
        org_todo_keywords = {
          { 'TODO(o)', 'NEXT', '|', 'DONE(e)' }, -- Mixed: explicit, auto, explicit
          { 'MEETING', 'PHONE(h)', '|', 'COMPLETED' }, -- Mixed: auto, explicit, auto
        },
      })

      local todos = config:get_todo_keywords()

      -- Check explicitly defined shortcuts
      assert.are.equal('o', todos:find('TODO').shortcut)
      assert.are.equal('e', todos:find('DONE').shortcut)
      assert.are.equal('h', todos:find('PHONE').shortcut)

      -- Check auto-generated shortcuts
      assert.are.equal('n', todos:find('NEXT').shortcut)
      assert.are.equal('m', todos:find('MEETING').shortcut)
      assert.are.equal('c', todos:find('COMPLETED').shortcut)

      -- Confirm fast access is enabled
      local todo_state = TodoState:new({
        current_state = '',
        todos = todos,
      })
      assert.is_true(todo_state:has_fast_access())
    end)

    it('should properly toggle todo states using fast access when multiple sequences exist', function()
      local file = helpers.create_file({
        '#+TITLE: Test Multiple Sequences',
        '#+TODO: TODO NEXT | DONE',
        '#+TODO: MEETING PHONE | COMPLETED',
        '',
        '* TODO Task one',
        '* MEETING Meeting with team',
      })

      -- The test now validates that multiple sequences automatically trigger fast access mode
      local todo_state = TodoState:new({
        current_state = 'TODO',
        todos = file:get_todo_keywords(),
      })

      -- Check that fast access is enabled with multiple sequences
      assert.are.same(true, todo_state:has_fast_access())

      -- Test that all keywords from all sequences have fast access shortcuts
      for _, keyword in ipairs(file:get_todo_keywords():all()) do
        assert.are.same(true, keyword.has_fast_access)
      end
    end)

    it('should correctly identify todo keywords from different sequences', function()
      local file = helpers.create_file({
        '#+TITLE: Test Multiple Sequences',
        '#+TODO: TODO NEXT | DONE',
        '#+TODO: MEETING PHONE | COMPLETED',
        '',
        '* TODO Task one',
        '* MEETING Meeting with team',
      })

      local file_todo_keywords = file:get_todo_keywords()

      -- Verify first sequence
      local todo_state1 = TodoState:new({
        current_state = 'TODO',
        todos = file_todo_keywords,
      })
      local next_state = todo_state1:get_next()
      if next_state == nil then -- for the type checker
        assert.is.truthy(next_state)
        return
      end
      assert.are.same('NEXT', next_state.value)
      assert.are.same(1, next_state.sequence_index)

      -- Verify second sequence
      local todo_state2 = TodoState:new({
        current_state = 'MEETING',
        todos = file_todo_keywords,
      })
      local phone_state = todo_state2:get_next()
      if phone_state == nil then -- for the type checker
        assert.is.truthy(phone_state)
        return
      end
      assert.are.same('PHONE', phone_state.value)
      assert.are.same(2, phone_state.sequence_index)
    end)
  end)
end)
