local create_client = dofile("lua/sonoran/client.lua")
local last_request
local client = create_client({ product = 0, communityId = "test-community", apiKey = "test-key" }, {
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

assert(client.cad:getPermissionCatalogV2().success)
assert(last_request.method == "GET")
assert(last_request.url == "https://api.sonorancad.com/v2/general/permissions/catalog")
assert(last_request.headers.Authorization == "Bearer test-key")
assert(client.cad:getAccountPermissionsV2("account/uuid").success)
assert(last_request.method == "GET")
assert(last_request.url == "https://api.sonorancad.com/v2/general/permissions/accounts/account%2Fuuid")
assert(client.cad:replaceAccountPermissionsV2("account-uuid", { "global.police" }).success)
assert(last_request.method == "PUT")
assert(last_request.body.json.version == 2)
assert(last_request.body.json.grants[1] == "global.police")
assert(client.cad:replaceAccountPermissionsV2("account-uuid", {}).success)
assert(last_request.method == "PUT")
assert(last_request.headers["Content-Type"] == "application/json")
assert(last_request.body == '{"version":2,"grants":[]}')
assert(not pcall(function() client.cad:replaceAccountPermissionsV2("account", nil) end))
assert(not pcall(function() client.cad:replaceAccountPermissionsV2("account", { police = true }) end))
assert(not pcall(function() client.cad:replaceAccountPermissionsV2("account", { 1 }) end))
print("All Sonoran.lua granular permission tests passed.")
