--- Entry point of Flux, included by both gamemode files of the schema.
-- Defines `FLUX_PATH`, opens the `file` binary module on the server, without which startup is
-- aborted, then loads the environment, the standard library and the package manager and
-- includes the project, the package of the schema's own folder, whose specification depends
-- on `flux` and through it on every other package. Once the packages are in, the schema is
-- included. On a code refresh the project, the `flux` package and, unless the refresh is a
-- lite one, the other dependencies of the project are reloaded instead.

AddCSLuaFile()

local start_time = os.clock()
local project = engine.ActiveGamemode()

--- Folder of the Flux package relative to the `LUA` search path, with a trailing slash.
FLUX_PATH = project..'/packages/flux/'

if SERVER then
  resource.AddWorkshop('1518849094')

  --- Includes a module and returns a boolean depending on success.
  -- Does not throw Lua errors.
  -- @param mod [String module name, as passed to require]
  -- @return [Boolean success]
  function require_module(mod)
    local success, _value = pcall(require, mod)

    if !success then
      ErrorNoHalt('Failed to open the "'..mod..'" module!\n')
      return false
    end

    return true
  end

  if !require_module 'file' then
    ErrorNoHalt(
      'The file module has failed to load!\nIt comes with the gmsv_file package, a dependency of Flux: run '..
      '"fpkg install" to put gmsv_file_'..((system.IsWindows() and 'win64') or 'linux64')..
      '.dll in the garrysmod/lua/bin folder!\nAborting startup...\n'
    )
    return
  end
end

include(FLUX_PATH..'lib/env.lua')
include(FLUX_PATH..'lib/stdlib/sh_stdlib.lua')
include(FLUX_PATH..'lib/package.lua')

local refresh = Flux.initialized

if refresh then
  Package:reload(project)
  Package:reload 'flux'

  if !LITE_REFRESH then
    for _, dep_name in ipairs(Package.installed[project].metadata.deps) do
      if dep_name != 'flux' then
        Package:reload(dep_name)
      end
    end
  end
else
  Package:include(project)
end

Flux.include_schema()

--- Called once the project, the Flux package, all of their dependencies and the schema with
-- its plugins have been included.
-- Runs on both the server and the client, on boot and again on every code refresh.
-- The return value is not used, but a non-nil one stops the handlers after it, the gamemode's
-- own included, which writes the client files on the server.
hook.Call('FluxPackageLoaded', GM or GAMEMODE)
Flux.initialized = true

if refresh then
  MsgC(Color(0, 255, 100, 255), 'Code reloaded in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
else
  MsgC(Color(0, 255, 100, 255), 'Boot complete in '..math.Round(os.clock() - start_time, 3)..' second(s)\n')
end

if CLIENT then
  Font.create_fonts()
end

print_debug_metrics()
