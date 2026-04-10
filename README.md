# Sonoran.lua

`Sonoran.lua` is a FiveM-first Lua SDK for Sonoran CAD v2 endpoints. This first release only covers the CAD `/v2` API surface and keeps the public method names aligned with `Sonoran.js`.

## Installation

Add this resource to your server and start it before resources that consume it.

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

## Usage

Create a client instance through the exported constructor:

```lua
local sonoran = exports["Sonoran.lua"]:createClient({
  apiKey = "your-cad-api-key",
  communityId = "your-community-id",
  apiUrl = "https://api.sonorancad.com",
  defaultServerId = 1,
  timeoutMs = 30000
})
```

### Config

- `apiKey`: required for authenticated endpoints.
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

## Examples

General endpoint:

```lua
local version = sonoran:getVersionV2()
if version.success then
  print(version.data)
end
```

Civilian endpoint:

```lua
local characters = sonoran:getCharactersV2({
  apiId = "1234567890"
})

if characters.success then
  print(("Found %s character(s)"):format(#characters.data))
end
```

Emergency endpoint:

```lua
local created = sonoran:createDispatchCallV2({
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

- This version is server-side FiveM only.
- The transport layer is adapter-backed internally; the shipped adapter uses `PerformHttpRequest`, `promise.new()`, and `Citizen.Await`.
- Radio, CMS, and legacy CAD endpoints are intentionally out of scope for this initial port.
