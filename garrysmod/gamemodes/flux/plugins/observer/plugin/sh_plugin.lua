--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flObserver")

util.Include("cl_hooks.lua")
util.Include("sv_hooks.lua")

fl.admin:RegisterPermission("noclip", "Noclip", "Lets the player use observer mode / noclip.", "general")

if (SERVER) then
	config.Set("observer_reset", true)
else
	config.AddToMenu("observer_reset", "Observer Reset", "Whether or not should player's position be restored when they leave observer mode?", "boolean")
end