--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("roll")
COMMAND.name = "Roll"
COMMAND.description = "Roll a random number between 1 and 100 or specific number."
COMMAND.syntax = "[number Range]"
COMMAND.category = "roleplay"
COMMAND.arguments = 0

function COMMAND:OnRun(player, range)
	range = tonumber(range) or 100

	chatbox.AddText(nil, Color("purple"), player:Name().." has rolled "..math.random(1, range).." out of "..range..".", {sender = player, position = player:GetPos(), radius = config.Get("talk_radius"), hearWhenLook = true})
end

COMMAND:Register()