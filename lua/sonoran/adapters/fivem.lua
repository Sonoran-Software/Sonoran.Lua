local function encode_uri_component(value)
  return tostring(value):gsub("([^%w%-%._~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

local function perform_request(options, callback)
  local resource_name = GetCurrentResourceName and GetCurrentResourceName() or nil
  if resource_name ~= nil and exports ~= nil and exports[resource_name] ~= nil and exports[resource_name].HandleHttpRequest ~= nil then
    exports[resource_name]:HandleHttpRequest(
      options.url,
      callback,
      options.method or "GET",
      options.body,
      options.headers or {}
    )
    return
  end

  PerformHttpRequest(
    options.url,
    callback,
    options.method or "GET",
    options.body,
    options.headers or {}
  )
end

local function resolve_response_parts(body, headers, extra)
  if type(body) == "table" and type(headers) == "string" then
    return headers, body
  end

  if type(headers) ~= "table" and type(extra) == "table" then
    return body, extra
  end

  if type(headers) == "table" then
    return body, headers
  end

  return body, {}
end

return function()
  return {
    encode = function(value)
      return json.encode(value)
    end,
    decode = function(value)
      return json.decode(value)
    end,
    encodeURIComponent = encode_uri_component,
    sleep = function(delay_ms)
      local deferred = promise.new()
      local resolved = false

      local function finish()
        if resolved then
          return
        end

        resolved = true
        deferred:resolve(true)
      end

      if SetTimeout and tonumber(delay_ms) and tonumber(delay_ms) > 0 then
        SetTimeout(tonumber(delay_ms), finish)
      else
        finish()
      end

      return Citizen.Await(deferred)
    end,
    request = function(options)
      local deferred = promise.new()
      local settled = false
      local timeout_ms = tonumber(options.timeoutMs) or 30000

      local function settle(result)
        if settled then
          return
        end

        settled = true
        deferred:resolve(result)
      end

      if SetTimeout and timeout_ms > 0 then
        SetTimeout(timeout_ms, function()
          settle({
            ok = false,
            status = 408,
            headers = {},
            body = "Request timed out."
          })
        end)
      end

      perform_request(
        options,
        function(status_code, body, headers, extra)
          local resolved_body, resolved_headers = resolve_response_parts(body, headers, extra)
          settle({
            ok = type(status_code) == "number" and status_code >= 200 and status_code < 300,
            status = status_code or 0,
            headers = resolved_headers,
            body = resolved_body
          })
        end
      )

      return Citizen.Await(deferred)
    end
  }
end
