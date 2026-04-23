local create_client = require(script.Parent.client)
local create_roblox_adapter = require(script.Parent.adapters.roblox)

local Sonoran = {}
Sonoran.productEnums = {
  CAD = 0,
  CMS = 1,
  RADIO = 2
}
Sonoran.logLevels = {
  OFF = "OFF",
  DEBUG = "DEBUG"
}

function Sonoran.createClient(config)
  return create_client(config or {}, create_roblox_adapter(game:GetService("HttpService")))
end

return Sonoran
