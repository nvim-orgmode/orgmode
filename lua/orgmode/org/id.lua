local config = require('orgmode.config')
local utils = require('orgmode.utils')

local OrgId = {
  uuid_pattern = '%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x',
}

---@return string
function OrgId.new()
  return OrgId._generate()
end

---@return boolean
function OrgId.is_valid_uuid(value)
  if not value or vim.trim(value) == '' then
    return false
  end

  return value:match(OrgId.uuid_pattern) ~= nil
end

---@private
---@return string
function OrgId._generate()
  if config.org_id_method == 'uuid' then
    if vim.fn.executable(config.org_id_uuid_program) ~= 1 then
      utils.echo_error('org_id_uuid_program is not executable: ' .. config.org_id_uuid_program)
      return ''
    end
    return tostring(vim.fn.system(config.org_id_uuid_program):gsub('%s+', ''))
  end

  if config.org_id_method == 'ts' then
    return tostring(os.date(config.org_id_ts_format))
  end

  if config.org_id_method == 'org' then
    math.randomseed(os.clock() * 100000000000)
    return ('%s%s'):format(vim.trim(config.org_id_prefix or ''), math.random(100000000000000))
  end

  utils.echo_error('Invalid org_id_method: ' .. config.org_id_method)
  return ''
end

return OrgId
