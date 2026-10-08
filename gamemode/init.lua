--- Server entry point of the gamemode.
-- Opens the `file` binary module, without which startup is aborted, then loads the
-- environment, the standard library and the package manager and includes the `flux` package.
-- On a code refresh the package is reloaded instead.

local start_time = os.clock()

--- Includes a module and returns a boolean depending on success.
-- Does not throw Lua errors.
-- @param mod [String module name, as passed to require]
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
    ((system.IsWindows() and 'win64') or 'linux64')..
    '.dll in the garrysmod/lua/bin folder!\nAborting startup...\n'
  )
  return
end

include 'env.lua'
include 'flux/lib/stdlib/sh_stdlib.lua'
include 'flux/lib/package.lua'

if Flux.initialized then
  Package:reload 'flux'
  MsgC(Color(0, 255, 100, 255), 'Code reloaded in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
else
  Package:include 'flux'
  MsgC(Color(0, 255, 100, 255), 'Boot complete in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
end

print_debug_metrics()
