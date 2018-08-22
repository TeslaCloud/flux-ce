--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]fl = fl or {}
fl.startTime = os.clock()

-- Include pON, Netstream and UTF-8 library
if (!string.utf8len or !pon or !netstream) then
  include("thirdparty/utf8.lua")
  include("thirdparty/pon.lua")
  include("thirdparty/netstream.lua")
end

if (fl.initialized) then
  MsgC(Color(0, 255, 100, 255), "Lua auto-reload in progress...\n")
else
  MsgC(Color(0, 255, 100, 255), "Initializing...\n")
end

-- Initiate shared boot.
include("shared.lua")

font.CreateFonts()

if (fl.initialized) then
  MsgC(Color(0, 255, 100, 255), "Auto-reloaded in "..math.Round(os.clock() - fl.startTime, 3).. " second(s)\n")
else
  MsgC(Color(0, 255, 100, 255), "Flux v"..GM.Version.." has finished loading in "..math.Round(os.clock() - fl.startTime, 3).. " second(s)\n")

  fl.initialized = true
end
