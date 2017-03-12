--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("player", fl)

function fl.player:Notify(player, message)
	if (!IsValid(player)) then
		print("[Notification] "..message)
		return
	end

	netstream.Start(player, "flNotification", message)
end

function fl.player:NotifyAll(message)
	ServerLog("NOTIFY - "..message)

	netstream.Start(nil, "flNotification", message)
end

function fl.player:Save(player)
	if (!IsValid(player)) then return end

	fl.db:EasyWrite("fl_players", {"steamID", player:SteamID()}, {
		steamID = player:SteamID(),
		name = player:Name(),
		joinTime = player.flJoinTime or os.time(),
		lastPlayTime = os.time(),
		userGroup = player:GetUserGroup(),
		secondaryGroups = fl.core:Serialize(player:GetSecondaryGroups()),
		customPermissions = fl.core:Serialize(player:GetCustomPermissions()),
		data = fl.core:Serialize(player:GetData()),
		whitelists = fl.core:Serialize(player:GetWhitelists())
	})
end

function fl.player:SaveUsergroup(player)
	if (!IsValid(player)) then return end

	fl.db:EasyWrite("fl_players", {"steamID", player:SteamID()}, {
		name = player:Name(),
		userGroup = player:GetUserGroup()
	})
end

function fl.player:SaveAllUsergroups(player)
	if (!IsValid(player)) then return end

	fl.db:EasyWrite("fl_players", {"steamID", player:SteamID()}, {
		steamID = player:SteamID(),
		name = player:Name(),
		userGroup = player:GetUserGroup(),
		secondaryGroups = fl.core:Serialize(player:GetSecondaryGroups()),
		customPermissions = fl.core:Serialize(player:GetCustomPermissions())
	})
end

function fl.player:Restore(player)
	if (!IsValid(player)) then return end

	fl.db:EasyRead("fl_players", {"steamID", player:SteamID()}, function(result, hasData)
		if (hasData) then
			result = result[1]

			if (result.whitelists) then
				player:SetWhitelists(fl.core:Deserialize(result.whitelists))
			end

			if (result.data) then
				player:SetData(fl.core:Deserialize(result.data))
			end

			if (result.customPermissions) then
				player:SetCustomPermissions(fl.core:Deserialize(result.customPermissions))
			end

			if (result.secondaryGroups) then
				player:SetSecondaryGroups(fl.core:Deserialize(result.secondaryGroups))
			end

			if (result.userGroup) then
				player:SetUserGroup(result.userGroup)
			end

			if (result.joinTime) then
				player.flJoinTime = result.joinTime
			end

			if (result.lastPlayTime) then
				player.flLastPlayTime = result.lastPlayTime
			end
		else
			print(player:Name().." has joined for the first time!")
			fl.player:Save(player)
		end

		hook.Run("OnPlayerRestored", player)
	end)
end

function fl.player:SetUserGroup(player, group)
	local groupObj = fl.admin:FindGroup(group)
	local oldGroupObj = fl.admin:FindGroup(player:GetUserGroup())

	if (oldGroupObj:OnGroupTake(player, groupObj) == nil) then
		player:SetUserGroup(group)

		if (groupObj:OnGroupSet(player, oldGroupObj) == nil) then
			self:SaveUsergroup(player)
		end
	end
end