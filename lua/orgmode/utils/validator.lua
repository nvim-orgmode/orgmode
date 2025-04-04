local M = {}

local has_v_0_11 = vim.fn.has('nvim-0.11') > 0

--- @alias OrgValidateValidor
--- | type
--- | 'callable'
--- | (type|'callable')[]
--- | fun(v:any):boolean, string?

--- @param name string Argument name
--- @param value any Argument value
--- @param validator OrgValidateValidor
--- @param optional? boolean
function M.validate(name, value, validator, optional)
  if has_v_0_11 then
    return vim.validate(name, value, validator, optional)
  else
    local val = { value, validator }
    if optional then
      table.insert(val, optional)
    end
    return vim.validate({ [name] = val })
  end
end

return M
