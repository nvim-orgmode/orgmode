local config = require('orgmode.config')
local TodoState = require('orgmode.objects.todo_state')

describe('Todo state', function()
  it('should switch to next state', function()
    local state = TodoState:new({ current_state = 'TODO' })
    assert.are.same({ value = 'DONE', type = 'DONE', hl = 'OrgDONE' }, state:get_next())
    assert.are.same({ value = '', type = '' }, state:get_next())
    assert.are.same({ value = 'TODO', type = 'TODO', hl = 'OrgTODO' }, state:get_next())
  end)

  it('should switch to prev state', function()
    local state = TodoState:new({ current_state = 'TODO' })
    assert.are.same({ value = '', type = '' }, state:get_prev())
    assert.are.same({ value = 'DONE', type = 'DONE', hl = 'OrgDONE' }, state:get_prev())
    assert.are.same({ value = 'TODO', type = 'TODO', hl = 'OrgTODO' }, state:get_prev())
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
    local next_state = TodoState:new({ current_state = 'TODO' })
    assert.are.same({ value = 'WAITING', type = 'TODO', hl = 'OrgTODO' }, next_state:get_next())
    assert.are.same({ value = 'PROCESSING', type = 'TODO', hl = 'OrgTODO' }, next_state:get_next())
    assert.are.same({ value = 'HYPHEN-KEYWORD', type = 'TODO', hl = 'OrgTODO' }, next_state:get_next())
    assert.are.same({ value = 'MULTI-HYPHEN-KEYWORD', type = 'TODO', hl = 'OrgTODO' }, next_state:get_next())
    assert.are.same({ value = 'CONFIRM', type = 'DONE', hl = 'OrgDONE' }, next_state:get_next())
    assert.are.same({ value = 'DONE', type = 'DONE', hl = 'OrgDONE' }, next_state:get_next())
    assert.are.same({ value = '', type = '' }, next_state:get_next())

    local prev_state = TodoState:new({ current_state = 'WAITING' })
    assert.are.same({ value = 'TODO', type = 'TODO', hl = 'OrgTODO' }, prev_state:get_prev())
    assert.are.same({ value = '', type = '' }, prev_state:get_prev())
    assert.are.same({ value = 'DONE', type = 'DONE', hl = 'OrgDONE' }, prev_state:get_prev())
    assert.are.same({ value = 'CONFIRM', type = 'DONE', hl = 'OrgDONE' }, prev_state:get_prev())
    assert.are.same({ value = 'MULTI-HYPHEN-KEYWORD', type = 'TODO', hl = 'OrgTODO' }, prev_state:get_prev())
    assert.are.same({ value = 'HYPHEN-KEYWORD', type = 'TODO', hl = 'OrgTODO' }, prev_state:get_prev())
    assert.are.same({ value = 'PROCESSING', type = 'TODO', hl = 'OrgTODO' }, prev_state:get_prev())
    assert.are.same({ value = 'WAITING', type = 'TODO', hl = 'OrgTODO' }, prev_state:get_prev())
    assert.are.same({ value = 'TODO', type = 'TODO', hl = 'OrgTODO' }, prev_state:get_prev())
  end)
end)
