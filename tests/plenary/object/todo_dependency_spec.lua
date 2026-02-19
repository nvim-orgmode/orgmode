local config = require('orgmode.config')
local TodoState = require('orgmode.objects.todo_state')
local TodoKeyword = require('orgmode.objects.todo_keywords.todo_keyword')

local helpers = require('tests.plenary.helpers')
local api = require('orgmode.api')
local Date = require('orgmode.objects.date')
local OrgId = require('orgmode.org.id')
local orgmode = require('orgmode')

local M = {}
-- @param headline OrgApiHeadline
-- local M.vis_head = function (headline, indent)
function M:vis_head(headline, indent)
  if headline == nil then
    return
  end
  print(string.rep('>', indent or 0) .. ' ' .. headline.title)
  for _, h in ipairs(headline.headlines) do
    M:vis_head(h, (indent or 0) + 1)
  end
end

function M:headline_has_unfinished_child(headline)
  for _, h in ipairs(headline.headlines) do
    if h.todo_type == 'TODO' then
      return true
    end
    if M:headline_has_unfinished_child(h) then
      return true
    end
  end
  return false
end

describe('Todo mappings unfer force dependency', function()
  before_each(function()
    config:extend({ org_enforce_todo_dependencies = true })
  end)
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)
  it('should change todo state of a headline forward (org_todo)', function()
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
    vim.fn.cursor(3, 1)

    -- Changing to DONE and adding closed date
    vim.cmd([[norm cit]])

    assert.are.same({
      '* DONE Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02> CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Removing todo keyword and removing closed date
    vim.cmd([[norm cit]])
    assert.are.same({
      '* Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Setting TODO keyword, initial state
    vim.cmd([[norm cit]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
  end)

  it('should change todo state of a headline forward (org_todo)', function()
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
    vim.fn.cursor(3, 1)

    -- Changing to DONE and adding closed date
    vim.cmd([[norm cit]])
    assert.are.same({
      '* DONE Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02> CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Removing todo keyword and removing closed date
    vim.cmd([[norm cit]])
    assert.are.same({
      '* Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Setting TODO keyword, initial state
    vim.cmd([[norm cit]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
  end)

  it('should change todo state of repeatable task and add last repeat property and state change (org_todo)', function()
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 6, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm cit]])
    vim.wait(50)
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-14 Tue 12:00 +1w>',
      '  :PROPERTIES:',
      '  :LAST_REPEAT: [' .. Date.now():to_string() .. ']',
      '  :END:',
      '  - State "DONE" from "TODO" [' .. Date.now():to_string() .. ']',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
  end)

  it('should change todo state of repeatable task and not log last repeat date if disabled', function()
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    }, {
      org_log_repeat = false,
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 6, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm cit]])
    vim.wait(50)
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-14 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 10, false))

    config.org_log_repeat = 'time'
  end)

  it('should add last repeat property and state change to drawer (org_log_into_drawer)', function()
    config:extend({
      org_log_into_drawer = 'LOGBOOK',
    })

    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 6, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm cit]])
    vim.wait(50)
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-14 Tue 12:00 +1w>',
      '  :PROPERTIES:',
      '  :LAST_REPEAT: [' .. Date.now():to_string() .. ']',
      '  :END:',
      '  :LOGBOOK:',
      '  - State "DONE" from "TODO" [' .. Date.now():to_string() .. ']',
      '  :END:',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 12, false))

    vim.fn.cursor(3, 1)
    vim.cmd([[norm cit]])
    vim.wait(200)
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-21 Tue 12:00 +1w>',
      '  :PROPERTIES:',
      '  :LAST_REPEAT: [' .. Date.now():to_string() .. ']',
      '  :END:',
      '  :LOGBOOK:',
      '  - State "DONE" from "TODO" [' .. Date.now():to_string() .. ']',
      '  - State "DONE" from "TODO" [' .. Date.now():to_string() .. ']',
      '  :END:',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 13, false))
  end)

  it('should change todo state of a headline backward (org_todo_prev)', function()
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
    vim.fn.cursor(3, 1)

    -- Removing todo keyword
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Changing to DONE and adding closed date
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* DONE Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02> CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Setting TODO keyword, initial state
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
  end)

  it('should change todo state of a headline backward (org_todo_prev)', function()
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO Test orgmode 1',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
    vim.fn.cursor(3, 1)

    -- Removing todo keyword, but will fail because of dependency
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Changing to DONE and adding closed date, but will fail because of dependency
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    --  remove TODO
    vim.fn.cursor(5, 1)
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** Test orgmode 1',
    }, vim.api.nvim_buf_get_lines(0, 2, 5, false))

    -- toggle done
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** DONE Test orgmode 1',
      '   CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(0, 2, 6, false))

    -- remove todo for parent
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- toggle done

    vim.cmd([[norm ciT]])
    assert.are.same({
      '* DONE Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02> CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
  end)
end)
