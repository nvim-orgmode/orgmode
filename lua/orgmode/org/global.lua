local current_file_path = string.sub(debug.getinfo(1, 'S').source, 2)
local docs_dir = vim.fn.fnamemodify(current_file_path, ':p:h:h:h:h') .. '/docs'

---@param orgmode Org
local build = function(orgmode)
  local Open = setmetatable({}, {
    __call = function(t, ...)
      t.a(...)
    end,
    __index = function(t, k)
      local existing = rawget(t, k)
      if existing then
        return existing
      end

      ---@diagnostic disable-next-line: invisible
      local keys = orgmode.agenda:_build_menu():get_valid_keys()

      for key, item in pairs(keys) do
        t[key] = item.action
      end

      return rawget(t, k)
    end,
  })

  for _, shortcut in ipairs({ 'a', 't', 'm', 'M', 's' }) do
    Open[shortcut] = function()
      return orgmode.agenda:open_by_key(shortcut)
    end
  end

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

    open = Open,
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
  if item and type(item) == 'function' then
    return item()
  end
  require('orgmode.utils').echo_error(('Invalid command "Org %s"'):format(opts.args))
end, {
  nargs = '*',
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
