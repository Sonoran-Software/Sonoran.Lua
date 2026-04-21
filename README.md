# Sonoran.lua

`Sonoran.lua` is a Lua SDK for Sonoran CAD v2 endpoints with shared client code for FiveM and Roblox runtimes.

## Installation

### FiveM

Install from LuaRocks:

```sh
luarocks install sonoran.lua
```

LuaRocks package:
[sonoran.lua on LuaRocks](https://luarocks.org/modules/sonoransoftware/sonoran.lua)

Or use the generated FiveM resource release asset and start it before resources that consume it.

```cfg
ensure Sonoran.lua
```

In your consuming resource:

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

server_scripts {
  'server.lua'
}

dependency 'Sonoran.lua'
```

### Roblox

Install from Wally:

```toml
[dependencies]
Sonoran = "sonoransoftwaregit/sonoran-lua@^0.1.0"
```

Then require the package module:

```lua
local Sonoran = require(ReplicatedStorage.Packages.Sonoran)
```

## Usage

FiveM resource usage:

```lua
local Sonoran = require("sonoran")

local sonoran = exports["Sonoran.lua"]:createClient({
  product = Sonoran.productEnums.CAD,
  apiKey = "your-cad-api-key",
  communityId = "your-community-id",
  apiUrl = "https://api.sonorancad.com",
  defaultServerId = 1,
  timeoutMs = 30000
})
```

Roblox usage:

```lua
local sonoran = Sonoran.createClient({
  product = Sonoran.productEnums.CAD,
  apiKey = "your-cad-api-key",
  communityId = "your-community-id",
  apiUrl = "https://api.sonorancad.com",
  defaultServerId = 1,
  timeoutMs = 30000
})
```

### Config

- `apiKey`: required for authenticated endpoints.
- `product`: required; currently must be `Sonoran.productEnums.CAD`.
- `communityId`: optional; used by `getLoginPageV2()` when no explicit `communityId` is supplied.
- `apiUrl`: optional; defaults to `https://api.sonorancad.com`.
- `defaultServerId`: optional; defaults to `1`.
- `headers`: optional extra headers merged into every request.
- `timeoutMs`: optional timeout for the FiveM adapter; defaults to `30000`.

### Response Shape

All public methods return:

```lua
{ success = true, data = ... }
```

or:

```lua
{ success = false, reason = ... }
```

Successful JSON responses are decoded automatically. Plain-text error responses are returned as strings. `204 No Content` responses return `data = nil`.

### Rate Limit Handling

For CAD v2 endpoints, `Sonoran.lua` automatically retries `429 Too Many Requests` responses up to 2 times. The client honors a numeric `Retry-After` header when present and otherwise falls back to a short exponential backoff. This is intentionally limited, so callers should still avoid sending bursts to high-frequency endpoints.

## Examples

General endpoint:

```lua
local version = sonoran.cad:getVersionV2()
if version.success then
  print(version.data)
end
```

Civilian endpoint:

```lua
local characters = sonoran.cad:getCharactersV2({
  apiId = "1234567890"
})

if characters.success then
  print(("Found %s character(s)"):format(#characters.data))
end
```

Emergency endpoint:

```lua
local created = sonoran.cad:createDispatchCallV2({
  serverId = 1,
  origin = 1,
  status = 1,
  priority = 1,
  block = "123",
  address = "Main St",
  postal = "100",
  title = "Traffic Stop",
  code = "TS",
  description = "Blue sedan heading north",
  notes = {},
  apiIds = { "1234567890" }
})

if not created.success then
  print(json.encode(created.reason))
end
```

## Public API

All CAD v2 helpers are available under `client.cad.*`. The root-level methods are still present for backward compatibility.

### General

- `getLoginPageV2(params?)`
- `checkApiIdV2(apiId)`
- `applyPermissionKeyV2(data)`
- `banUserV2(data)`
- `setPenalCodesV2(codes)`
- `setApiIdsV2(data)`
- `getTemplatesV2(recordTypeId?)`
- `createRecordV2(data)`
- `updateRecordV2(recordId, data)`
- `removeRecordV2(recordId)`
- `sendRecordDraftV2(data)`
- `lookupV2(data)`
- `lookupByValueV2(data)`
- `lookupCustomV2(data)`
- `getAccountV2(query?)`
- `getAccountsV2(query?)`
- `createCommunityLinkV2(data)`
- `checkCommunityLinkV2(data)`
- `setAccountPermissionsV2(data)`
- `heartbeatV2(serverId, playerCount)`
- `getVersionV2()`
- `getServersV2()`
- `setServersV2(servers, deployMap?)`
- `verifySecretV2(secret)`
- `authorizeStreetSignsV2(serverId?)`
- `setPostalsV2(postals)`
- `sendPhotoV2(data)`
- `getInfoV2()`

### Civilian

- `getCharactersV2(query?)`
- `removeCharacterV2(characterId)`
- `setSelectedCharacterV2(data)`
- `getCharacterLinksV2(query?)`
- `addCharacterLinkV2(syncId, data)`
- `removeCharacterLinkV2(syncId, data)`

### Emergency

- `getUnitsV2(query?)`
- `getCallsV2(query?)`
- `getCurrentCallV2(accountUuid)`
- `updateUnitLocationsV2(data)`
- `setUnitPanicV2(data)`
- `setUnitStatusV2(data)`
- `kickUnitV2(data)`
- `getIdentifiersV2(accountUuid)`
- `getAccountUnitsV2(data)`
- `selectIdentifierV2(accountUuid, identId)`
- `createIdentifierV2(accountUuid, data)`
- `updateIdentifierV2(accountUuid, identId, data)`
- `deleteIdentifierV2(accountUuid, identId)`
- `addIdentifiersToGroupV2(data)`
- `createEmergencyCallV2(data)`
- `deleteEmergencyCallV2(callId, serverId?)`
- `createDispatchCallV2(data)`
- `updateDispatchCallV2(callId, data)`
- `attachUnitsToDispatchCallV2(callId, data)`
- `detachUnitsFromDispatchCallV2(data)`
- `setDispatchPostalV2(callId, postal, serverId?)`
- `setDispatchPrimaryV2(callId, identId, trackPrimary?, serverId?)`
- `addDispatchNoteV2(callId, data)`
- `closeDispatchCallsV2(callIds, serverId?)`
- `updateStreetSignsV2(data)`
- `setStreetSignConfigV2(signs, serverId?)`
- `setAvailableCalloutsV2(callouts, serverId?)`
- `getPagerConfigV2(serverId?)`
- `setPagerConfigV2(data)`
- `setStationsV2(config, serverId?)`
- `getBlipsV2(serverId?)`
- `createBlipV2(data)`
- `updateBlipV2(blipId, data)`
- `deleteBlipsV2(ids, serverId?)`

## Notes

- `updateUnitLocationsV2(data)` uses the HTTP v2 endpoint for slower unit location updates.
- Unit location updates can target `communityUserId` through the v2 HTTP endpoint.
- FiveM uses `PerformHttpRequest`, `promise.new()`, and `Citizen.Await`.
- Roblox uses `HttpService:RequestAsync()`.
- Radio, CMS, and legacy CAD endpoints are intentionally out of scope for this initial port.
