--- Core of the Flux package, included as a dependency by its package specification.
-- Sets the environment constants (`IS_PRODUCTION`, `IS_DEVELOPMENT` and `IS_TEST`), loads the
-- `Pipeline`, `Plugin` and `Config` libraries and defines what happens once the package and
-- all of its dependencies have been included: the schema is loaded and the FluxPackageLoaded
-- hook runs. On the server it also reads `settings.yml`, `config.yml` and `database.yml` from
-- the gamemode's `config` folder into the `Settings` and `DatabaseSettings` globals.

AddCSLuaFile()

if !Flux then
  require_relative 'flux_struct'
end

IS_PRODUCTION    = ENV['FLUX_ENV'] == 'production'
IS_DEVELOPMENT   = !IS_PRODUCTION
IS_TEST          = ENV['FLUX_ENV'] == 'test'

Flux.development = !IS_PRODUCTION

if !Pipeline or !Plugin or !Config then
  require_relative 'pipeline'
  require_relative 'plugin'
  require_relative 'config'
end

if PACKAGE then
  --- Called by the Package manager once the Flux package has been included.
  -- Reloads the dependencies when this is a code refresh, includes the schema and runs the
  -- FluxPackageLoaded hook.
  function PACKAGE:__installed__()
    if Flux.initialized then
      if !LITE_REFRESH then
        for k, v in pairs(self.metadata.deps) do
          Package:reload(v)
        end
      else
        -- Reload flow either way since we actually need its shared file.
        Package:reload 'flow'
      end
    end

    Flux.include_schema()

    --- Called once the Flux package, all of its dependencies and the schema with its plugins
    -- have been included.
    -- Runs on both the server and the client, on boot and again every time a code refresh
    -- reloads the package.
    hook.Call('FluxPackageLoaded', GM or GAMEMODE)
    Flux.initialized = true
  end
end

-- The rest of the file is serverside-only.
if !SERVER then return end

Settings          = Settings or YAML.read('gamemodes/flux/config/settings.yml')
Settings.configs  = Settings.configs or YAML.read('gamemodes/flux/config/config.yml')
DatabaseSettings  = YAML.read('gamemodes/flux/config/database.yml')

LITE_REFRESH = Flux.initialized and Settings.lite_refresh or false

AddCSLuaFile('_flux/environment.lua')
