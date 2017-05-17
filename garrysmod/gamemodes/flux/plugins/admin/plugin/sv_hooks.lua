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

function flAdmin:DatabaseConnected()
	local queryObj = fl.db:Create("fl_bans")
		queryObj:Create("key", "INT NOT NULL AUTO_INCREMENT")
		queryObj:Create("steamID", "VARCHAR(25) NOT NULL")
		queryObj:Create("name", "VARCHAR(255) NOT NULL")
		queryObj:Create("unbanTime", "INT NOT NULL")
		queryObj:Create("banTime", "INT DEFAULT NULL")
		queryObj:Create("duration", "INT DEFAULT NULL")
		queryObj:Create("reason", "TEXT DEFAULT NULL")
		queryObj:PrimaryKey("key")
	queryObj:Execute()
end

function flAdmin:OnPlayerRestored(player)
	local root_steamid = config.Get("root_steamid")

	if (isstring(root_steamid)) then
		if (player:SteamID() == root_steamid) then
			player:SetUserGroup("root")
		end
	elseif (istable(root_steamid)) then
		for k, v in ipairs(root_steamid) do
			if (v == player:SteamID()) then
				player:SetUserGroup("root")
			end
		end
	end

	ServerLog(player:Name().." ("..player:GetUserGroup()..") has connected to the server.")
end