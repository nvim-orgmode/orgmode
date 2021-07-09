local utils = require('orgmode.utils')

---@class Export
local Export = {}

function Export.prompt()
  return utils.menu('Export command', {
    { label = '', separator = '-', length = 34 },
    { label = 'Export to HTML file', key = 'h', action = function() return Export.format('org-html-export-to-html', 'html') end },
    { label = 'Export to LaTex file', key = 'l', action = function() return Export.format('org-latex-export-to-latex', 'tex') end },
    { label = 'Export to LaTeX and convert to PDF file', key = 'p', action = function() return Export.format('org-latex-export-to-pdf', 'pdf') end },
    { label = 'Export to LaTex file (Beamer)', key = 'L', action = function() return Export.format('org-beamer-export-to-latex', 'tex') end },
    { label = 'Export to LaTeX and convert to PDF file (Beamer)', key = 'P', action = function() return Export.format('org-beamer-export-to-pdf', 'pdf') end },
    { label = 'Export to Markdown file', key = 'm', action = function() return Export.format('org-md-export-to-markdown', 'md') end },
    { label = 'Export to iCalendar file', key = 'i', action = function() return Export.format('org-icalendar-export-to-ics', 'ics') end },
    { label = 'Quit', key = 'q' },
    { label = '', separator = ' ', length = 1 },
  }, 'Export command')
end

function Export.format(format, extension)
  local file = vim.api.nvim_buf_get_name(0)
  local target = vim.fn.fnamemodify(file, ':p:r')..'.'..extension
  if vim.fn.executable('emacs') ~= 1 then
    return utils.echo_error('emacs executable not found. Make sure emacs is in $PATH.')
  end
  local output = {}
  local read_data = function(_, data, _)
    for _, i in ipairs(data) do
      if i and i ~= '' then
        table.insert(output, i)
      end
    end
  end
  vim.fn.jobstart({
    'emacs',
    '-nw',
    '--batch',
    string.format('--visit=%s', file),
    string.format('--funcall=%s', format)
  }, {
    on_stdout = read_data,
    on_stderr = read_data,
    on_exit = function(_, code, _)
      if code ~= 0 then
        table.insert(output, '')
        table.insert(output, 'NOTE: Exports are completely handled by emacs. Any error that occurs is most likely an issue with emacs configuration.')
        return utils.echo_error(string.format('Export error:\n%s', table.concat(output, '\n')))
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
