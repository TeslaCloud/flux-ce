--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

rw = rw or {}; -- Our namespace.
rw.startTime = os.clock(); -- For start time benchmarking.

function SafeRequire(mod)
	local success, value = pcall(require, mod)

	if (!success) then
		ErrorNoHalt("[Rework] Failed to open '"..mod.."' module!\n")

		return false
	end

	return true
end

if (rw.initialized) then
	MsgC(Color(0, 255, 100, 255), "[Rework] Lua auto-reload in progress...\n")
else
	MsgC(Color(0, 255, 100, 255), "[Rework] Initializing...\n")
end

if (!SafeRequire("fileio")) then
	ErrorNoHalt("[Rework] fileio module has failed to load!\nPlease make sure that you have gmsv_fileio_"..((system.IsWindows() and "win32") or "linux")..".dll in garrysmod/lua/bin folder!\nAborting startup...\n")
	return
end

if (!rw.WatchDogAvailable and system.IsWindows()) then
	if (file.Exists("lua/bin/gmsv_watchdog_win32.dll", "GAME")) then
		print("[Rework] Loading Watch Dog file monitoring tools...")

		local success = SafeRequire("watchdog")

		if (success) then
			timer.Create("WatchDogUpdater", (1 / 16), 0, function()
				WatchdogUpdate()
			end)

			hook.Add("WatchDogFileChanged", "WatchdogPluginWatcher", function(fileName)
				-- fileName is relative to garrysmod/gamemodes/
				print("[Watchdog] "..fileName)

				if (fileName:find("plugins")) then
					-- Prevent it from passing extra directories to the hook, as well as files it doesn't really need.
					if (fileName:EndsWith("plugins")) then return; end
					if (fileName:find("/plugin/")) then return; end
					if (fileName:find(".ini")) then return; end

					print("[Watchdog] Detected plugin change.")
					hook.Run("OnPluginFileChange", fileName)
				end
			end)

			rw.WatchDogAvailable = true
		else
			ErrorNoHalt("[Rework] Failed to load Watchdog!\nYou do not appear to have MS Visual C++ 2015 installed!\n")
		end
	end
end

-- A function to get whether watchdog module is available.
function rw.IsWatchdogAvailable()
	return rw.WatchDogAvailable
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

do
	local mysql_host = config.Get("mysql_host")
	local mysql_username = config.Get("mysql_username")
	local mysql_password = config.Get("mysql_password")
	local mysql_database = config.Get("mysql_database")
	local mysql_port = config.Get("mysql_port")

	rw.db:Connect(mysql_host, mysql_username, mysql_password, mysql_database, mysql_port)
end

if (rw.initialized) then
	MsgC(Color(0, 255, 100, 255), "[Rework] Auto-reloaded in "..math.Round(os.clock() - rw.startTime, 3).. " second(s)\n")
else
	MsgC(Color(0, 255, 100, 255), "[Rework] RW "..GM.Version.." loaded in "..math.Round(os.clock() - rw.startTime, 3).. " second(s)\n")
	rw.initialized = true
end