---@class OrgCaptureFinishedEvent: OrgEvent
---@field window OrgCaptureWindow
---@field content string[]
local CaptureFinished = {
  type = 'orgmode.capture_opened',
}
CaptureFinished.__index = CaptureFinished

---@param opts { window: OrgCaptureWindow, content: string[]}
function CaptureFinished:new(opts)
  return setmetatable({
    window = opts.window,
    content = opts.content,
  }, self)
end

return CaptureFinished
