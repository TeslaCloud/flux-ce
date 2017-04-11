--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("static")
COMMAND.name = "Static"
COMMAND.description = "Makes the entity you're looking at static."
COMMAND.syntax = "[none]"
COMMAND.category = "misc"
COMMAND.aliases = {"staticadd", "staticpropadd"}

function COMMAND:OnRun(player)
	plugin.Call("PlayerMakeStatic", player, false)
end

COMMAND:Register()