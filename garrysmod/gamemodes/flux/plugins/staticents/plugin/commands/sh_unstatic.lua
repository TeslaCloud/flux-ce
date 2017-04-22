--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("unstatic")
COMMAND.name = "UnStatic"
COMMAND.description = "Makes the entity you're looking at not static."
COMMAND.syntax = "[none]"
COMMAND.category = "misc"
COMMAND.aliases = {"staticpropremove", "staticremove"}

function COMMAND:OnRun(player)
	plugin.Call("PlayerMakeStatic", player, false)
end

COMMAND:Register()