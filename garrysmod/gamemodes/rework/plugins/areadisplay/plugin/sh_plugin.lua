--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

areas.RegisterType(
	"text",
	"Text Area",
	"An area that displays text when a player enters it.",
	function(player, area, poly, bHasEntered, curPos, curTime)
		if (bHasEntered) then
			plugin.Call("PlayerEnteredTextArea", player, area, curTime)
		else
			plugin.Call("PlayerLeftTextArea", player, area, curTime)
		end
	end
)

util.Include("cl_hooks.lua")
