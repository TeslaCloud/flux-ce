--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flAdmin")

util.Include("cl_hooks.lua")
util.Include("sv_hooks.lua")

function flAdmin:OnPluginLoaded()
	plugin.AddExtra("commands")
	plugin.AddExtra("groups")

	local folder = self:GetFolder().."/plugin"

	util.Include(folder.."/commands/")
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

function flAdmin:PlayerIsOwner(player)
	return player:IsMemberOf("owner")
end

function flAdmin:PlayerIsCoOwner(player)
	if (player:IsOwner()) then
		return true
	end

	local extraIDs = config.Get("owner_steamid_extra")

	if (istable(extraIDs)) then
		for k, v in ipairs(extraIDs) do
			if (v == player:SteamID()) then
				return true
			end
		end
	end

	return false
end

function flAdmin:PlayerIsMemberOfGroup(player, group)
	for k, v in ipairs(player:GetSecondaryGroups()) do
		if (v == group) then
			return true
		end
	end

	return false
end