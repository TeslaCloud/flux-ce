--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("it")
COMMAND.name = "It"
COMMAND.description = "Describe something."
COMMAND.syntax = "<text>"
COMMAND.category = "roleplay"
COMMAND.aliases = {"do"}
COMMAND.arguments = 1

function COMMAND:OnRun(player, ...)
	chatbox.AddText(nil, Color("lightblue"), "("..player:Name()..") "..table.concat({...}, " "), {sender = player, position = player:GetPos(), radius = config.Get("talk_radius"), hearWhenLook = true})
end

COMMAND:Register()