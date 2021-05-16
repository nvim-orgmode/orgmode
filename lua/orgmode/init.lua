local Config = require('orgmode.config')
local config = Config:new()

local function setup(opts)
  config = Config:new(opts)
end

return {
  setup = setup,
  config = config
}
