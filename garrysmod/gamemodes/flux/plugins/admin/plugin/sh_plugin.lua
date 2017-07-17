--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flAdmin")

util.Include("sv_hooks.lua")

function flAdmin:OnPluginLoaded()
	plugin.AddExtra("commands")
	plugin.AddExtra("groups")

	local folder = self:GetFolder().."/plugin"

	util.IncludeDirectory(folder.."/commands/")
	fl.admin:IncludeGroups(folder.."/groups/")
end

function flAdmin:PluginIncludeFolder(extra, folder)
	if (extra == "groups") then
		fl.admin:IncludeGroups(folder.."/groups/")

		return true
	end
end

function flAdmin:PlayerHasPermission(player, perm)
	return fl.admin:HasPermission(player, perm)
end

function flAdmin:PlayerIsRoot(player)
	return player:IsMemberOf("root")
end

function flAdmin:PlayerIsMemberOfGroup(player, group)
	for k, v in ipairs(player:GetSecondaryGroups()) do
		if (v == group) then
			return true
		end
	end

	return false
end