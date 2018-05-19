--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flAttributes")

util.Include("sv_hooks.lua")

function flAttributes:OnPluginLoaded()
	local dir = self:GetFolder().."/plugin/"

	attributes.RegisterType("skills", "SKILL", dir.."skills/")
	attributes.RegisterType("stats", "STAT", dir.."stats/")
	attributes.RegisterType("perks", "PERK", dir.."perks/")
end

function flAttributes:PluginIncludeFolder(extra, folder)
	for k, v in pairs(attributes.types) do
		if (extra == k) then
			attributes.IncludeType(k, v, folder.."/"..k.."/")

			return true
		end
	end
end
