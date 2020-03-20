--- Gets the type of an object while ensuring the output is always lowercase.
-- Functions exactly the same as `type`.
-- @return [String type]
-- @see [type]
function typeof(obj)
  return string.lower(type(obj))
end

local unpack = unpack or table.unpack
--- A wrapper for pcall for shorthand writing.
-- @return [Vararg]
try = function(func, ...)
  local tryed = {pcall(func, ...)}

  if not tryed[1] then
    error_with_traceback(tostring(tryed[2]))
  end

  return unpack(tryed)
end
