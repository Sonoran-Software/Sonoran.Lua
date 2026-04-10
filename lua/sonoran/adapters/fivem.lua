local function encode_uri_component(value)
  return tostring(value):gsub("([^%w%-%._~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)
end

return function()
  return {
    encode = function(value)
      if not json or not json.encode then
        error("FiveM json.encode is required.")
      end

      return json.encode(value)
    end,
    decode = function(value)
      if not json or not json.decode then
        error("FiveM json.decode is required.")
      end

      return json.decode(value)
    end,
    encodeURIComponent = encode_uri_component,
    request = function(options)
      if not PerformHttpRequest then
        error("PerformHttpRequest is required in the FiveM runtime.")
      end

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

      PerformHttpRequest(
        options.url,
        function(status_code, body, headers)
          settle({
            ok = type(status_code) == "number" and status_code >= 200 and status_code < 300,
            status = status_code or 0,
            headers = headers or {},
            body = body
          })
        end,
        options.method or "GET",
        options.body,
        options.headers or {}
      )

      return Citizen.Await(deferred)
    end
  }
end
