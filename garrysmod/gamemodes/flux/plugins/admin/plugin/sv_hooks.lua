--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flAdmin:SavePlayerData(player, saveTable)
	saveTable.userGroup = player:GetUserGroup()
	saveTable.secondaryGroups = fl.Serialize(player:GetSecondaryGroups())
	saveTable.customPermissions = fl.Serialize(player:GetCustomPermissions())
end

function flAdmin:RestorePlayer(player, result)
	if (result.customPermissions) then
		player:SetCustomPermissions(fl.Deserialize(result.customPermissions))
	end

	if (result.secondaryGroups) then
		player:SetSecondaryGroups(fl.Deserialize(result.secondaryGroups))
	end

	if (result.userGroup) then
		player:SetUserGroup(result.userGroup)
	end
end