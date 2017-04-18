--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local playerMeta = FindMetaTable("Player")

function playerMeta:SetWhitelists(data)
	self:SetNetVar("whitelists", data)
	self:SavePlayer()
end

function playerMeta:GiveWhitelist(name)
	local whitelists = self:GetWhitelists()

	if (!table.HasValue(whitelists, name)) then
		table.insert(whitelists, name)

		self:SetWhitelists(whitelists)
	end
end

function playerMeta:TakeWhitelist(name)
	local whitelists = self:GetWhitelists()

	for k, v in ipairs(whitelists) do
		if (v == name) then
			table.remove(whitelists, k)

			break
		end
	end

	self:SetWhitelists(whitelists)
end

function playerMeta:SavePlayer()
	fl.db:EasyWrite("fl_players", {"steamID", self:SteamID()}, {
		steamID = self:SteamID(),
		name = self:Name(),
		joinTime = self.flJoinTime or os.time(),
		lastPlayTime = os.time(),
		userGroup = self:GetUserGroup(),
		secondaryGroups = fl.core:Serialize(self:GetSecondaryGroups()),
		customPermissions = fl.core:Serialize(self:GetCustomPermissions()),
		data = fl.core:Serialize(self:GetData()),
		whitelists = fl.core:Serialize(self:GetWhitelists())
	})
end

function playerMeta:SetData(data)
	self:SetNetVar("flData", {})
end

function playerMeta:SetInitialized(bIsInitialized)
	if (bIsInitialized == nil) then bIsInitialized = true end

	self:SetDTBool(BOOL_INITIALIZED, bIsInitialized)
end

function playerMeta:Notify(message)
	fl.player:Notify(self, message)
end

--[[
	Admin system
--]]

function playerMeta:SaveUsergroup()
	fl.db:EasyWrite("fl_players", {"steamID", self:SteamID()}, {
		name = self:Name(),
		userGroup = self:GetUserGroup()
	})
end

function playerMeta:SaveAllUsergroups()
	fl.db:EasyWrite("fl_players", {"steamID", self:SteamID()}, {
		steamID = self:SteamID(),
		name = self:Name(),
		userGroup = self:GetUserGroup(),
		secondaryGroups = fl.core:Serialize(self:GetSecondaryGroups()),
		customPermissions = fl.core:Serialize(self:GetCustomPermissions())
	})
end

function playerMeta:RestorePlayer()
	fl.db:EasyRead("fl_players", {"steamID", self:SteamID()}, function(result, hasData)
		if (hasData) then
			result = result[1]

			if (result.whitelists) then
				self:SetWhitelists(fl.core:Deserialize(result.whitelists))
			end

			if (result.data) then
				self:SetData(fl.core:Deserialize(result.data))
			end

			if (result.customPermissions) then
				self:SetCustomPermissions(fl.core:Deserialize(result.customPermissions))
			end

			if (result.secondaryGroups) then
				self:SetSecondaryGroups(fl.core:Deserialize(result.secondaryGroups))
			end

			if (result.userGroup) then
				self:SetUserGroup(result.userGroup)
			end

			if (result.joinTime) then
				self.flJoinTime = result.joinTime
			end

			if (result.lastPlayTime) then
				self.flLastPlayTime = result.lastPlayTime
			end
		else
			ServerLog(self:Name().." has joined for the first time!")

			self:SavePlayer()
		end

		hook.Run("OnPlayerRestored", self)
	end)
end

function playerMeta:SetPermissions(permTable)
	self:SetNetVar("flPermissions", permTable)
end

function playerMeta:SetUserGroup(group)
	group = group or "user"

	local groupObj = fl.admin:FindGroup(group)
	local oldGroupObj = fl.admin:FindGroup(self:GetUserGroup())

	self:SetNetVar("flUserGroup", group)

	if (oldGroupObj and groupObj and oldGroupObj:OnGroupTake(self, groupObj) == nil) then
		if (groupObj:OnGroupSet(self, oldGroupObj) == nil) then
			self:SaveUsergroup()
		end
	end

	fl.admin:CompilePermissions(self)
end

function playerMeta:SetSecondaryGroups(groups)
	self:SetNetVar("flSecondaryGroups", groups)

	fl.admin:CompilePermissions(self)
end

function playerMeta:AddSecondaryGroup(group)
	if (group == "owner" or group == "") then return end

	local groups = self:GetSecondaryGroups()

	table.insert(groups, group)

	self:SetNetVar("flSecondaryGroups", groups)

	fl.admin:CompilePermissions(self)
end

function playerMeta:RemoveSecondaryGroup(group)
	local groups = self:GetSecondaryGroups()

	for k, v in ipairs(groups) do
		if (v == group) then
			table.remove(groups, k)

			break
		end
	end

	self:SetNetVar("flSecondaryGroups", groups)

	fl.admin:CompilePermissions(self)
end

function playerMeta:SetCustomPermissions(data)
	self:SetNetVar("flCustomPermissions", data)

	fl.admin:CompilePermissions(self)
end