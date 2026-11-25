--- The first stages of the boot, shared by the game, where `boot.lua` includes this file, and by
-- fpkg's tasks, where `lib/tasks.lua` does. The file that includes it sets `FLUX_PATH` first.
-- On the server the `file` binary module is opened, without which start-up stops; then the
-- environment, the standard library and the package manager are loaded. An environment that
-- `lib/env.lua` refuses stops start-up as well.
-- Returns whether start-up can go on.

AddCSLuaFile()

if SERVER then
  --- Includes a module and returns a boolean depending on success.
  -- Does not throw Lua errors: a failure is printed with the error `require` gave.
  -- @param mod [String module name, as passed to require]
  -- @return [Boolean success]
  function require_module(mod)
    local success, result = pcall(require, mod)

    if !success then
      ErrorNoHalt('Failed to open the "'..mod..'" module: '..tostring(result)..'\n')
      return false
    end

    return true
  end

  if !require_module 'file' then
    local is_64_bit = jit.arch == 'x64'
    local platform = system.IsWindows() ? (is_64_bit ? 'win64' : 'win32') : (is_64_bit ? 'linux64' : 'linux')

    ErrorNoHalt(
      'The file module has failed to load!\nIt comes with the gmsv_file package, a dependency of Flux: run '..
      '"fpkg install" to put gmsv_file_'..platform..'.dll in the garrysmod/lua/bin folder!\nAborting startup...\n'
    )
    return false
  end
end

include(FLUX_PATH..'lib/env.lua')

if !getenv or !getenv('FLUX_ENV') then return false end

include(FLUX_PATH..'lib/stdlib/sh_stdlib.lua')
include(FLUX_PATH..'lib/package.lua')

return true
