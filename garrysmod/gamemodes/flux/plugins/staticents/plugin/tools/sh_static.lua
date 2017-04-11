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

	plugin.Call("PlayerMakeStatic", player, true)

 	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end

	local player = self:GetOwner()

	if (!IsValid(player) or !player:HasPermission("unstatic")) then return end

	plugin.Call("PlayerMakeStatic", player, false)

	return true
end