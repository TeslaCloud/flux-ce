-- A function to get lowercase type of an object.
function typeof(obj)
  return string.lower(type(obj))
end

function try(func, ...)
  local success, a, b, c, d, e, f = pcall(func, ...)

  if !success then
    error_with_traceback(a)
  end

  return a, b, c, d, e, f
end
