if !Flux then
  require_relative 'flux_struct'
end

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
        -- Reload fluctuations either way since we actually need it's shared file.
        Crate:reload 'fluctuations'
      end
    end

    Flux.include_schema()

    hook.Call('FluxCrateLoaded', GM or GAMEMODE)
    Flux.initialized = true
  end
end

-- The rest of the file is serverside-only.
if !SERVER then return end

if !string.utf8upper or !pon or !Cable then
  AddCSLuaFile      'vendor/utf8.min.lua'
  AddCSLuaFile      'vendor/pon.min.lua'
  AddCSLuaFile      'vendor/cable.min.lua'
  AddCSLuaFile      'vendor/markdown.min.lua'
end

-- Include the required third-party libraries.
if !string.utf8upper or !pon or !Cable or !YAML then
  include           'vendor/utf8.lua'
  include           'vendor/pon.lua'
  Cable             = include 'vendor/cable.lua'
  Markdown          = include 'vendor/markdown.lua'
  YAML              = include 'vendor/yaml.lua'

  Settings          = Settings or YAML.read('gamemodes/flux/config/settings.yml')
  Settings.configs  = Settings.configs or YAML.read('gamemodes/flux/config/config.yml')
  DatabaseSettings  = YAML.read('gamemodes/flux/config/database.yml')
end
