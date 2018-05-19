--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("unstatic")
COMMAND.Name = "UnStatic"
COMMAND.Description = "Makes the entity you're looking at not static."
COMMAND.Syntax = "[none]"
COMMAND.Category = "misc"
COMMAND.Aliases = {"staticpropremove", "staticremove"}

function COMMAND:OnRun(player)
	plugin.Call("PlayerMakeStatic", player, false)
end

COMMAND:Register()
