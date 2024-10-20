local utils = require('orgmode.utils')
local config = require('orgmode.config')
local Menu = require('orgmode.ui.menu')

---@class OrgExport
local Export = {}

---@param cmd table
---@param on_success? function
---@param on_error? function
function Export._exporter(cmd, target, on_success, on_error)
  utils.echo_info('Exporting...')
  local output = {}
  local read_data = function(_, data, _)
    for _, i in ipairs(data) do
      if i and i ~= '' then
        table.insert(output, i)
      end
    end
  end
  vim.fn.jobstart(cmd, {
    on_stdout = read_data,
    on_stderr = read_data,
    on_exit = function(_, code, _)
      if code ~= 0 then
        if on_error then
          return on_error(output)
        end
        return utils.echo_error(string.format('Export error:\n%s', table.concat(output, '\n')))
      end

      if on_success then
        return on_success(output)
      end

      local menu = Menu:new({
        title = string.format('Exported to %s', target),
        prompt = 'Open?',
      })
      menu:add_separator({ length = 34 })
      menu:add_option({
        label = 'Yes',
        key = 'y',
        action = function()
          return utils.open(target)
        end,
      })
      menu:add_option({ label = 'No', key = 'n' })
      return menu:open()
    end,
  })
end

---@param opts table
function Export.pandoc(opts)
  local file = utils.current_file_path()
  local target = vim.fn.fnamemodify(file, ':p:r') .. '.' .. opts.extension
  if vim.fn.executable('pandoc') ~= 1 then
    return utils.echo_error('pandoc executable not found. Make sure pandoc is in $PATH.')
  end

  local cmd = { 'pandoc', file, '-o', target }
  if opts.format then
    table.insert(cmd, '-t')
    table.insert(cmd, opts.format)
  end

  return Export._exporter(cmd, target)
end

---@param opts table
function Export.emacs(opts)
  local file = utils.current_file_path()
  local target = vim.fn.fnamemodify(file, ':p:r') .. '.' .. opts.extension
  local emacs = config.emacs_config.executable_path
  local emacs_config_path = config.emacs_config.config_path
  if vim.fn.executable(emacs) ~= 1 then
    return utils.echo_error('emacs executable not found. Make sure emacs is in $PATH.')
  end

  local cmd = {
    emacs,
    '-nw',
    '--batch',
    '--load',
    emacs_config_path,
    string.format('--visit=%s', file),
    string.format('--funcall=%s', opts.command),
  }

  return Export._exporter(cmd, target, nil, function(err)
    table.insert(err, '')
    table.insert(err, 'NOTE: Emacs export issues are most likely caused by bad or missing emacs configuration.')
    return utils.echo_error(string.format('Export error:\n%s', table.concat(err, '\n')))
  end)
end

Export.emacs_beamer = Export.emacs

function Export.prompt()
  local keys = {
    emacs = 'e',
    emacs_beamer = 'b',
    pandoc = 'p',
  }

  local submenu = function(key, label, extension, exporters)
    local commands = {}

    local exporters_names = {}

    for name, opts in pairs(exporters) do
      table.insert(exporters_names, name)

      opts.extension = extension

      local exporter_label = name
      if opts.command then
        exporter_label = string.format('%s (%s)', name, opts.command)
      else
        exporter_label = name
      end

      table.insert(commands, {
        label = exporter_label,
        key = keys[name],
        action = function()
          return Export[name](opts)
        end,
      })
    end

    table.sort(commands, function(lhs, rhs)
      return lhs.label < rhs.label
    end)

    table.sort(exporters_names, function(lhs, rhs)
      return lhs < rhs
    end)

    local action
    if #commands > 1 then
      action = function()
        Menu:new({
          title = label .. ' via',
          items = commands,
          prompt = label .. ' via',
        }):open()
      end

      table.insert(commands, {
        label = 'quit',
        key = 'q',
      })
    else
      action = commands[1].action
    end

    return {
      label = string.format('%s (%s)', label, table.concat(exporters_names, '/')),
      key = key,
      action = action,
    }
  end

  local opts = {
    submenu('h', 'Export to HTML file', 'html', {
      emacs = {
        command = 'org-html-export-to-html',
      },
      pandoc = {},
    }),
    submenu('l', 'Export to LaTex file', 'tex', {
      emacs = {
        command = 'org-latex-export-to-latex',
      },
      emacs_beamer = {
        command = 'org-beamer-export-to-latex',
      },
      pandoc = {},
    }),
    submenu('p', 'Export to PDF file', 'pdf', {
      emacs = {
        command = 'org-latex-export-to-pdf',
      },
      emacs_beamer = {
        command = 'org-beamer-export-to-pdf',
      },
      pandoc = {},
    }),
    submenu('m', 'Export to Markdown file', 'md', {
      emacs = {
        command = 'org-md-export-to-markdown',
      },
      pandoc = {
        format = 'gfm',
      },
    }),
    submenu('i', 'Export to iCalendar file', 'ics', {
      emacs = {
        command = 'org-icalendar-export-to-ics',
      },
    }),
  }

  if not vim.tbl_isempty(config.org_custom_exports) then
    for key, data in pairs(config.org_custom_exports) do
      table.insert(opts, {
        key = key,
        label = data.label,
        action = function()
          return data.action(Export._exporter)
        end,
      })
    end
  end

  table.insert(opts, { label = 'quit', key = 'q' })
  table.insert(opts, { icon = ' ', length = 1 })

  return Menu:new({
    title = 'Export options',
    items = opts,
    prompt = 'Export command',
  }):open()
end

return Export
