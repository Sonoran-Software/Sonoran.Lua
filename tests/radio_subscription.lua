local create_client = dofile("lua/sonoran/client.lua")

local last_request
local adapter = {
  encode = function(value) return value end,
  decode = function(value)
    assert(value == "subscription-response", "unexpected response body")
    return { subscription = 2 }
  end,
  encodeURIComponent = function(value) return tostring(value) end,
  request = function(options)
    last_request = options
    return {
      ok = true,
      status = 200,
      headers = { ["content-type"] = "application/json" },
      body = "subscription-response"
    }
  end
}

local client = create_client({
  product = 2,
  apiKey = "radio-key",
  communityId = "radio-community",
  apiUrl = "https://api.sonoranradio.com/",
  timeoutMs = 12345
}, adapter)

local response = client.radio:getServerSubscriptionV2()
assert(response.success == true, "subscription request failed")
assert(response.data.subscription == 2, "unexpected subscription level")
assert(last_request.method == "GET", "unexpected request method")
assert(last_request.url == "https://api.sonoranradio.com/v2/servers/radio-community/subscription", "unexpected request URL")
assert(last_request.headers.Authorization == "Bearer radio-key", "missing authorization header")
assert(last_request.timeoutMs == 12345, "unexpected request timeout")

print("Radio subscription request mapping test passed.")
