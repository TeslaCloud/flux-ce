--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local playerMeta = FindMetaTable("Player")

function playerMeta:HasInitialized()
	return self:GetDTBool(BOOL_INITIALIZED) or false
end

function playerMeta:GetData()
	return self:GetNetVar("flData", {})
end

function playerMeta:GetWhitelists()
	return self:GetNetVar("whitelists", {})
end

function playerMeta:HasWhitelist(name)
	return table.HasValue(self:GetWhitelists(), name)
end

playerMeta.flName = playerMeta.flName or playerMeta.Name

function playerMeta:Name(bForceTrueName)
	return (!bForceTrueName and self.nameOverride) or self:GetNetVar("name", self:flName())
end

function playerMeta:SteamName()
	return self:flName()
end

function playerMeta:SetModel(sPath)
	local oldModel = self:GetModel()

	hook.Run("PlayerModelChanged", self, sPath, oldModel)

	if (SERVER) then
		netstream.Start(nil, "PlayerModelChanged", self:EntIndex(), sPath, oldModel)
	end

	return self:flSetModel(sPath)
end

--[[
	Actions system
--]]

function playerMeta:SetAction(id, bForce)
	if (bForce or self:GetAction() == "none") then
		self:SetNetVar("action", id)

		return true
	end
end

function playerMeta:GetAction()
	return self:GetNetVar("action", "none")
end

function playerMeta:IsDoingAction(id)
	return (self:GetAction() == id)
end

function playerMeta:ResetAction()
	self:SetAction("none", true)
end

function playerMeta:DoAction(id)
	local act = self:GetAction()

	if (isstring(id)) then
		act = id
	end

	if (act and act != "none") then
		local actionTable = fl.GetAction(act)

		if (istable(actionTable) and isfunction(actionTable.callback)) then
			try {
				actionTable.callback, self, act
			} catch {
				function(exception)
					ErrorNoHalt("[Flux] Player action '"..tostring(act).."' has failed to run!\n"..exception.."\n")
				end
			}
		end
	end
end

--[[
	Admin system

	Hook your admin mods to these functions, they're universally used
	throughout Flux framework.
--]]

function playerMeta:HasPermission(perm)
	return hook.Run("PlayerHasPermission", self, perm)
end

function playerMeta:IsRoot()
	return hook.Run("PlayerIsRoot", self)
end

function playerMeta:IsMemberOf(group)
	if (self:GetUserGroup() == group) then
		return true
	end

	return hook.Run("PlayerIsMemberOfGroup", self, group)
end
