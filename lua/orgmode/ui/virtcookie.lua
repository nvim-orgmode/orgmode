local org = require('orgmode')

---@alias OrgVirtCookieType '/' | '%' The type of cookie to default to when no "real" cookie exists

---@class OrgVirtCookie Updates Headline Cookies for Progress using Virtual Text
---@field private bufnr integer Buffer Watcher is attached to
---@field private attached boolean Whether the watcher is running
---@field private cookie_type OrgVirtCookieType
---@field private ns_id integer
local OrgVirtCookie = {
  ns_id = vim.api.nvim_create_namespace('orgmode.ui.cookie'),
}

---@alias OrgCookieWatchers table<integer, OrgVirtCookie> A mapping of buffer ids to watchers

---@type OrgCookieWatchers
local watchers = {}

---Get all currently registered cookie watchers
---@return OrgCookieWatchers
function OrgVirtCookie.watchers()
  return watchers
end

---Gets an existing OrgCookieWatcher for the given buffer if it exists
---@param bufnr? integer Buffer to get the watcher for
---@return OrgVirtCookie?
function OrgVirtCookie.get(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local watcher = OrgVirtCookie.watchers()[bufnr]
  return watcher
end

---Creates a new headline watcher
---@param bufnr? integer Buffer to watch, if unspecified then uses the current buffer
---@param cookie_type? OrgVirtCookieType
function OrgVirtCookie.new(bufnr, cookie_type)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local watcher = OrgVirtCookie.get(bufnr)
  if watcher then
    return watcher
  end
  local this = setmetatable({
    bufnr = bufnr,
    attached = false,
    cookie_type = cookie_type or '/',
  }, { __index = OrgVirtCookie })
  watchers[this.bufnr] = this

  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = this.bufnr,
    callback = function()
      this:delete()
      return true
    end,
  })

  return watchers[this.bufnr]
end

---@param new_cookie_type OrgVirtCookieType
function OrgVirtCookie:set_cookie_type(new_cookie_type)
  if not vim.list_contains({ '%', '/' }, new_cookie_type) then
    error(("Invalid cookie type provided, got '%s', expected one of '%%' or '/'"):format(new_cookie_type))
  end
  self.cookie_type = new_cookie_type
  self:redraw()
end

---@return OrgVirtCookieType
function OrgVirtCookie:get_cookie_type()
  return self.cookie_type
end

function OrgVirtCookie:toggle_cookie_type()
  self.cookie_type = (self.cookie_type == '/') and '%' or '/'
  self:redraw()
end

---@param headline OrgHeadline
---@return OrgHeadline[]
function OrgVirtCookie._parent_headlines(headline)
  local located_headlines = {}
  local count = 0
  while true do
    count = count + 1
    local parent = headline:get_parent_headline()

    if not parent or not parent.headline then
      break
    end

    table.insert(located_headlines, parent)
    headline = parent
  end
  return located_headlines
end

---@param start_line integer 0-indexed inclusive
---@param end_line integer 0-indexed inclusive
function OrgVirtCookie:_del_extmarks(start_line, end_line)
  local old_extmarks = vim.api.nvim_buf_get_extmarks(
    self.bufnr,
    self.ns_id,
    { start_line, 0 },
    { end_line, -1 },
    { overlap = true }
  )
  for _, ext in ipairs(old_extmarks) do
    vim.api.nvim_buf_del_extmark(self.bufnr, self.ns_id, ext[1])
  end
end

---@param complete integer
---@param total integer
---@param cookie_type OrgVirtCookieType
---@return [string, string]
function OrgVirtCookie._build_cookie_virt_text(complete, total, cookie_type)
  ---@type [string, string]
  local virt_text = {}
  -- Now we build up our virtual cookie
  table.insert(virt_text, { '[', '@org.cookie.delimiter.left' })
  if cookie_type == '%' then
    -- Handling a percentage cookie, e.g. [90%]
    local num = ('%.0f'):format(((complete / total) * 100))
    table.insert(virt_text, { num, '@org.cookie.number' })
    table.insert(virt_text, { '%', '@org.cookie.sign.percent' })
  else
    -- Handling an out of cookie, e.g. [10/12]
    table.insert(virt_text, { tostring(complete), '@org.cookie.number.complete' })
    table.insert(virt_text, { '/', '@org.cookie.sign.div' })
    table.insert(virt_text, { tostring(total), '@org.cookie.number.total' })
  end
  table.insert(virt_text, { ']', '@org.cookie.delimiter.right' })
  return virt_text
end

---@param headline OrgHeadline
function OrgVirtCookie:_set_virt_cookie(headline)
  ---@type OrgVirtCookieType
  local cookie_type = self.cookie_type
  ---@type 'eol' | 'inline'
  local virt_text_pos = 'eol'
  local start_line, start_col
  local end_line, end_col

  local cookie = headline:get_cookie()
  if cookie then
    -- If we have a "real" cookie we want to place the virtual cookie on top of the existing cookie
    start_line, start_col, _ = cookie:start()
    end_line, end_col, _ = cookie:end_()
    virt_text_pos = 'inline'
    if headline.file:get_node_text(cookie):find('%%') then
      cookie_type = '%'
    else
      cookie_type = '/'
    end
  else
    -- If we don't have a "real" cookie then we'll set the virtual cookie on the headline
    start_line, _, _ = headline:node():start()
    end_line, _, _ = headline:node():end_()
    local _, tag_node = headline:get_own_tags()
    if tag_node then
      -- If the current headline has some of its own tags then we want to put the cookie in front of
      -- the tags and after the headline title
      _, start_col = tag_node:range()
      virt_text_pos = 'inline'
    end
  end

  -- We preference checkboxes for the count, then todos, and if we have neither but still have a
  -- cookie then we want to show an indication of missing items
  local chk_complete, chk_total = unpack(headline:_get_checkbox_progress() or { 0, 0 })
  local todo_complete, todo_total = unpack(headline:_get_todo_progress() or { 0, 0 })
  local complete = chk_complete + todo_complete
  local total = chk_total + todo_total
  if total == 0 then
    -- If we have no items to calculate the cookie based on, we want to ensure the current headline
    -- doesn't have a virtual cookie before returning (not setting a virtual cookie)
    self:_del_extmarks(start_line, end_line)
    return
  end

  local virt_text = self._build_cookie_virt_text(complete, total, cookie_type)
  -- In the scenario where we're trying to put a virtual cookie after the title but before the tags,
  -- we need to pad with a space to the right to keep some whitespace between the virtual cookie and
  -- the tags
  if not cookie and start_col then
    table.insert(virt_text, { ' ' })
  end

  -- Ensure we wipe out the old extmark(s) before setting the new one(s)
  self:_del_extmarks(start_line, end_line)

  -- The virtual cookie text we put in place
  vim.api.nvim_buf_set_extmark(self.bufnr, self.ns_id, start_line, start_col or -1, {
    virt_text_pos = virt_text_pos,
    hl_mode = 'combine',
    virt_text = virt_text,
  })

  if cookie then
    -- This ensures the user can see the _actual_ cookie as well as the virtual cookie when relevant
    vim.api.nvim_buf_set_extmark(self.bufnr, self.ns_id, start_line, start_col, {
      hl_mode = 'combine',
      end_col = end_col,
      conceal = '',
    })
  end
end

---@param start_line integer 0-index row to start from
---@param end_line integer 0-index row to end at
function OrgVirtCookie:_update_cookies_in_range(start_line, end_line)
  ---@type table<integer, OrgHeadline>
  local modified_headlines = {}
  for line = start_line, end_line, 1 do
    local success, headline = pcall(org.files.get_closest_headline, org.files, { line + 1, 0 })
    if headline and success then
      local headline_row, _, _ = headline:node():start()
      modified_headlines[headline_row] = headline
    end
  end
  for _, headline in pairs(modified_headlines) do
    self:_set_virt_cookie(headline)
    local parents = OrgVirtCookie._parent_headlines(headline)
    for _, parent in ipairs(parents) do
      self:_set_virt_cookie(parent)
    end
  end
end

---Get whether the watcher is currently attached
---@return boolean
function OrgVirtCookie:is_attached()
  return self.attached
end

---Get the registered buffer id for the watcher
---@return integer
function OrgVirtCookie:get_bufnr()
  return self.bufnr
end

---Starts the watcher for the watcher's buffer if it's not already attached
function OrgVirtCookie:attach()
  if self.attached then
    return
  end
  self.attached = true
  vim.b[self.bufnr].org_cookie_mode = true
  vim.b[self.bufnr].org_cookie_type = self.cookie_type

  watchers[self.bufnr] = self
  self:_update_cookies_in_range(0, vim.api.nvim_buf_line_count(self.bufnr) - 1)

  -- We cant use  `nvim_set_decoration_provider()` here because of a
  -- `org.files.get_closest_headline` call made later "modifies" (reloads) some content which
  -- causes the decoration provider to explode.
  --
  -- There's a way around this by playing entirely with the TS Nodes, but this seems fast enough
  -- so it'll do.
  vim.api.nvim_buf_attach(self.bufnr, false, {
    on_lines = function(_, _, _, start_line, _, end_line)
      if not self.attached then
        return true
      end

      vim.schedule(function()
        if start_line > 0 then
          -- Sometimes we miss the outer range, so we want to ensure we grab that in those
          -- scenarios
          start_line = start_line - 1
        end
        self:_update_cookies_in_range(start_line, end_line)
      end)
    end,
    on_reload = function()
      self:_update_cookies_in_range(0, vim.api.nvim_buf_line_count(self.bufnr) - 1)
    end,
    on_detach = function()
      self:delete()
    end,
  })
end

---Detaches the watcher if it's attached
function OrgVirtCookie:detach()
  if not self.attached then
    return
  end
  self.attached = false
  vim.b[self.bufnr].org_cookie_mode = false
  vim.api.nvim_buf_clear_namespace(self.bufnr, self.ns_id, 0, -1)
end

---Redraws all virtual cookies for the buffer if it's currently attached
function OrgVirtCookie:redraw()
  if self.attached then
    self:detach()
    self:attach()
  end
end

---Toggles the attached state for the watcher
function OrgVirtCookie:toggle()
  if self.attached then
    self:detach()
  else
    self:attach()
  end
end

---Completely removes the watcher, including from tracked watchers
function OrgVirtCookie:delete()
  self:detach()
  watchers[self.bufnr] = nil
end

return OrgVirtCookie
