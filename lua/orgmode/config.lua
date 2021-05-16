local instance = {}
local Config = {}

local defaults = {
  week_start_day = 'Monday',
  org_agenda_files = '',
  org_default_notes_file = '',
  org_todo_keywords = {'TODO', 'NEXT', 'DONE'}
}

function Config:new(opts)
  opts = opts or {}
  local data = vim.tbl_extend('force', defaults, opts)
  setmetatable(data, self)
  self.__index = self
  return data
end

function Config:extend(opts)
  instance = self:new(vim.tbl_extend('force', self, opts or {}))
  return instance
end

function Config:get_all_files()
  if not self.org_agenda_files or self.org_agenda_files == '' then
    return {}
  end
  return vim.fn.glob(vim.fn.fnamemodify(self.org_agenda_files, ':p'), 0, 1)
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

instance = Config:new()
return instance
