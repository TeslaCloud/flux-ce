--[[
	Flux © 2016-2018 TeslaCloud Studios
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

	plugin.Call("PlayerMakeStatic", player, true)

 	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end

	local player = self:GetOwner()

	plugin.Call("PlayerMakeStatic", player, false)

	return true
end
