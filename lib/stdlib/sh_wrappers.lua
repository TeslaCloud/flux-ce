--- Shorthand wrappers around built-in Lua functions: `typeof` and `try`.
-- On Linux servers `ErrorNoHalt` is also replaced to print errors on a red background,
-- with the original kept as `_ErrorNoHalt`.

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

if SERVER and system.IsLinux() then
  _ErrorNoHalt = _ErrorNoHalt or ErrorNoHalt

  --- Prints the error in bold on a red background using ANSI escape sequences.
  -- Trailing newlines are printed after the styling is reset.
  -- @param msg [String error message]
  function ErrorNoHalt(msg)
    local new_msg, count = tostring(msg):gsub('\n+$', '')

    Msg('\27[41;15m\27[1m')
    _ErrorNoHalt(new_msg)
    Msg('\27[0m'..string.rep('\n', count))
  end
end
