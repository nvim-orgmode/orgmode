local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

---Stand-in for a floating window input handler like dressing.nvim or
---snacks.nvim. Those open their own window and enter insert mode, which ends
---visual mode before the prompt is answered.
---@param answers table<string, string>
local function float_input(answers)
  return function(opts, on_confirm)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      row = 1,
      col = 1,
      width = 20,
      height = 1,
      style = 'minimal',
    })
    vim.cmd('startinsert')
    vim.cmd('stopinsert')
    vim.api.nvim_win_close(win, true)
    local answer = answers[opts.prompt]
    if answer == nil then
      answer = opts.default
    end
    return on_confirm(answer)
  end
end

---@param answers table<string, string>
---@param keys string
local function insert_link(answers, keys)
  helpers.with_var(config.ui.input, 'use_vim_ui', true, function()
    helpers.with_var(vim.ui, 'input', float_input(answers), function()
      vim.cmd('norm ' .. vim.api.nvim_replace_termcodes(keys, true, true, true))
      vim.wait(200)
    end)
  end)
end

describe('Insert link', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should use a charwise visual selection as description', function()
    helpers.create_file({ 'alpha beta gamma' })
    vim.fn.cursor(1, 7)
    insert_link({ ['Links: '] = 'https://example.com' }, 've,oli')
    assert.are.same('alpha [[https://example.com][beta]] gamma', vim.api.nvim_get_current_line())
  end)

  it('should use a linewise visual selection as description', function()
    helpers.create_file({ 'alpha beta gamma' })
    vim.fn.cursor(1, 1)
    insert_link({ ['Links: '] = 'https://example.com' }, 'V,oli')
    assert.are.same('[[https://example.com][alpha beta gamma]]', vim.api.nvim_get_current_line())
  end)

  it('should use a blockwise visual selection as description', function()
    helpers.create_file({ 'alpha beta gamma' })
    vim.fn.cursor(1, 7)
    insert_link({ ['Links: '] = 'https://example.com' }, '<C-v>e,oli')
    assert.are.same('alpha [[https://example.com][beta]] gamma', vim.api.nvim_get_current_line())
  end)

  it('should prefer the visual selection over the link target', function()
    helpers.create_file({ 'alpha beta gamma' })
    vim.fn.cursor(1, 7)
    insert_link({ ['Links: '] = 'file:/tmp/target.org::*Some Headline' }, 've,oli')
    assert.are.same('alpha [[file:/tmp/target.org::*Some Headline][beta]] gamma', vim.api.nvim_get_current_line())
  end)

  it('should fall back to the link target when nothing is selected', function()
    helpers.create_file({ 'alpha beta gamma' })
    vim.fn.cursor(1, 5)
    insert_link({ ['Links: '] = 'file:/tmp/target.org::*Some Headline' }, ',oli')
    assert.are.same(
      'alpha[[file:/tmp/target.org::*Some Headline][Some Headline]] beta gamma',
      vim.api.nvim_get_current_line()
    )
  end)
end)
