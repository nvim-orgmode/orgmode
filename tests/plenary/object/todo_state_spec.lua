local config = require('orgmode.config')
local TodoState = require('orgmode.objects.todo_state')
local TodoKeyword = require('orgmode.objects.todo_keywords.todo_keyword')

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
end)
