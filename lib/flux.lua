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

if CRATE then
  function CRATE:__installed__()
    if Flux.initialized then
      if !LITE_REFRESH then
        for k, v in pairs(self.metadata.deps) do
          Crate:reload(v)
        end
      else
        -- Reload flow either way since we actually need it's shared file.
        Crate:reload 'flow'
      end
    end

    Flux.include_schema()

    hook.Call('FluxCrateLoaded', GM or GAMEMODE)
    Flux.initialized = true
  end
end

-- The rest of the file is serverside-only.
if !SERVER then return end

Settings          = Settings or YAML.read('gamemodes/flux/config/settings.yml')
Settings.configs  = Settings.configs or YAML.read('gamemodes/flux/config/config.yml')
DatabaseSettings  = YAML.read('gamemodes/flux/config/database.yml')

LITE_REFRESH     = Flux.initialized and Settings.lite_refresh or false

AddCSLuaFile('_flux/environment.lua')
