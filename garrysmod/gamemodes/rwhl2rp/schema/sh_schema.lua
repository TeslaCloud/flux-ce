--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

util.Include("cl_hooks.lua")

Schema.DefaultTheme = "hl2rp"

function Schema:IsCombineFaction(faction)
	return faction == "cca" or faction == "ota" or faction == "ca"
end

function Schema:PlayerIsCombine(player)
	return self:IsCombineFaction(player:GetFactionID())
end