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
	local trace = player:GetEyeTraceNoCursor()
	local entity = trace.Entity

	if (!IsValid(entity)) then
		fl.player:Notify(player, "This is not a valid entity!")

		return
	end

	if (!entity:GetPersistent()) then
		fl.player:Notify(player, "This entity is not static!")

		return
	end

	entity:SetPersistent(false)

	fl.player:Notify(player, "You have removed this static entity!")
end

COMMAND:Register()