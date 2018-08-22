--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]fl = fl or {}
fl.startTime = os.clock()

function SafeRequire(mod)
  local success, value = pcall(require, mod)

  if (!success) then
    ErrorNoHalt("Failed to open the '"..mod.."' module!\n")

    return false
  end

  return true
end

if (fl.initialized) then
  MsgC(Color(0, 255, 100, 255), "Lua auto-reload in progress...\n")
else
  MsgC(Color(0, 255, 100, 255), "Initializing...\n")
end

if (!SafeRequire("fileio")) then
  ErrorNoHalt("The fileio module has failed to load!\nPlease make sure that you have gmsv_fileio_"..((system.IsWindows() and "win32") or "linux")..".dll in garrysmod/lua/bin folder!\nAborting startup...\n")

  return
end

if (system.IsWindows() and fileio.CheckForChanges) then
  fl.WatchDogAvailable = true

  timer.Create("WatchDogUpdater", 0.25, 0, function()
    fileio.CheckForChanges()
  end)

  hook.Add("FileHasChanged", "WatchdogPluginWatcher", function(fileName, action)
    -- fileName is relative to garrysmod/gamemodes/
    local text = "not touched."

    if (action == FILE_ACTION_ADDED) then
      text = "added."
    elseif (action == FILE_ACTION_REMOVED) then
      text = "removed."
    elseif (action == FILE_ACTION_MODIFIED) then
      text = "modified."
    elseif (action == FILE_ACTION_RENAMED_OLD_NAME) then
      text = "renamed, this is it's old name."
    elseif (action == FILE_ACTION_RENAMED_NEW_NAME) then
      text = "renamed, this is it's new name."
    end

    fl.DevPrint("File action: '"..fileName.."' was "..text)
  end)
end

-- A function to get whether watchdog module is available.
function fl.IsWatchdogAvailable()
  return fl.WatchDogAvailable
end

-- Put that under an if because it doesn't change.
if (!string.utf8len or !pon or !netstream) then
  AddCSLuaFile("thirdparty/utf8.lua")
  AddCSLuaFile("thirdparty/pon.lua")
  AddCSLuaFile("thirdparty/netstream.lua")
end

AddCSLuaFile("shared.lua")

-- Include pON, Netstream and UTF-8 library.
if (!string.utf8len or !pon or !netstream) then
  include("thirdparty/utf8.lua")
  include("thirdparty/pon.lua")
  include("thirdparty/netstream.lua")
end

-- Initiate shared boot.
include("shared.lua")

if (fl.initialized) then
  MsgC(Color(0, 255, 100, 255), "Auto-reloaded in "..math.Round(os.clock() - fl.startTime, 3).. " second(s)\n")
else
  MsgC(Color(0, 255, 100, 255), "Flux v"..GM.Version.." has finished loading in "..math.Round(os.clock() - fl.startTime, 3).. " second(s)\n")

  fl.initialized = true
end
