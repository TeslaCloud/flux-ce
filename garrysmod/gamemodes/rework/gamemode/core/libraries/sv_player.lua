--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("player", rw)

function rw.player:Notify(player, message)
	if (!IsValid(player)) then
		print("[Notification] "..message)
		return
	end

	netstream.Start(player, "rwNotification", message)
end

function rw.player:NotifyAll(message)
	ServerLog("NOTIFY - "..message)

	netstream.Start(nil, "rwNotification", message)
end

function rw.player:Save(player)
	if (!IsValid(player)) then return end

	rw.db:EasyWrite("rw_players", {"steamID", player:SteamID()}, {
		steamID = player:SteamID(),
		name = player:Name(),
		joinTime = player.rwJoinTime or os.time(),
		lastPlayTime = os.time(),
		userGroup = player:GetUserGroup(),
		secondaryGroups = rw.core:Serialize(player:GetSecondaryGroups()),
		customPermissions = rw.core:Serialize(player:GetCustomPermissions()),
		data = rw.core:Serialize(player:GetData()),
		whitelists = rw.core:Serialize(player:GetWhitelists())
	})
end

function rw.player:SaveUsergroup(player)
	if (!IsValid(player)) then return end

	rw.db:EasyWrite("rw_players", {"steamID", player:SteamID()}, {
		name = player:Name(),
		userGroup = player:GetUserGroup()
	})
end

function rw.player:SaveAllUsergroups(player)
	if (!IsValid(player)) then return end

	rw.db:EasyWrite("rw_players", {"steamID", player:SteamID()}, {
		steamID = player:SteamID(),
		name = player:Name(),
		userGroup = player:GetUserGroup(),
		secondaryGroups = rw.core:Serialize(player:GetSecondaryGroups()),
		customPermissions = rw.core:Serialize(player:GetCustomPermissions())
	})
end

function rw.player:Restore(player)
	if (!IsValid(player)) then return end

	rw.db:EasyRead("rw_players", {"steamID", player:SteamID()}, function(result, hasData)
		if (hasData) then
			result = result[1]

			if (result.whitelists) then
				player:SetWhitelists(rw.core:Deserialize(result.whitelists))
			end

			if (result.data) then
				player:SetData(rw.core:Deserialize(result.data))
			end

			if (result.customPermissions) then
				player:SetCustomPermissions(rw.core:Deserialize(result.customPermissions))
			end

			if (result.secondaryGroups) then
				player:SetSecondaryGroups(rw.core:Deserialize(result.secondaryGroups))
			end

			if (result.userGroup) then
				player:SetUserGroup(result.userGroup)
			end

			if (result.joinTime) then
				player.rwJoinTime = result.joinTime
			end

			if (result.lastPlayTime) then
				player.rwLastPlayTime = result.lastPlayTime
			end
		else
			print(player:Name().." has joined for the first time!")
			rw.player:Save(player)
		end

		hook.Run("OnPlayerRestored", player)
	end)
end

function rw.player:SetUserGroup(player, group)
	local groupObj = rw.admin:FindGroup(group)
	local oldGroupObj = rw.admin:FindGroup(player:GetUserGroup())

	if (oldGroupObj:OnGroupTake(player, groupObj) == nil) then
		player:SetUserGroup(group)

		if (groupObj:OnGroupSet(player, oldGroupObj) == nil) then
			self:SaveUsergroup(player)
		end
	end
end