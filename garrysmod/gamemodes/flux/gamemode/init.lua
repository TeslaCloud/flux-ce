--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

fl = fl or {}
fl.startTime = os.clock()

function SafeRequire(mod)
	local success, value = pcall(require, mod)

	if (!success) then
		ErrorNoHalt("[Flux] Failed to open '"..mod.."' module!\n")

		return false
	end

	return true
end

if (fl.initialized) then
	MsgC(Color(0, 255, 100, 255), "[Flux] Lua auto-reload in progress...\n")
else
	MsgC(Color(0, 255, 100, 255), "[Flux] Initializing...\n")
end

if (!SafeRequire("fileio")) then
	ErrorNoHalt("[Flux] fileio module has failed to load!\nPlease make sure that you have gmsv_fileio_"..((system.IsWindows() and "win32") or "linux")..".dll in garrysmod/lua/bin folder!\nAborting startup...\n")

	return
end

if (system.IsWindows()) then
	timer.Create("WatchDogUpdater", (1 / 16), 0, function()
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

		if (fileName:find("plugins") and action == FILE_ACTION_ADDED) then
			-- Prevent it from passing extra directories to the hook, as well as files it doesn't really need.
			if (fileName:EndsWith("plugins")) then return end
			if (fileName:find("/plugin/")) then return end
			if (fileName:find(".json") or fileName:find(".ini")) then return end

			print("[Watchdog] Detected a new plugin.")
			--hook.Run("OnPluginFileChange", fileName)
		end
	end)
end

-- A function to get whether watchdog module is available.
function fl.IsWatchdogAvailable()
	return fl.WatchDogAvailable
end

-- Uninclude stuff that doesn't change.
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
	MsgC(Color(0, 255, 100, 255), "[Flux] Auto-reloaded in "..math.Round(os.clock() - fl.startTime, 3).. " second(s)\n")
else
	MsgC(Color(0, 255, 100, 255), "[Flux] Framework v"..GM.Version.." has loaded in "..math.Round(os.clock() - fl.startTime, 3).. " second(s)\n")

	fl.initialized = true
end