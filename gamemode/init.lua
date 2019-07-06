local start_time = os.clock()

--- Includes a module and returns a boolean depending on success.
-- Does now throw Lua errors.
-- @return [Boolean success]
function require_module(mod)
  local success, value = pcall(require, mod)

  if !success then
    ErrorNoHalt('Failed to open the "'..mod..'" module!\n')
    return false
  end

  return true
end

if !require_module 'file' then
  ErrorNoHalt(
    'The file module has failed to load!\nPlease make sure that you have gmsv_file_'..
    ((system.IsWindows() and 'win32') or 'linux')..
    '.dll in garrysmod/lua/bin folder!\nAborting startup...\n'
  )
  return
end

include 'env.lua'
include 'flux/lib/stdlib/sh_stdlib.lua'
include 'flux/lib/crate.lua'

if Flux.initialized then
  Crate:reload 'flux'
  MsgC(Color(0, 255, 100, 255), 'Code reloaded in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
else
  Crate:include 'flux'
  MsgC(Color(0, 255, 100, 255), 'Boot complete in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
end

print_debug_metrics()
