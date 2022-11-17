local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local utils = require('orgmode.utils')
local diagnostic_ns = vim.api.nvim_create_namespace('org_diagnostics')

---@return table[]|nil|boolean
local function get_errors()
  if not config.diagnostics then
    return false
  end

  local file = Files.get_current_file()
  if not file then
    return nil
  end

  local errors = file:get_errors()
  if not errors then
    return {}
  end

  return vim.tbl_map(function(error)
    local err = error.err
    local start_line, start_col, end_line, end_col = err.node:range()
    return {
      lnum = start_line,
      end_lnum = end_line,
      col = start_col,
      end_col = end_col,
      severity = vim.diagnostic.severity.ERROR or 'Error',
      source = 'always',
      message = string.format('Error on text "%s"', err.text),
    }
  end, errors)
end

local function report_errors()
  local errors = get_errors()
  if errors == false or errors == nil then
    return
  end

  return vim.diagnostic.set(diagnostic_ns, vim.api.nvim_get_current_buf(), errors)
end

local function print_errors()
  local errors = get_errors()
  if errors == false then
    return utils.echo_info('Diagnostics are disabled in the configuration.')
  end

  if errors == nil then
    return utils.echo_error(
      'Current file not found in the Orgmode state. Try saving and reloading the file with command ":edit!".'
    )
  end

  if #errors == 0 then
    return utils.echo_info('No errors.')
  end
  local msg = vim.tbl_map(function(err)
    return string.format('%s, Line %d, col %d', err.message, err.lnum + 1, err.col + 1)
  end, errors)
  return utils.echo_error(msg)
end

return {
  report = report_errors,
  print = print_errors,
}
