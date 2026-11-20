local current_file_path = string.sub(debug.getinfo(1, 'S').source, 2)
local docs_dir = vim.fn.fnamemodify(current_file_path, ':p:h:h:h:h') .. '/docs'

---@param orgmode Org
---@param config OrgConfig
local function generate_agenda_object(orgmode, config)
  local Agenda = setmetatable({}, {
    __call = function()
      return orgmode.agenda:prompt()
    end,
  })

  local agenda_keys = { 'a', 't', 'm', 'M', 's' }
  if config.org_agenda_custom_commands then
    for key, _ in pairs(config.org_agenda_custom_commands) do
      table.insert(agenda_keys, key)
    end
  end

  table.sort(agenda_keys)

  for _, key in ipairs(agenda_keys) do
    Agenda[key] = function()
      return orgmode.agenda:open_by_key(key)
    end
  end

  return Agenda
end

---@param orgmode Org
---@param config OrgConfig
local function generate_capture_object(orgmode, config)
  local Capture = setmetatable({}, {
    __call = function()
      return orgmode.capture:prompt()
    end,
  })

  for key, _ in pairs(config.org_capture_templates or {}) do
    Capture[key] = function()
      return orgmode.capture:open_template_by_shortcut(key)
    end
  end

  return Capture
end

---@param orgmode Org
---@param config OrgConfig
local function generate_attach_object(orgmode, config)
  local Attach = setmetatable({}, {
    __call = function()
      return orgmode.attach:prompt()
    end,
  })

  local attach_keys = { 'a', 'c', 'm', 'l', 'y', 'u', 'b', 'n', 'z', 'o', 'O', 'f', 'F', 'd', 'D', 's', 'S' }
  for _, key in ipairs(attach_keys) do
    Attach[key] = function()
      return orgmode.agenda:open_by_key(key)
    end
  end

  return Attach
end

---@param orgmode Org
local build = function(orgmode)
  local config = require('orgmode.config')

  local OrgGlobal = {
    help = function()
      vim.cmd(('tabnew %s'):format(('%s/%s'):format(docs_dir, 'index.org')))
      vim.cmd(('tcd %s'):format(docs_dir))
    end,

    helpgrep = function()
      orgmode.agenda:open_view('search', {
        agenda_files = ('%s/**/*'):format(docs_dir),
      })
    end,

    install_treesitter_grammar = function()
      local installed = require('orgmode.config'):install_grammar()
      if not installed then
        local choice =
          vim.fn.confirm('Treesitter grammar is already installed. Do you want to re-install it?', '&Yes\n&No', 2)
        if choice == 1 then
          return require('orgmode.config'):reinstall_grammar()
        end
      end
    end,

    agenda = generate_agenda_object(orgmode, config),
    capture = generate_capture_object(orgmode, config),

    store_link = function()
      ---@type OrgHeadline | nil
      local headline = nil
      if vim.bo.filetype == 'orgagenda' then
        headline = orgmode.agenda:get_headline_at_cursor()
      elseif vim.bo.filetype == 'org' then
        headline = orgmode.files:get_current_file():get_closest_headline_or_nil()
      end
      if not headline then
        require('orgmode.utils').echo_error('No headline found')
        return
      end
      headline.file
        :update(function()
          orgmode.links:store_link_to_headline(headline)
        end)
        :wait()
      return require('orgmode.utils').echo_info('Stored: ' .. headline:get_title())
    end,
    indent_mode = function()
      require('orgmode.ui.virtual_indent').toggle_buffer_indent_mode()
    end,

    attach = generate_attach_object(orgmode, config),
  }

  _G.Org = OrgGlobal
end

---@param opts string[]
---@return table
local function resolve_item(opts)
  ---@type table
  local obj = _G.Org
  for _, opt in ipairs(opts) do
    if type(obj) ~= 'table' then
      return obj
    end
    if obj[opt] then
      obj = obj[opt]
    end
  end

  return obj
end

vim.api.nvim_create_user_command('Org', function(opts)
  local item = resolve_item(opts.fargs)
  if item and (type(item) == 'function' or (getmetatable(item) and getmetatable(item).__call)) then
    return item()
  end
  require('orgmode.utils').echo_error(('Invalid command "Org %s"'):format(opts.args))
end, {
  nargs = '+',
  complete = function(arg_lead, cmd_line)
    local opts = vim.split(cmd_line:sub(5), '%s+')
    local item = resolve_item(opts)
    if type(item) ~= 'table' then
      return {}
    end
    local list = vim.tbl_keys(item)

    if arg_lead == '' then
      return list
    end
    return vim.fn.matchfuzzy(list, arg_lead)
  end,
})

return build
