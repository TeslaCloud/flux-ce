--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("roll")
COMMAND.Name = "Roll"
COMMAND.Description = "Roll a random number between 1 and 100 or specific number."
COMMAND.Syntax = "[number Range]"
COMMAND.Category = "roleplay"
COMMAND.Arguments = 0

function COMMAND:OnRun(player, range)
	range = tonumber(range) or 100

	chatbox.AddText(nil, Color("purple"), L("Chat_Roll", player:Name(), math.random(1, range), range), {sender = player, position = player:GetPos(), radius = config.Get("talk_radius"), hearWhenLook = true})
end

COMMAND:Register()