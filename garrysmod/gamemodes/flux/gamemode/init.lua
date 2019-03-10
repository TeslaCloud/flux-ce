Flux = Flux or {}
Flux.start_time = os.clock()

function safe_require(mod)
  local success, value = pcall(require, mod)

  if !success then
    ErrorNoHalt('Failed to open the "'..mod..'" module!\n')
    return false
  end

  return true
end

if Flux.initialized then
  if LITE_REFRESH then
    MsgC(Color(0, 255, 100, 255), 'Schema auto-reload in progress...\n')
  else
    MsgC(Color(0, 255, 100, 255), 'Lua auto-reload in progress...\n')
  end
end

if !LITE_REFRESH then
  if !safe_require 'fileio' then
    ErrorNoHalt('The fileio module has failed to load!\nPlease make sure that you have gmsv_fileio_'..((system.IsWindows() and 'win32') or 'linux')..'.dll in garrysmod/lua/bin folder!\nAborting startup...\n')
    return
  end

  -- Put that under an if because it doesn't change.
  if !string.utf8upper or !pon or !cable then
    AddCSLuaFile 'lib/vendor/utf8.min.lua'
    AddCSLuaFile 'lib/vendor/pon.min.lua'
    AddCSLuaFile 'lib/vendor/cable.min.lua'
  end

  AddCSLuaFile 'shared.lua'

  -- Include pON, Cable and UTF-8 library.
  if !string.utf8upper or !pon or !cable or !YAML then
    include 'lib/vendor/utf8.lua'
    include 'lib/vendor/pon.lua'
    include 'lib/vendor/cable.lua'
    YAML = include 'lib/vendor/yaml.lua'

    Settings = Settings or YAML.read('gamemodes/flux/config/settings.yml')
    DatabaseSettings = YAML.read('gamemodes/flux/config/database.yml')
  end
end

-- Initiate shared boot.
include 'shared.lua'

if Flux.initialized then
  MsgC(Color(0, 255, 100, 255), 'Auto-reloaded in '..math.Round(os.clock() - Flux.start_time, 3)..' second(s)\n')
else
  MsgC(Color(0, 255, 100, 255), 'Flux v'..GM.version..' ('..GM.code_name..') has finished loading in '..math.Round(os.clock() - Flux.start_time, 3)..' second(s)\n')
  Flux.initialized = true
end
