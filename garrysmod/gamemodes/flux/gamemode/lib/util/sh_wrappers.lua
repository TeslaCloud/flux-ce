-- A function to get lowercase type of an object.
function typeof(obj)
  return string.lower(type(obj))
end

function Try(id, func, ...)
  id = id or 'Try'
  local result = {pcall(func, ...)}
  local success = result[1]
  table.remove(result, 1)

  if !success then
    ErrorNoHalt('[Try:'..id..'] Failed to run the function!\n')
    ErrorNoHalt(unpack(result), '\n')
  elseif result[1] != nil then
    return unpack(result)
  end
end

do
  local try_cache = {}

  function try(tab)
    try_cache = {}
    try_cache.f = tab[1]

    local args = {}

    for k, v in ipairs(tab) do
      if k != 1 then
        table.insert(args, v)
      end
    end

    try_cache.args = args
  end

  function catch(handler)
    local func = try_cache.f
    local args = try_cache.args or {}
    local result = {pcall(func, unpack(args))}
    local success = result[1]
    table.remove(result, 1)

    handler = handler or {}
    try_cache = {}

    SUCCEEDED = true

    if !success then
      SUCCEEDED = false

      if isfunction(handler[1]) then
        handler[1](unpack(result))
      else
        ErrorNoHalt('[Try:Exception] Failed to run the function!\n')
        ErrorNoHalt(unpack(result), '\n')
      end
    elseif result[1] != nil then
      return unpack(result)
    end
  end

  --[[
    Please note that the try-catch block will only
    run if you put in the catch function.

    Example usage:

    try {
      function()
        print('Hello World')
      end
    } catch {
      function(exception)
        print(exception)
      end
    }

    try {
      function(arg1, arg2)
        print(arg1, arg2)
      end, 'arg1', 'arg2'
    } catch {
      function(exception)
        print(exception)
      end
    }
  --]]
end
