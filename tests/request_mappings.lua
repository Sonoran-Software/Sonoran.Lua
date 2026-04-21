local create_client = dofile("lua/sonoran/client.lua")

local product_enums = {
  CAD = 0,
  CMS = 1,
  RADIO = 2
}

local decode_map = {
  ["json:ok"] = { ok = true },
  ["json:error"] = { error = "bad request" }
}

local last_request
local next_response = {
  ok = true,
  status = 200,
  headers = {
    ["content-type"] = "application/json; charset=utf-8"
  },
  body = "json:ok"
}

local function encode_uri_component(value)
  return tostring(value):gsub("([^%w%-%._~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

local fake_adapter = {
  encode = function(value)
    return { __json = value }
  end,
  decode = function(value)
    local decoded = decode_map[value]
    if not decoded then
      error("Unexpected JSON payload: " .. tostring(value))
    end
    return decoded
  end,
  encodeURIComponent = encode_uri_component,
  sleep = function(ms)
    fake_adapter.last_sleep_ms = ms
  end,
  request = function(options)
    last_request = options
    if type(next_response) == "table" and next_response[1] ~= nil then
      return table.remove(next_response, 1)
    end

    return next_response
  end
}

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
  end
end

local function assert_contains(actual, expected, label)
  if type(actual) ~= "string" or not string.find(actual, expected, 1, true) then
    error(("%s: expected %s to contain %s"):format(label, tostring(actual), tostring(expected)))
  end
end

local function assert_truthy(value, label)
  if not value then
    error(label .. " should be truthy")
  end
end

local function assert_nil(value, label)
  if value ~= nil then
    error(label .. " should be nil")
  end
end

local function assert_at_least(actual, minimum, label)
  if actual < minimum then
    error(("%s: expected at least %s, got %s"):format(label, tostring(minimum), tostring(actual)))
  end
end

local function assert_deep_equal(actual, expected, label)
  if type(expected) ~= "table" then
    assert_equal(actual, expected, label)
    return
  end

  assert_truthy(type(actual) == "table", label .. " type")

  local expected_count = 0
  for key, value in pairs(expected) do
    expected_count = expected_count + 1
    assert_deep_equal(actual[key], value, label .. "." .. tostring(key))
  end

  local actual_count = 0
  for _ in pairs(actual) do
    actual_count = actual_count + 1
  end

  assert_equal(actual_count, expected_count, label .. " count")
end

local function assert_body(expected, label)
  if expected == nil then
    assert_nil(last_request.body, label .. " body")
    return
  end

  assert_truthy(last_request.body, label .. " body wrapper")
  local body = last_request.body.__json
  assert_truthy(body, label .. " body payload")
  assert_deep_equal(body, expected, label .. " body")
end

local function assert_response_shape(response, expect_success, label)
  assert_equal(response.success, expect_success, label .. " success")
  if expect_success then
    assert_equal(response.data.ok, true, label .. " data.ok")
  else
    assert_equal(response.reason.error, "bad request", label .. " reason.error")
  end
end

local client = create_client({
  product = product_enums.CAD,
  apiKey = "test-key",
  communityId = "community-123",
  apiUrl = "https://api.sonorancad.com/",
  defaultServerId = 3,
  headers = {
    ["X-Test"] = "yes"
  },
  timeoutMs = 12345
}, fake_adapter)

local missing_product_ok, missing_product_error = pcall(create_client, {
  apiKey = "test-key",
  communityId = "community-123"
}, fake_adapter)
assert_equal(missing_product_ok, false, "missing product should fail")
assert_contains(missing_product_error, "product is required when instancing.", "missing product error")

local unsupported_product_ok, unsupported_product_error = pcall(create_client, {
  product = product_enums.CMS,
  apiKey = "test-key",
  communityId = "community-123"
}, fake_adapter)
assert_equal(unsupported_product_ok, false, "unsupported product should fail")
assert_contains(unsupported_product_error, "Only productEnums.CAD and productEnums.RADIO are currently supported in Sonoran.lua.", "unsupported product error")

assert_truthy(type(client.cad) == "table", "cad namespace exists")
assert_truthy(client.cad ~= client, "cad namespace is distinct from root client")

local cases = {
  {
    name = "getLoginPageV2",
    invoke = function() return client.cad:getLoginPageV2({ url = "https://example.com/callback", communityId = "abc 123" }) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/general/login-page?communityId=abc%20123&url=https%3A%2F%2Fexample.com%2Fcallback",
    auth = false
  },
  {
    name = "checkApiIdV2",
    invoke = function() return client.cad:checkApiIdV2("api/id 123") end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/general/api-ids/api%2Fid%20123"
  },
  {
    name = "applyPermissionKeyV2",
    invoke = function() return client.cad:applyPermissionKeyV2({ apiId = "1", permissionKey = "pk" }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/permission-keys/applications",
    body = { apiId = "1", permissionKey = "pk" }
  },
  {
    name = "banUserV2",
    invoke = function() return client.cad:banUserV2({ apiId = "1", isBan = true }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/account-bans",
    body = { apiId = "1", isBan = true }
  },
  {
    name = "setPenalCodesV2",
    invoke = function() return client.cad:setPenalCodesV2({ "A", "B" }) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/general/penal-codes",
    body = { codes = { "A", "B" } }
  },
  {
    name = "setApiIdsV2",
    invoke = function() return client.cad:setApiIdsV2({ username = "u", apiIds = { "1", "2" } }) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/general/api-ids",
    body = { username = "u", apiIds = { "1", "2" } }
  },
  {
    name = "getTemplatesV2",
    invoke = function() return client.cad:getTemplatesV2(9) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/general/templates/9"
  },
  {
    name = "createRecordV2",
    invoke = function() return client.cad:createRecordV2({ apiId = "1", record = { id = 7 } }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/records",
    body = { apiId = "1", record = { id = 7 } }
  },
  {
    name = "updateRecordV2",
    invoke = function() return client.cad:updateRecordV2(77, { apiId = "1" }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/general/records/77",
    body = { apiId = "1" }
  },
  {
    name = "removeRecordV2",
    invoke = function() return client.cad:removeRecordV2(77) end,
    method = "DELETE",
    url = "https://api.sonorancad.com/v2/general/records/77"
  },
  {
    name = "sendRecordDraftV2",
    invoke = function() return client.cad:sendRecordDraftV2({ recordTypeId = 1, replaceValues = { a = "b" } }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/record-drafts",
    body = { recordTypeId = 1, replaceValues = { a = "b" } }
  },
  {
    name = "lookupV2",
    invoke = function() return client.cad:lookupV2({ first = "A", last = "B", mi = "", plate = "", types = { 1 } }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/lookups",
    body = { first = "A", last = "B", mi = "", plate = "", types = { 1 } }
  },
  {
    name = "lookupByValueV2",
    invoke = function() return client.cad:lookupByValueV2({ searchType = "plate", value = "ABC", types = { 1 } }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/lookups/by-value",
    body = { searchType = "plate", value = "ABC", types = { 1 } }
  },
  {
    name = "lookupCustomV2",
    invoke = function() return client.cad:lookupCustomV2({ map = "x", value = "y", types = { 2 } }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/lookups/custom",
    body = { map = "x", value = "y", types = { 2 } }
  },
  {
    name = "getAccountV2",
    invoke = function() return client.cad:getAccountV2({ username = "test user" }) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/general/accounts/account?username=test%20user"
  },
  {
    name = "getAccountsV2",
    invoke = function() return client.cad:getAccountsV2({ limit = 5, offset = 10, status = "ACTIVE", username = "foo" }) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/general/accounts?limit=5&offset=10&status=ACTIVE&username=foo"
  },
  {
    name = "createCommunityLinkV2",
    invoke = function() return client.cad:createCommunityLinkV2({ communityUserId = "u1" }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/links",
    body = { communityUserId = "u1" }
  },
  {
    name = "checkCommunityLinkV2",
    invoke = function() return client.cad:checkCommunityLinkV2({ communityUserId = "u1" }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/links/check",
    body = { communityUserId = "u1" }
  },
  {
    name = "setAccountPermissionsV2",
    invoke = function() return client.cad:setAccountPermissionsV2({ apiId = "1", add = { "A", "B" } }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/general/accounts/permissions",
    body = { apiId = "1", add = { "A", "B" } }
  },
  {
    name = "heartbeatV2",
    invoke = function() return client.cad:heartbeatV2(8, 24) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/servers/8/heartbeat",
    body = { playerCount = 24 }
  },
  {
    name = "getVersionV2",
    invoke = function() return client.cad:getVersionV2() end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/general/version"
  },
  {
    name = "getServersV2",
    invoke = function() return client.cad:getServersV2() end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/general/servers"
  },
  {
    name = "setServersV2",
    invoke = function() return client.cad:setServersV2({ { id = 1 } }, true) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/general/servers",
    body = { servers = { { id = 1 } }, deployMap = true }
  },
  {
    name = "verifySecretV2",
    invoke = function() return client.cad:verifySecretV2("secret") end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/secrets/verify",
    body = { secret = "secret" }
  },
  {
    name = "authorizeStreetSignsV2",
    invoke = function() return client.cad:authorizeStreetSignsV2(9) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/servers/9/street-sign-auth"
  },
  {
    name = "setPostalsV2",
    invoke = function() return client.cad:setPostalsV2({ { postal = "100" } }) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/general/postals",
    body = { postals = { { postal = "100" } } }
  },
  {
    name = "sendPhotoV2",
    invoke = function() return client.cad:sendPhotoV2({ apiId = "1", url = "https://img" }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/general/photos",
    body = { apiId = "1", url = "https://img" }
  },
  {
    name = "getInfoV2",
    invoke = function() return client.cad:getInfoV2() end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/general/info"
  },
  {
    name = "getCharactersV2",
    invoke = function() return client.cad:getCharactersV2({ apiId = "a1" }) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/civilian/characters?apiId=a1"
  },
  {
    name = "removeCharacterV2",
    invoke = function() return client.cad:removeCharacterV2(15) end,
    method = "DELETE",
    url = "https://api.sonorancad.com/v2/civilian/characters/15"
  },
  {
    name = "setSelectedCharacterV2",
    invoke = function() return client.cad:setSelectedCharacterV2({ characterId = "77", apiId = "a1" }) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/civilian/selected-character",
    body = { characterId = "77", apiId = "a1" }
  },
  {
    name = "getCharacterLinksV2",
    invoke = function() return client.cad:getCharacterLinksV2({ accountUuid = "uuid-1" }) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/civilian/character-links?accountUuid=uuid-1"
  },
  {
    name = "addCharacterLinkV2",
    invoke = function() return client.cad:addCharacterLinkV2("sync/id", { apiId = "a1" }) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/civilian/character-links/sync%2Fid",
    body = { apiId = "a1" }
  },
  {
    name = "removeCharacterLinkV2",
    invoke = function() return client.cad:removeCharacterLinkV2("sync/id", { apiId = "a1" }) end,
    method = "DELETE",
    url = "https://api.sonorancad.com/v2/civilian/character-links/sync%2Fid",
    body = { apiId = "a1" }
  },
  {
    name = "getUnitsV2",
    invoke = function() return client.cad:getUnitsV2({ includeOffline = true, onlyUnits = false, limit = 2, offset = 3 }) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/emergency/servers/3/units?includeOffline=true&limit=2&offset=3&onlyUnits=false"
  },
  {
    name = "getCallsV2",
    invoke = function() return client.cad:getCallsV2({ serverId = 10, closedLimit = 5, closedOffset = 2, type = "dispatch" }) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/emergency/servers/10/calls?closedLimit=5&closedOffset=2&type=dispatch"
  },
  {
    name = "getCurrentCallV2",
    invoke = function() return client.cad:getCurrentCallV2("uuid/with slash") end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/emergency/accounts/uuid%2Fwith%20slash/current-call"
  },
  {
    name = "updateUnitLocationsV2",
    invoke = function() return client.cad:updateUnitLocationsV2({ serverId = 5, updates = { { communityUserId = "player-1", location = "Main" } } }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/5/unit-locations",
    body = { updates = { { communityUserId = "player-1", location = "Main" } } }
  },
  {
    name = "updateUnitLocationsApiV2",
    invoke = function() return client.cad:updateUnitLocationsApiV2({ serverId = 5, updates = { { communityUserId = "player-1", location = "Main" } } }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/5/unit-locations",
    body = { updates = { { communityUserId = "player-1", location = "Main" } } }
  },
  {
    name = "setUnitPanicV2",
    invoke = function() return client.cad:setUnitPanicV2({ serverId = 5, apiIds = { "1" }, isPanic = true }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/5/units/panic",
    body = { apiIds = { "1" }, isPanic = true }
  },
  {
    name = "setUnitStatusV2",
    invoke = function() return client.cad:setUnitStatusV2({ serverId = 5, apiId = "1", status = 2 }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/5/units/status",
    body = { apiId = "1", status = 2 }
  },
  {
    name = "kickUnitV2",
    invoke = function() return client.cad:kickUnitV2({ serverId = 7, apiId = "1", reason = "spam" }) end,
    method = "DELETE",
    url = "https://api.sonorancad.com/v2/emergency/servers/7/units/kick",
    body = { apiId = "1", reason = "spam" }
  },
  {
    name = "getIdentifiersV2",
    invoke = function() return client.cad:getIdentifiersV2("acc-1") end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/emergency/accounts/acc-1/identifiers"
  },
  {
    name = "getAccountUnitsV2",
    invoke = function() return client.cad:getAccountUnitsV2({ serverId = 6, accountUuid = "acc/1", onlyOnline = true, onlyUnits = true, limit = 4, offset = 1 }) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/emergency/servers/6/accounts/acc%2F1/units?limit=4&offset=1&onlyOnline=true&onlyUnits=true"
  },
  {
    name = "selectIdentifierV2",
    invoke = function() return client.cad:selectIdentifierV2("acc-1", 13) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/emergency/accounts/acc-1/selected-identifier",
    body = { identId = 13 }
  },
  {
    name = "createIdentifierV2",
    invoke = function() return client.cad:createIdentifierV2("acc-1", { unitNum = "A1" }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/emergency/accounts/acc-1/identifiers",
    body = { unitNum = "A1" }
  },
  {
    name = "updateIdentifierV2",
    invoke = function() return client.cad:updateIdentifierV2("acc-1", 9, { unitNum = "A2" }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/accounts/acc-1/identifiers/9",
    body = { unitNum = "A2" }
  },
  {
    name = "deleteIdentifierV2",
    invoke = function() return client.cad:deleteIdentifierV2("acc-1", 9) end,
    method = "DELETE",
    url = "https://api.sonorancad.com/v2/emergency/accounts/acc-1/identifiers/9"
  },
  {
    name = "addIdentifiersToGroupV2",
    invoke = function() return client.cad:addIdentifiersToGroupV2({ serverId = 4, groupName = "A Shift", apiIds = { "1" } }) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/emergency/servers/4/identifier-groups/A%20Shift",
    body = { apiIds = { "1" } }
  },
  {
    name = "createEmergencyCallV2",
    invoke = function() return client.cad:createEmergencyCallV2({ serverId = 4, isEmergency = true, caller = "caller", location = "loc", description = "desc" }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/emergency/servers/4/calls/911",
    body = { isEmergency = true, caller = "caller", location = "loc", description = "desc" }
  },
  {
    name = "deleteEmergencyCallV2",
    invoke = function() return client.cad:deleteEmergencyCallV2(12, 4) end,
    method = "DELETE",
    url = "https://api.sonorancad.com/v2/emergency/servers/4/calls/911/12"
  },
  {
    name = "createDispatchCallV2",
    invoke = function() return client.cad:createDispatchCallV2({ serverId = 11, origin = 1, status = 2, priority = 1, block = "123", address = "Main", postal = "100", title = "Call", code = "TS", description = "desc", notes = {} }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/dispatch-calls",
    body = { origin = 1, status = 2, priority = 1, block = "123", address = "Main", postal = "100", title = "Call", code = "TS", description = "desc", notes = {} }
  },
  {
    name = "updateDispatchCallV2",
    invoke = function() return client.cad:updateDispatchCallV2(14, { serverId = 11, title = "Updated" }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/dispatch-calls/14",
    body = { title = "Updated" }
  },
  {
    name = "attachUnitsToDispatchCallV2",
    invoke = function() return client.cad:attachUnitsToDispatchCallV2(14, { serverId = 11, apiIds = { "1", "2" } }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/dispatch-calls/14/attachments",
    body = { apiIds = { "1", "2" } }
  },
  {
    name = "detachUnitsFromDispatchCallV2",
    invoke = function() return client.cad:detachUnitsFromDispatchCallV2({ serverId = 11, apiIds = { "1" } }) end,
    method = "DELETE",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/dispatch-calls/attachments",
    body = { apiIds = { "1" } }
  },
  {
    name = "setDispatchPostalV2",
    invoke = function() return client.cad:setDispatchPostalV2(14, "85001", 11) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/dispatch-calls/14/postal",
    body = { postal = "85001" }
  },
  {
    name = "setDispatchPrimaryV2",
    invoke = function() return client.cad:setDispatchPrimaryV2(14, 9, true, 11) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/dispatch-calls/14/primary",
    body = { identId = 9, trackPrimary = true }
  },
  {
    name = "addDispatchNoteV2",
    invoke = function() return client.cad:addDispatchNoteV2(14, { serverId = 11, note = "test", noteType = "text", label = "A1" }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/dispatch-calls/14/notes",
    body = { note = "test", noteType = "text", label = "A1" }
  },
  {
    name = "closeDispatchCallsV2",
    invoke = function() return client.cad:closeDispatchCallsV2({ 1, 2 }, 11) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/dispatch-calls/close",
    body = { callIds = { 1, 2 } }
  },
  {
    name = "updateStreetSignsV2",
    invoke = function() return client.cad:updateStreetSignsV2({ serverId = 11, ids = { 5 }, text1 = "A" }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/street-signs",
    body = { ids = { 5 }, text1 = "A" }
  },
  {
    name = "setStreetSignConfigV2",
    invoke = function() return client.cad:setStreetSignConfigV2({ { id = 1 } }, 11) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/street-sign-config",
    body = { signs = { { id = 1 } } }
  },
  {
    name = "setAvailableCalloutsV2",
    invoke = function() return client.cad:setAvailableCalloutsV2({ { id = 1 } }, 11) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/callouts",
    body = { callouts = { { id = 1 } } }
  },
  {
    name = "getPagerConfigV2",
    invoke = function() return client.cad:getPagerConfigV2(11) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/pager-config"
  },
  {
    name = "setPagerConfigV2",
    invoke = function() return client.cad:setPagerConfigV2({ serverId = 11, natureWords = {}, maxAddresses = 3, maxBodyLength = 140 }) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/pager-config",
    body = { natureWords = {}, maxAddresses = 3, maxBodyLength = 140 }
  },
  {
    name = "setStationsV2",
    invoke = function() return client.cad:setStationsV2({ enabled = true }, 11) end,
    method = "PUT",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/stations",
    body = { config = { enabled = true } }
  },
  {
    name = "getBlipsV2",
    invoke = function() return client.cad:getBlipsV2(11) end,
    method = "GET",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/blips"
  },
  {
    name = "createBlipV2",
    invoke = function() return client.cad:createBlipV2({ serverId = 11, coordinates = { x = 1 }, subType = "radius", icon = "1", color = "red", tooltip = "tip" }) end,
    method = "POST",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/blips",
    body = { coordinates = { x = 1 }, subType = "radius", icon = "1", color = "red", tooltip = "tip" }
  },
  {
    name = "updateBlipV2",
    invoke = function() return client.cad:updateBlipV2(21, { serverId = 11, tooltip = "updated" }) end,
    method = "PATCH",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/blips/21",
    body = { tooltip = "updated" }
  },
  {
    name = "deleteBlipsV2",
    invoke = function() return client.cad:deleteBlipsV2({ 21, 22 }, 11) end,
    method = "DELETE",
    url = "https://api.sonorancad.com/v2/emergency/servers/11/blips",
    body = { ids = { 21, 22 } }
  },
}

for _, case in ipairs(cases) do
  next_response = {
    ok = true,
    status = 200,
    headers = {
      ["content-type"] = "application/json; charset=utf-8"
    },
    body = "json:ok"
  }

  last_request = nil
  local response = case.invoke()
  assert_equal(last_request.method, case.method, case.name .. " method")
  assert_equal(last_request.url, case.url, case.name .. " url")
  assert_equal(last_request.timeoutMs, 12345, case.name .. " timeout")
  assert_equal(last_request.headers["Accept"], "application/json", case.name .. " accept header")
  assert_equal(last_request.headers["X-Test"], "yes", case.name .. " passthrough header")

  if case.auth == false then
    assert_nil(last_request.headers["Authorization"], case.name .. " auth header")
  else
    assert_equal(last_request.headers["Authorization"], "Bearer test-key", case.name .. " auth header")
  end

  if case.body ~= nil then
    assert_equal(last_request.headers["Content-Type"], "application/json", case.name .. " content type")
  end

  assert_body(case.body, case.name)
  assert_response_shape(response, true, case.name)
end

last_request = nil
client:_request("GET", "v2/test/query-arrays", {
  query = {
    ids = { "a", "b" },
    status = "active"
  }
})
assert_truthy(last_request.url == "https://api.sonorancad.com/v2/test/query-arrays?ids=a&ids=b&status=active" or last_request.url == "https://api.sonorancad.com/v2/test/query-arrays?status=active&ids=a&ids=b", "query array serialization")

fake_adapter.last_sleep_ms = nil
next_response = {
  {
    ok = false,
    status = 429,
    headers = {
      ["content-type"] = "application/json",
      ["retry-after"] = "1"
    },
    body = "json:error"
  },
  {
    ok = false,
    status = 429,
    headers = {
      ["content-type"] = "application/json"
    },
    body = "json:error"
  },
  {
    ok = true,
    status = 200,
    headers = {
      ["content-type"] = "application/json"
    },
    body = "json:ok"
  }
}

local rate_limited = client.cad:getVersionV2()
assert_response_shape(rate_limited, true, "rate limit retry success")
assert_truthy(fake_adapter.last_sleep_ms ~= nil, "rate limit sleep recorded")
assert_at_least(fake_adapter.last_sleep_ms, 1000, "rate limit sleep delay")

next_response = {
  ok = false,
  status = 400,
  headers = {
    ["content-type"] = "application/json"
  },
  body = "json:error"
}
local failure = client.cad:verifySecretV2("bad")
assert_response_shape(failure, false, "error normalization")

next_response = {
  ok = true,
  status = 204,
  headers = {},
  body = ""
}
local empty = client.cad:getVersionV2()
assert_equal(empty.success, true, "204 success")
assert_nil(empty.data, "204 data")

next_response = {
  ok = false,
  status = 500,
  headers = {
    ["content-type"] = "text/plain"
  },
  body = "plain error"
}
local text_failure = client.cad:getInfoV2()
assert_equal(text_failure.success, false, "plain text failure success")
assert_equal(text_failure.reason, "plain error", "plain text failure reason")

local ws_calls = {}
local ws_connection = {
  invoke = function(self, method, payload)
    ws_calls[#ws_calls + 1] = { method = method, payload = payload }
    return { success = true, count = #payload }
  end
}

local ws_auth_response = client.cad:authenticateWsV2(ws_connection, { serverId = 5 })
assert_equal(ws_calls[1].method, "authenticatev2", "authenticateWsV2 method")
assert_deep_equal(ws_calls[1].payload, {
  communityId = "community-123",
  apiKey = "test-key",
  serverId = 5
}, "authenticateWsV2 payload")
assert_equal(ws_auth_response.success, true, "authenticateWsV2 response")

local ws_response = client.cad:updateUnitLocationsWsV2(ws_connection, {
  {
    communityUserId = "player-1",
    location = "Main"
  }
})
assert_equal(ws_calls[2].method, "unitLocation", "updateUnitLocationsWsV2 method")
assert_deep_equal(ws_calls[2].payload, {
  {
    communityUserId = "player-1",
    location = "Main"
  }
}, "updateUnitLocationsWsV2 payload")
assert_equal(ws_response.success, true, "updateUnitLocationsWsV2 response")
assert_equal(ws_response.count, 1, "updateUnitLocationsWsV2 count")

print("All Sonoran.lua request mapping tests passed.")
