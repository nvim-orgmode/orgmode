local Date = require('orgmode.objects.date')
local Agenda = {}


function Agenda:new(opts)
  opts = opts or {}
  local data = {
    files = opts.files or {}
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Agenda:open()
  local dates = Date.now():get_range_until(Date.now():add({ day = 7 }))
  local content = { 'Span: week' }
  for _, date in ipairs(dates) do
    local d = date:format('%A %d %B %Y')
    local is_today = date:is_today()
    if is_today then
      d = d..' [Today]'
    end
    table.insert(content, d)
    for _, orgfile in pairs(self.files) do
      if is_today then
      else
      end
      local headlines = orgfile:find_headlines_for_date(date)
      for _, headline in ipairs(headlines) do
        local priority_date = headline:get_priority_date(date)
        local date_label = priority_date.date:humanize(date)
        if priority_date:is_deadline(date) then
          date_label = 'Deadline'
        elseif priority_date:is_scheduled(date) then
          date_label = 'Scheduled'
        elseif date_label == 'Today' then
          date_label = ''
        end
        local tags = ''
        if #headline.tags > 0 then
          tags = ':'..table.concat(headline.tags, ':')..':'
        end
        local line = string.format(
          '%s: %s: %s %s %s',
          orgfile:get_category(headline),
          date_label,
          headline.todo_keyword,
          headline.title,
          tags
        )
        table.insert(content, line)
      end
    end
  end

  vim.cmd('pedit '..vim.fn.tempname())
  vim.cmd[[wincmd p]]
  vim.bo.modifiable = true
  vim.api.nvim_buf_set_lines(0, 0, -1, true, content)
  vim.bo.modified = false
  vim.bo.modifiable = false
end

return Agenda
