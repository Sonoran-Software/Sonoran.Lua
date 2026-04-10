return function(http_service)
  return {
    encode = function(value)
      return http_service:JSONEncode(value)
    end,
    decode = function(value)
      return http_service:JSONDecode(value)
    end,
    encodeURIComponent = function(value)
      return http_service:UrlEncode(tostring(value))
    end,
    request = function(options)
      local response = http_service:RequestAsync({
        Url = options.url,
        Method = options.method or "GET",
        Headers = options.headers or {},
        Body = options.body
      })

      return {
        ok = response.Success,
        status = response.StatusCode or 0,
        headers = response.Headers or {},
        body = response.Body
      }
    end
  }
end
