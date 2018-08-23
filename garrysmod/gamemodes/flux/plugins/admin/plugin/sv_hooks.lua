function flAdmin:SavePlayerData(player, saveTable)
  saveTable.userGroup = player:GetUserGroup()
  saveTable.secondaryGroups = fl.serialize(player:GetSecondaryGroups())
  saveTable.customPermissions = fl.serialize(player:GetCustomPermissions())
end

function flAdmin:RestorePlayer(player, result)
  if (result.customPermissions) then
    player:SetCustomPermissions(fl.deserialize(result.customPermissions))
  end

  if (result.secondaryGroups) then
    player:SetSecondaryGroups(fl.deserialize(result.secondaryGroups))
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

  -- Restore all bans.
  local queryObj = fl.db:Select("fl_bans")
    queryObj:Callback(function(result)
      if (istable(result) and #result > 0) then
        for k, v in ipairs(result) do
          fl.admin:AddBan(v.steamID, v.name, v.banTime, v.unbanTime, v.duration, v.reason)
        end
      end
    end)
  queryObj:Execute()
end

function flAdmin:CheckPassword(steamID64, ip, svPass, clPass, name)
  local steamID = util.SteamIDFrom64(steamID64)
  local entry = fl.admin:GetBans()[steamID]

  if (entry and plugin.call("ShouldCheckBan", steamID, ip, name) != false) then
    if (entry.duration != 0 and entry.unbanTime >= os.time() and plugin.call("ShouldExpireBan", steamID, ip, name) != false) then
      self:RemoveBan(steamID)

      return true
    else
      return false, "You are still banned: "..tostring(entry.reason)
    end
  end
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

function flAdmin:CommandCheckImmunity(player, target, canBeEqual)
  return fl.admin:CheckImmunity(player, v, canBeEqual)
end

function flAdmin:OnCommandCreated(id, data)
  fl.admin:PermissionFromCommand(data)
end
