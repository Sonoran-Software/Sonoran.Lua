local create_client = dofile("lua/sonoran/client.lua")
local last_request
local client = create_client({ product = 0, communityId = "test-community", apiKey = "test-key", defaultServerId = 7 }, {
  encode = function(value) return { json = value } end,
  decode = function() return {} end,
  encodeURIComponent = function(value)
    return tostring(value):gsub("([^%w%-%._~])", function(char)
      return string.format("%%%02X", string.byte(char))
    end)
  end,
  request = function(options)
    last_request = options
    return { ok = true, status = 200, headers = {}, body = "" }
  end
})

assert(client.cad:getFiveMConfigurationV2().success)
assert(last_request.method == "GET")
assert(last_request.url == "https://api.sonorancad.com/v2/fivem/servers/7/configuration")
assert(last_request.headers.Authorization == "Bearer test-key")
assert(client.cad:getFiveMConfigurationV2(2).success)
assert(last_request.url == "https://api.sonorancad.com/v2/fivem/servers/2/configuration")
assert(client.cad:acknowledgeFiveMConfigurationV2(nil, 4).success)
assert(last_request.method == "POST")
assert(last_request.url == "https://api.sonorancad.com/v2/fivem/servers/7/configuration/acknowledge/4")
assert(last_request.body == nil)
assert(not pcall(function() client.cad:acknowledgeFiveMConfigurationV2(7, 0) end))
assert(not pcall(function() client.cad:getFiveMConfigurationV2(0) end))
print("FiveM configuration tests passed")
