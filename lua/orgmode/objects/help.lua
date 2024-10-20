local utils = require('orgmode.utils')
local config = require('orgmode.config')

local Help = {
  buf = nil,
  win = nil,
}

function Help.show(type)
  if not Help.tree then
    Help._generate_tree()
  end
  local content = Help.prepare_content(type)
  local longest = utils.reduce(content, function(acc, item)
    return math.max(acc, item:len())
  end, 0)

  local window_opts = {
    relative = 'editor',
    width = math.min(longest + 2, vim.o.columns - 2),
    height = math.min(#content + 1, vim.o.lines - 2),
    anchor = 'NW',
    style = 'minimal',
    border = config.win_border,
    row = 5,
    col = vim.o.columns / 4,
  }

  window_opts.row = (vim.o.lines - window_opts.height) / 2
  window_opts.col = (vim.o.columns - window_opts.width) / 2

  Help.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(Help.buf, 'orghelp')
  vim.api.nvim_set_option_value('filetype', 'orghelp', { buf = Help.buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = Help.buf })
  Help.win = vim.api.nvim_open_win(Help.buf, true, window_opts)

  vim.api.nvim_buf_set_lines(Help.buf, 0, -1, true, content)

  vim.api.nvim_set_option_value('winhl', 'Normal:Normal', { win = Help.win })
  vim.api.nvim_set_option_value('wrap', false, { win = Help.win })
  vim.api.nvim_set_option_value('conceallevel', 3, { win = Help.win })
  vim.api.nvim_set_option_value('concealcursor', 'nvic', { win = Help.win })
  vim.api.nvim_set_option_value('modifiable', false, { buf = Help.buf })
  vim.api.nvim_buf_set_var(Help.buf, 'indent_blankline_enabled', false)

  vim.keymap.set('n', 'q', ':call nvim_win_close(win_getid(), v:true)<CR>', { buffer = Help.buf, silent = true })
  vim.keymap.set('n', '<Esc>', ':call nvim_win_close(win_getid(), v:true)<CR>', { buffer = Help.buf, silent = true })

  local org_help_augroup = vim.api.nvim_create_augroup('org_help', { clear = true })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = Help.buf,
    group = org_help_augroup,
    callback = function()
      require('orgmode.objects.help').dispose()
    end,
  })
end

function Help.dispose()
  Help.win = nil
  Help.buf = nil
end

function Help._generate_tree()
  local tree = {}
  local mappings = require('orgmode.config.mappings')
  for category, category_mappings in pairs(mappings) do
    tree[category] = {}
    for key, mapping in pairs(category_mappings) do
      if mapping.help_desc then
        table.insert(tree[category], { key = key, description = mapping.help_desc })
      end
    end

    if vim.tbl_isempty(tree[category]) then
      tree[category] = nil
    else
      table.sort(tree[category], function(a, b)
        return a.key < b.key
      end)
    end
  end

  Help.tree = tree
end

function Help._generate_mappings(buffer_type, title)
  local content = {
    ('  __%s__'):format(title),
  }
  local mappings = config.mappings
  for _, item in ipairs(Help.tree[buffer_type]) do
    local maps = mappings[buffer_type][item.key]
    if type(maps) == 'table' then
      maps = table.concat(maps, ', ')
    end

    table.insert(
      content,
      string.format('  `%-12s` - %s', string.gsub(maps, '<prefix>', mappings.prefix), item.description)
    )
  end
  table.insert(content, '')
  return content
end

---@return string[]
function Help.prepare_content(buffer_type)
  local opts_by_type = {
    org = { title = 'Org', include_org_mappings = false },
    capture = { title = 'Capture', include_org_mappings = true },
    note = { title = 'Note', include_org_mappings = true },
    agenda = { title = 'Agenda', include_org_mappings = false },
    edit_src = { title = 'Edit src', include_org_mappings = false },
  }
  local max_height = vim.o.lines - 2
  local title = opts_by_type[buffer_type].title
  local content = Help._generate_mappings(buffer_type, opts_by_type[buffer_type].title)
  if opts_by_type[buffer_type].include_org_mappings then
    vim.list_extend(content, Help._generate_mappings('org', opts_by_type.org.title))
    vim.list_extend(content, Help._generate_mappings('text_objects', 'Text Objects'))
    title = title .. ' + Org'
  elseif buffer_type == 'org' then
    vim.list_extend(content, Help._generate_mappings('text_objects', 'Text Objects'))
  end
  table.insert(content, string.format('  `%-12s` - %s', '<Esc>, q', 'Close this help'))

  local scroll_more_text = ''
  if #content > max_height then
    scroll_more_text = ' (Scroll down for more)'
  end

  return vim.list_extend({
    string.format(' **Orgmode mappings - %s:%s**', title, scroll_more_text),
    '',
  }, content)
end

return Help
