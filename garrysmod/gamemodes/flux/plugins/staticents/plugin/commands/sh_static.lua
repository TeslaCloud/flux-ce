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
	local trace = player:GetEyeTraceNoCursor()
	local entity = trace.Entity

	if (!IsValid(entity)) then
		fl.player:Notify(player, "This is not a valid entity!")

		return
	end

	if (entity:GetPersistent()) then
		fl.player:Notify(player, "This entity is already static!")

		return
	end

	entity:SetPersistent(true)

	fl.player:Notify(player, "You have added a static entity!")
end

COMMAND:Register()