--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("textremove")
COMMAND.name = "TextRemove"
COMMAND.description = "Removes a 3D text."
COMMAND.syntax = "[none]"
COMMAND.category = "misc"

function COMMAND:OnRun(player)
	fl3DText:Remove(player)
end

COMMAND:Register()