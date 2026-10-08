--- Shorthand wrappers around built-in Lua functions: `typeof` and `try`.

--- Gets the type of an object while ensuring the output is always lowercase.
-- Functions exactly the same as `type`.
-- @param obj [Any]
-- @return [String type]
-- @see [type]
function typeof(obj)
  return string.lower(type(obj))
end

--- A wrapper for pcall for shorthand writing.
-- If the function fails, the error is printed with a traceback and nothing is returned.
-- @param func [Function function to call]
-- @param ... [Vararg arguments to call the function with]
-- @return [Vararg up to six return values of the function]
function try(func, ...)
  local success, a, b, c, d, e, f = pcall(func, ...)

  if !success then
    error_with_traceback(tostring(a))
  end

  return a, b, c, d, e, f
end
