local M = {}

local has_v_0_11 = vim.fn.has('nvim-0.11') > 0

--- Use the faster validate version if available
-- Taken from: https://github.com/lukas-reineke/indent-blankline.nvim/pull/934/files#diff-09ebcaa8c75cd1e92d25640e377ab261cfecaf8351c9689173fd36c2d0c23d94R16
--- @param spec table<string,[any, vim.validate.Validator, boolean|string]>
function M.validate(spec)
  if not has_v_0_11 then
    return vim.validate(spec)
  end
  for key, key_spec in pairs(spec) do
    local message = type(key_spec[3]) == 'string' and key_spec[3] or nil --[[@as string?]]
    local optional = type(key_spec[3]) == 'boolean' and key_spec[3] or nil --[[@as boolean?]]
    ---@diagnostic disable-next-line:param-type-mismatch, redundant-parameter
    vim.validate(key, key_spec[1], key_spec[2], optional, message)
  end
end

return M
