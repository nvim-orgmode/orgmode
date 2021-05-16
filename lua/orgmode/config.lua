local Config = {}

local defaults = {
  week_start_day = 'Monday'
}

function Config:new(opts)
  opts = opts or {}
  local data = vim.tbl_extend('force', defaults, opts)
  setmetatable(data, self)
  self.__index = self
  return data
end

function Config:get_week_start_day_number()
  if self.week_start_day == 'Monday' then
    return 2
  end
  return 1
end

function Config:get_week_end_day_number()
  if self.week_start_day == 'Monday' then
    return 1
  end
  return 7
end

return Config
