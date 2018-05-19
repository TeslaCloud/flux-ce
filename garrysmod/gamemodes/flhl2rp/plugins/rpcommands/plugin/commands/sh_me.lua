--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("me")
COMMAND.Name = "Me"
COMMAND.Description = "Describe your action."
COMMAND.Syntax = "<text>"
COMMAND.Category = "roleplay"
COMMAND.Aliases = {"perform", "e"}
COMMAND.Arguments = 1

function COMMAND:OnRun(player, ...)
	chatbox.AddText(nil, Color("green"), player:Name().." "..table.concat({...}, " "), {sender = player, position = player:GetPos(), radius = config.Get("talk_radius"), hearWhenLook = true})
end

COMMAND:Register()
