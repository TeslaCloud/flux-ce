--- Entry point of Flux, included by both gamemode files of the schema.
-- Defines `FLUX_PATH` and runs the first stages of the boot that fpkg's tasks share
-- (`lib/start.lua`: the `file` binary module on the server, the environment, the standard
-- library and the package manager), which stop start-up when they fail. Then it includes the
-- project, the package of the schema's own folder, whose specification depends on `flux` and
-- through it on every other package. Once the packages are in, the schema is included. On a
-- code refresh the hook and load caches of `Plugin` are cleared first, then the project, the
-- `flux` package and, unless the refresh is a lite one, the other dependencies of the project
-- are reloaded instead.

AddCSLuaFile()

local start_time = os.clock()
local project = engine.ActiveGamemode()

--- Folder of the Flux package relative to the `LUA` search path, with a trailing slash.
FLUX_PATH = project..'/packages/flux/'

if SERVER then
  resource.AddWorkshop('1518849094')
end

if !include(FLUX_PATH..'lib/start.lua') then return end

local refresh = Flux.initialized

--- Whether this code refresh is a lite one, which only reloads the schema and the code outside
-- of the framework: true during a refresh on the server when `lite_refresh` is on in
-- `settings.yml`, false on the first boot and on the client, which always makes a full refresh.
LITE_REFRESH = refresh and SERVER and Settings.lite_refresh or false

if refresh then
  Plugin.clear_cache()
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

print_debug_metrics()
