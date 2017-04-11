--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

TOOL.Category = "Flux"
TOOL.Name = "Static Add/Remove"
TOOL.Command = nil
TOOL.ConfigName = ""

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end

	local player = self:GetOwner()

	if (!IsValid(player) or !player:HasPermission("static")) then return end

	local entity = trace.Entity

	if (!IsValid(entity)) then
		fl.player:Notify(player, "This is not a valid entity!")

		return true
	end

	if (entity:GetPersistent()) then
		fl.player:Notify(player, "This entity is already static!")

		return true
	end

	entity:SetPersistent(true)

	fl.player:Notify(player, "You have added a static entity!")

 	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end

	local player = self:GetOwner()

	if (!IsValid(player) or !player:HasPermission("unstatic")) then return end

	local entity = trace.Entity

	if (!IsValid(entity)) then
		fl.player:Notify(player, "This is not a valid entity!")

		return true
	end

	if (!entity:GetPersistent()) then
		fl.player:Notify(player, "This entity is not static!")

		return true
	end

	entity:SetPersistent(false)

	fl.player:Notify(player, "You have removed this static entity!")

	return true
end