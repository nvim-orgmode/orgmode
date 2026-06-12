---@class OrgCaptureOpenedEvent: OrgEvent
---@field window OrgCaptureWindow
---@field content string[]
local CaptureOpened = {
  type = 'orgmode.capture_opened',
}
CaptureOpened.__index = CaptureOpened

---@param opts { window: OrgCaptureWindow, content: string[]}
function CaptureOpened:new(opts)
  return setmetatable({
    window = opts.window,
    content = opts.content,
  }, self)
end

return CaptureOpened
