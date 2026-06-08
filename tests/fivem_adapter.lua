local create_adapter = dofile("lua/sonoran/adapters/fivem.lua")

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
  end
end

local function assert_truthy(value, label)
  if not value then
    error(label .. " should be truthy")
  end
end

local function make_async_stubs()
  promise = {
    new = function()
      local deferred = {}

      function deferred:resolve(value)
        self.value = value
      end

      return deferred
    end
  }

  Citizen = {
    Await = function(deferred)
      return deferred.value
    end
  }
end

local function restore_globals(state)
  promise = state.promise
  Citizen = state.Citizen
  SetTimeout = state.SetTimeout
  PerformHttpRequest = state.PerformHttpRequest
  GetCurrentResourceName = state.GetCurrentResourceName
  exports = state.exports
  json = state.json
end

local function save_globals()
  return {
    promise = promise,
    Citizen = Citizen,
    SetTimeout = SetTimeout,
    PerformHttpRequest = PerformHttpRequest,
    GetCurrentResourceName = GetCurrentResourceName,
    exports = exports,
    json = json
  }
end

local previous_globals = save_globals()

json = {
  encode = function(value)
    return value
  end,
  decode = function(value)
    return value
  end
}

make_async_stubs()

local export_call
GetCurrentResourceName = function()
  return "sonoran"
end
exports = {
  sonoran = {
    HandleHttpRequest = function(_, url, callback, method, body, headers)
      export_call = {
        url = url,
        method = method,
        body = body,
        headers = headers
      }
      callback(201, "wrapped", { source = "export" })
    end
  }
}
PerformHttpRequest = function()
  error("fallback should not run when HandleHttpRequest is available")
end

local adapter = create_adapter()
local wrapped_response = adapter.request({
  url = "https://example.com/wrapped",
  method = "POST",
  body = "payload",
  headers = {
    ["X-Test"] = "yes"
  }
})

assert_truthy(export_call, "export request")
assert_equal(export_call.url, "https://example.com/wrapped", "export url")
assert_equal(export_call.method, "POST", "export method")
assert_equal(export_call.body, "payload", "export body")
assert_equal(export_call.headers["X-Test"], "yes", "export header")
assert_equal(wrapped_response.status, 201, "wrapped response status")
assert_equal(wrapped_response.body, "wrapped", "wrapped response body")
assert_equal(wrapped_response.headers.source, "export", "wrapped response headers")

local direct_call
exports = {}
GetCurrentResourceName = function()
  return "sonoran"
end
PerformHttpRequest = function(url, callback, method, body, headers)
  direct_call = {
    url = url,
    method = method,
    body = body,
    headers = headers
  }
  callback(202, "direct", { source = "direct" })
end

local direct_response = adapter.request({
  url = "https://example.com/direct",
  headers = {}
})

assert_truthy(direct_call, "direct request")
assert_equal(direct_call.url, "https://example.com/direct", "direct url")
assert_equal(direct_call.method, "GET", "direct method default")
assert_equal(direct_response.status, 202, "direct response status")
assert_equal(direct_response.body, "direct", "direct response body")
assert_equal(direct_response.headers.source, "direct", "direct response headers")

restore_globals(previous_globals)
print("fivem adapter tests passed")
