--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

rw = rw or {};
rw.startTime = os.clock();

--[[ 
	Include pON, Netstream and UTF-8 library 
--]]
if (!string.utf8len or !pon or !netstream) then
	include("thirdparty/utf8.lua");
	include("thirdparty/pon.lua");
	include("thirdparty/netstream.lua");
end;

if (rw.core) then
	MsgC(Color(0, 255, 100, 255), "[Rework] Lua auto-reload in progress...\n");
else
	MsgC(Color(0, 255, 100, 255), "[Rework] Initializing...\n");
end;

-- Include clientside core file.
include("shared.lua");

if (rw.initialized) then
	MsgC(Color(0, 255, 100, 255), "[Rework] Auto-reloaded in "..math.Round(os.clock() - rw.startTime, 3).. " second(s)\n");
else
	MsgC(Color(0, 255, 100, 255), "[Rework] RW "..GM.Version.." loaded in "..math.Round(os.clock() - rw.startTime, 3).. " second(s)\n");
	rw.initialized = true;
end;