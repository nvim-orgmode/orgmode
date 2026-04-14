local config = require('orgmode.config')
local Async = require('orgmode.utils.async')
local utils = require('orgmode.utils')

---@class OrgInput
local OrgInput = {}

---@param prompt string
---@param default? string
---@param completion? string | fun(arg_lead: string): string[]
---@return OrgTask
function OrgInput.open(prompt, default, completion)
  _G.orgmode.__input_completion = completion
  local opts = {
    prompt = prompt,
    default = default or '',
  }
  if type(completion) == 'string' then
    opts.completion = completion
  elseif completion then
    opts.completion = 'customlist,v:lua.orgmode.__input_completion'
  end

  return Async.run(function()
    if config.ui.input.use_vim_ui then
      local value = Async.await(2, vim.ui.input, opts)
      if value == nil then
        utils.echo_error('Input canceled')
        return nil
      end
      return value
    end

    opts.cancelreturn = vim.NIL
    local value = vim.fn.input(opts)
    if value == vim.NIL then
      utils.echo_error('Input canceled')
      return nil
    end
    return value
  end)
end

return OrgInput
