local create_client = require(script.Parent.client)
local create_roblox_adapter = require(script.Parent.adapters.roblox)

local Sonoran = {}

function Sonoran.createClient(config)
  return create_client(config or {}, create_roblox_adapter(game:GetService("HttpService")))
end

return Sonoran
