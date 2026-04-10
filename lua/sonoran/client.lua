local function trim_trailing_slashes(value)
  return (tostring(value):gsub("/+$", ""))
end

local function starts_with(value, prefix)
  return value:sub(1, #prefix) == prefix
end

local function is_positive_integer(value)
  return type(value) == "number" and value >= 1 and value % 1 == 0
end

local function is_array(value)
  if type(value) ~= "table" then
    return false
  end

  local count = 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end

    count = count + 1
  end

  return count == #value
end

local function shallow_copy(value)
  if type(value) ~= "table" then
    return value
  end

  local copy = {}
  for key, entry in pairs(value) do
    copy[key] = entry
  end

  return copy
end

local function strip_keys(value, keys)
  local copy = shallow_copy(value or {})
  for _, key in ipairs(keys) do
    copy[key] = nil
  end
  return copy
end

local function normalize_headers(headers)
  local normalized = {}
  for key, value in pairs(headers or {}) do
    normalized[string.lower(tostring(key))] = value
  end
  return normalized
end

local function append_query_parts(parts, encode, key, value)
  if value == nil then
    return
  end

  if type(value) == "table" and is_array(value) then
    for _, entry in ipairs(value) do
      append_query_parts(parts, encode, key, entry)
    end
    return
  end

  parts[#parts + 1] = string.format("%s=%s", encode(key), encode(tostring(value)))
end

local function build_url(base_url, path, query, encode)
  local url = string.format("%s/%s", trim_trailing_slashes(base_url), tostring(path):gsub("^/+", ""))
  if type(query) ~= "table" then
    return url
  end

  local parts = {}
  local keys = {}
  for key in pairs(query) do
    keys[#keys + 1] = tostring(key)
  end
  table.sort(keys)

  for _, key in ipairs(keys) do
    local value = query[key]
    append_query_parts(parts, encode, tostring(key), value)
  end

  if #parts == 0 then
    return url
  end

  return url .. "?" .. table.concat(parts, "&")
end

local Client = {}
Client.__index = Client

function Client:_assert_positive_integer(value, label)
  if not is_positive_integer(value) then
    error(string.format("%s must be a positive integer.", label))
  end

  return value
end

function Client:_resolve_server_id(server_id)
  local resolved = server_id
  if resolved == nil then
    resolved = self._config.defaultServerId
  end

  self:_assert_positive_integer(resolved, "serverId")
  return resolved
end

function Client:_encode_path_segment(value)
  if value == nil or value == "" then
    error("Path segment is required.")
  end

  return self._adapter.encodeURIComponent(tostring(value))
end

function Client:_parse_response(response)
  local status = tonumber(response and response.status) or 0
  if status == 204 then
    return nil
  end

  local raw_body = response and response.body
  if raw_body == nil or raw_body == "" then
    return nil
  end

  local headers = normalize_headers(response and response.headers)
  local content_type = tostring(headers["content-type"] or "")
  if starts_with(string.lower(content_type), "application/json") then
    local ok, parsed = pcall(self._adapter.decode, raw_body)
    if ok then
      return parsed
    end
  end

  return raw_body
end

function Client:_request(method, path, options)
  options = options or {}

  local headers = shallow_copy(self._config.headers)
  headers["Accept"] = "application/json"

  local authenticated = options.authenticated ~= false
  if authenticated then
    if not self._config.apiKey or self._config.apiKey == "" then
      error("apiKey is required for authenticated requests.")
    end

    headers["Authorization"] = "Bearer " .. self._config.apiKey
  end

  local body = options.body
  local encoded_body
  if body ~= nil then
    headers["Content-Type"] = "application/json"
    encoded_body = self._adapter.encode(body)
  end

  local response = self._adapter.request({
    method = method,
    url = build_url(self._config.apiUrl, path, options.query, self._adapter.encodeURIComponent),
    headers = headers,
    body = encoded_body,
    timeoutMs = self._config.timeoutMs
  })

  local parsed = self:_parse_response(response or {})
  local ok = response and response.ok
  if ok == nil then
    local status = tonumber(response and response.status) or 0
    ok = status >= 200 and status < 300
  end

  if ok then
    return {
      success = true,
      data = parsed
    }
  end

  return {
    success = false,
    reason = parsed
  }
end

local function define_method(target, name, implementation)
  target[name] = implementation
end

local function create_client(config, adapter)
  if type(adapter) ~= "table" then
    error("An adapter instance is required.")
  end

  if type(adapter.encode) ~= "function" or type(adapter.decode) ~= "function" or type(adapter.request) ~= "function" or type(adapter.encodeURIComponent) ~= "function" then
    error("Adapter is missing one or more required functions.")
  end

  local instance = setmetatable({
    _adapter = adapter,
    _config = {
      apiKey = config and config.apiKey or nil,
      communityId = config and config.communityId or nil,
      apiUrl = trim_trailing_slashes(config and config.apiUrl or "https://api.sonorancad.com"),
      defaultServerId = config and config.defaultServerId or 1,
      headers = shallow_copy(config and config.headers or {}),
      timeoutMs = config and config.timeoutMs or 30000
    }
  }, Client)

  define_method(instance, "getLoginPageV2", function(self, params)
    params = params or {}
    return self:_request("GET", "v2/general/login-page", {
      authenticated = false,
      query = {
        url = params.url,
        communityId = params.communityId or self._config.communityId
      }
    })
  end)

  define_method(instance, "checkApiIdV2", function(self, api_id)
    return self:_request("GET", "v2/general/api-ids/" .. self:_encode_path_segment(api_id))
  end)
  define_method(instance, "applyPermissionKeyV2", function(self, data)
    return self:_request("POST", "v2/general/permission-keys/applications", { body = data })
  end)
  define_method(instance, "banUserV2", function(self, data)
    return self:_request("POST", "v2/general/account-bans", { body = data })
  end)
  define_method(instance, "setPenalCodesV2", function(self, codes)
    return self:_request("PUT", "v2/general/penal-codes", { body = { codes = codes } })
  end)
  define_method(instance, "setApiIdsV2", function(self, data)
    return self:_request("PUT", "v2/general/api-ids", { body = data })
  end)
  define_method(instance, "getTemplatesV2", function(self, record_type_id)
    if record_type_id ~= nil then
      self:_assert_positive_integer(record_type_id, "recordTypeId")
      return self:_request("GET", "v2/general/templates/" .. tostring(record_type_id))
    end
    return self:_request("GET", "v2/general/templates")
  end)
  define_method(instance, "createRecordV2", function(self, data)
    return self:_request("POST", "v2/general/records", { body = data })
  end)
  define_method(instance, "updateRecordV2", function(self, record_id, data)
    self:_assert_positive_integer(record_id, "recordId")
    return self:_request("PATCH", "v2/general/records/" .. tostring(record_id), { body = data })
  end)
  define_method(instance, "removeRecordV2", function(self, record_id)
    self:_assert_positive_integer(record_id, "recordId")
    return self:_request("DELETE", "v2/general/records/" .. tostring(record_id))
  end)
  define_method(instance, "sendRecordDraftV2", function(self, data)
    return self:_request("POST", "v2/general/record-drafts", { body = data })
  end)
  define_method(instance, "lookupV2", function(self, data)
    return self:_request("POST", "v2/general/lookups", { body = data })
  end)
  define_method(instance, "lookupByValueV2", function(self, data)
    return self:_request("POST", "v2/general/lookups/by-value", { body = data })
  end)
  define_method(instance, "lookupCustomV2", function(self, data)
    return self:_request("POST", "v2/general/lookups/custom", { body = data })
  end)
  define_method(instance, "getAccountV2", function(self, query)
    return self:_request("GET", "v2/general/accounts/account", { query = query or {} })
  end)
  define_method(instance, "getAccountsV2", function(self, query)
    return self:_request("GET", "v2/general/accounts", { query = query or {} })
  end)
  define_method(instance, "createCommunityLinkV2", function(self, data)
    return self:_request("POST", "v2/general/links", { body = data })
  end)
  define_method(instance, "checkCommunityLinkV2", function(self, data)
    return self:_request("POST", "v2/general/links/check", { body = data })
  end)
  define_method(instance, "setAccountPermissionsV2", function(self, data)
    return self:_request("PATCH", "v2/general/accounts/permissions", { body = data })
  end)
  define_method(instance, "heartbeatV2", function(self, server_id, player_count)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("POST", "v2/general/servers/" .. tostring(resolved_server_id) .. "/heartbeat", {
      body = { playerCount = player_count }
    })
  end)
  define_method(instance, "getVersionV2", function(self)
    return self:_request("GET", "v2/general/version")
  end)
  define_method(instance, "getServersV2", function(self)
    return self:_request("GET", "v2/general/servers")
  end)
  define_method(instance, "setServersV2", function(self, servers, deploy_map)
    return self:_request("PUT", "v2/general/servers", {
      body = {
        servers = servers,
        deployMap = deploy_map == true
      }
    })
  end)
  define_method(instance, "verifySecretV2", function(self, secret)
    return self:_request("POST", "v2/general/secrets/verify", { body = { secret = secret } })
  end)
  define_method(instance, "authorizeStreetSignsV2", function(self, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("POST", "v2/general/servers/" .. tostring(resolved_server_id) .. "/street-sign-auth")
  end)
  define_method(instance, "setPostalsV2", function(self, postals)
    return self:_request("PUT", "v2/general/postals", { body = { postals = postals } })
  end)
  define_method(instance, "sendPhotoV2", function(self, data)
    return self:_request("POST", "v2/general/photos", { body = data })
  end)
  define_method(instance, "getInfoV2", function(self)
    return self:_request("GET", "v2/general/info")
  end)

  define_method(instance, "getCharactersV2", function(self, query)
    return self:_request("GET", "v2/civilian/characters", { query = query or {} })
  end)
  define_method(instance, "removeCharacterV2", function(self, character_id)
    self:_assert_positive_integer(character_id, "characterId")
    return self:_request("DELETE", "v2/civilian/characters/" .. tostring(character_id))
  end)
  define_method(instance, "setSelectedCharacterV2", function(self, data)
    return self:_request("PUT", "v2/civilian/selected-character", { body = data })
  end)
  define_method(instance, "getCharacterLinksV2", function(self, query)
    return self:_request("GET", "v2/civilian/character-links", { query = query or {} })
  end)
  define_method(instance, "addCharacterLinkV2", function(self, sync_id, data)
    return self:_request("PUT", "v2/civilian/character-links/" .. self:_encode_path_segment(sync_id), { body = data })
  end)
  define_method(instance, "removeCharacterLinkV2", function(self, sync_id, data)
    return self:_request("DELETE", "v2/civilian/character-links/" .. self:_encode_path_segment(sync_id), { body = data })
  end)

  define_method(instance, "getUnitsV2", function(self, query)
    query = query or {}
    local resolved_server_id = self:_resolve_server_id(query.serverId)
    return self:_request("GET", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/units", {
      query = {
        includeOffline = query.includeOffline,
        onlyUnits = query.onlyUnits,
        limit = query.limit,
        offset = query.offset
      }
    })
  end)
  define_method(instance, "getCallsV2", function(self, query)
    query = query or {}
    local resolved_server_id = self:_resolve_server_id(query.serverId)
    return self:_request("GET", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/calls", {
      query = {
        closedLimit = query.closedLimit,
        closedOffset = query.closedOffset,
        type = query.type
      }
    })
  end)
  define_method(instance, "getCurrentCallV2", function(self, account_uuid)
    return self:_request("GET", "v2/emergency/accounts/" .. self:_encode_path_segment(account_uuid) .. "/current-call")
  end)
  define_method(instance, "updateUnitLocationsV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("PATCH", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/unit-locations", {
      body = { updates = data and data.updates or nil }
    })
  end)
  define_method(instance, "setUnitPanicV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("PATCH", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/units/panic", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "setUnitStatusV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("PATCH", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/units/status", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "kickUnitV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("DELETE", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/units/kick", {
      body = {
        apiId = data and data.apiId or nil,
        reason = data and data.reason or nil
      }
    })
  end)
  define_method(instance, "getIdentifiersV2", function(self, account_uuid)
    return self:_request("GET", "v2/emergency/accounts/" .. self:_encode_path_segment(account_uuid) .. "/identifiers")
  end)
  define_method(instance, "getAccountUnitsV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request(
      "GET",
      "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/accounts/" .. self:_encode_path_segment(data.accountUuid) .. "/units",
      {
        query = {
          onlyOnline = data.onlyOnline,
          onlyUnits = data.onlyUnits,
          limit = data.limit,
          offset = data.offset
        }
      }
    )
  end)
  define_method(instance, "selectIdentifierV2", function(self, account_uuid, ident_id)
    return self:_request("PUT", "v2/emergency/accounts/" .. self:_encode_path_segment(account_uuid) .. "/selected-identifier", {
      body = { identId = ident_id }
    })
  end)
  define_method(instance, "createIdentifierV2", function(self, account_uuid, data)
    return self:_request("POST", "v2/emergency/accounts/" .. self:_encode_path_segment(account_uuid) .. "/identifiers", { body = data })
  end)
  define_method(instance, "updateIdentifierV2", function(self, account_uuid, ident_id, data)
    self:_assert_positive_integer(ident_id, "identId")
    return self:_request("PATCH", "v2/emergency/accounts/" .. self:_encode_path_segment(account_uuid) .. "/identifiers/" .. tostring(ident_id), {
      body = data
    })
  end)
  define_method(instance, "deleteIdentifierV2", function(self, account_uuid, ident_id)
    self:_assert_positive_integer(ident_id, "identId")
    return self:_request("DELETE", "v2/emergency/accounts/" .. self:_encode_path_segment(account_uuid) .. "/identifiers/" .. tostring(ident_id))
  end)
  define_method(instance, "addIdentifiersToGroupV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request(
      "PUT",
      "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/identifier-groups/" .. self:_encode_path_segment(data.groupName),
      {
        body = strip_keys(data, { "serverId", "groupName" })
      }
    )
  end)
  define_method(instance, "createEmergencyCallV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("POST", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/calls/911", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "deleteEmergencyCallV2", function(self, call_id, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    self:_assert_positive_integer(call_id, "callId")
    return self:_request("DELETE", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/calls/911/" .. tostring(call_id))
  end)
  define_method(instance, "createDispatchCallV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("POST", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/dispatch-calls", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "updateDispatchCallV2", function(self, call_id, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    self:_assert_positive_integer(call_id, "callId")
    return self:_request("PATCH", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/dispatch-calls/" .. tostring(call_id), {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "attachUnitsToDispatchCallV2", function(self, call_id, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    self:_assert_positive_integer(call_id, "callId")
    return self:_request("POST", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/dispatch-calls/" .. tostring(call_id) .. "/attachments", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "detachUnitsFromDispatchCallV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("DELETE", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/dispatch-calls/attachments", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "setDispatchPostalV2", function(self, call_id, postal, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    self:_assert_positive_integer(call_id, "callId")
    return self:_request("PATCH", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/dispatch-calls/" .. tostring(call_id) .. "/postal", {
      body = { postal = postal }
    })
  end)
  define_method(instance, "setDispatchPrimaryV2", function(self, call_id, ident_id, track_primary, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    self:_assert_positive_integer(call_id, "callId")
    self:_assert_positive_integer(ident_id, "identId")
    return self:_request("PATCH", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/dispatch-calls/" .. tostring(call_id) .. "/primary", {
      body = {
        identId = ident_id,
        trackPrimary = track_primary == true
      }
    })
  end)
  define_method(instance, "addDispatchNoteV2", function(self, call_id, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    self:_assert_positive_integer(call_id, "callId")
    return self:_request("POST", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/dispatch-calls/" .. tostring(call_id) .. "/notes", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "closeDispatchCallsV2", function(self, call_ids, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("POST", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/dispatch-calls/close", {
      body = { callIds = call_ids }
    })
  end)
  define_method(instance, "updateStreetSignsV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("PATCH", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/street-signs", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "setStreetSignConfigV2", function(self, signs, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("PUT", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/street-sign-config", {
      body = { signs = signs }
    })
  end)
  define_method(instance, "setAvailableCalloutsV2", function(self, callouts, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("PUT", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/callouts", {
      body = { callouts = callouts }
    })
  end)
  define_method(instance, "getPagerConfigV2", function(self, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("GET", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/pager-config")
  end)
  define_method(instance, "setPagerConfigV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("PUT", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/pager-config", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "setStationsV2", function(self, config_value, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("PUT", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/stations", {
      body = { config = config_value }
    })
  end)
  define_method(instance, "getBlipsV2", function(self, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("GET", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/blips")
  end)
  define_method(instance, "createBlipV2", function(self, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    return self:_request("POST", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/blips", {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "updateBlipV2", function(self, blip_id, data)
    local resolved_server_id = self:_resolve_server_id(data and data.serverId)
    self:_assert_positive_integer(blip_id, "blipId")
    return self:_request("PATCH", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/blips/" .. tostring(blip_id), {
      body = strip_keys(data, { "serverId" })
    })
  end)
  define_method(instance, "deleteBlipsV2", function(self, ids, server_id)
    local resolved_server_id = self:_resolve_server_id(server_id)
    return self:_request("DELETE", "v2/emergency/servers/" .. tostring(resolved_server_id) .. "/blips", {
      body = { ids = ids }
    })
  end)

  return instance
end

return create_client
