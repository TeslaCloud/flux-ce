if !Flux then
  require_relative 'flux_struct'
end

if !Pipeline or !Plugin or !Config then
  require_relative 'pipeline'
  require_relative 'plugin'
  require_relative 'config'
end

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

if SERVER then
  function CRATE:__installed__()
    hook.Call('FluxCrateLoaded')
  end
end
