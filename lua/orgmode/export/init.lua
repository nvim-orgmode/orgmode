local utils = require('orgmode.utils')
local config = require('orgmode.config')

---@class Export
local Export = {}

function Export.prompt()
  local submenu = function(key, label, org_cmd, extension, additional_opts)
    return {
      label = label,
      key = key,
      action = function()
        local opts = {
          { label = '', separator = '-', length = 34 },
          { label = string.format('emacs (%s)', org_cmd), key = 'e', action = function() return Export.emacs(org_cmd, extension) end}
        }
        if additional_opts then
          opts = utils.concat(opts, additional_opts)
        end
        table.insert(opts, { label = 'pandoc', key = 'p', action = function() return Export.pandoc(extension) end})
        table.insert(opts, { label = 'Quit', key = 'q'})

        return utils.menu(label..' via', opts, label..' via')
      end,
    }
  end

  local opts = {
    { label = '', separator = '-', length = 34 },
    submenu('h', 'Export to HTML file (emacs/pandoc)', 'org-html-export-to-html', 'html'),
    submenu('l', 'Export to LaTex file (emacs/pandoc)', 'org-latex-export-to-latex', 'tex', {
      { label = 'emacs beamer (org-beamer-export-to-latex)', key = 'b', action = function() return Export.emacs('org-beamer-export-to-latex', 'tex') end}
    }),
    submenu('p', 'Export to PDF file (emacs/pandoc)', 'org-latex-export-to-pdf', 'pdf', {
      { label = 'emacs beamer (org-beamer-export-to-pdf)', key = 'b', action = function() return Export.emacs('org-beamer-export-to-pdf', 'pdf') end}
    }),
    { label = 'Export to Markdown file (emacs)', key = 'm', action = function() return Export.emacs('org-md-export-to-markdown', 'md') end },
    { label = 'Export to iCalendar file (emacs)', key = 'i', action = function() return Export.emacs('org-icalendar-export-to-ics', 'ics') end },
  }

  if not vim.tbl_isempty(config.org_custom_exports) then
    for key, data in pairs(config.org_custom_exports) do
      table.insert(opts, {
        key = key,
        label = data.label,
        action = function() return data.action(Export._exporter) end
      })
    end
  end

  table.insert(opts, { label = 'Quit', key = 'q' })
  table.insert(opts, { label = '', separator = ' ', length = 1 })

  return utils.menu('Export options', opts, 'Export command')
end

---@param extension string
function Export.pandoc(extension)
  local file = vim.api.nvim_buf_get_name(0)
  local target = vim.fn.fnamemodify(file, ':p:r')..'.'..extension
  if vim.fn.executable('pandoc') ~= 1 then
    return utils.echo_error('pandoc executable not found. Make sure pandoc is in $PATH.')
  end

  return Export._exporter({'pandoc', file, '-o', target }, target)
end

---@param format string
---@param extension string
function Export.emacs(format, extension)
  local file = vim.api.nvim_buf_get_name(0)
  local target = vim.fn.fnamemodify(file, ':p:r')..'.'..extension
  if vim.fn.executable('emacs') ~= 1 then
    return utils.echo_error('emacs executable not found. Make sure emacs is in $PATH.')
  end

  local cmd = {
    'emacs',
    '-nw',
    '--batch',
    string.format('--visit=%s', file),
    string.format('--funcall=%s', format)
  }

  return Export._exporter(cmd, target, nil, function(err)
    table.insert(err, '')
    table.insert(err, 'NOTE: Emacs export issues are most likely caused by bad or missing emacs configuration.')
    return utils.echo_error(string.format('Export error:\n%s', table.concat(err, '\n')))
  end)
end

---@param cmd table
---@param on_success function
---@param on_error function
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

      return utils.menu(string.format('Exported to %s', target), {
        { label = '', separator = '-', length = 34 },
        { label = 'Yes', key = 'y', action = function() return utils.open(target) end },
        { label = 'No', key = 'n'},
      }, 'Open')
    end,
  })
end

return Export
