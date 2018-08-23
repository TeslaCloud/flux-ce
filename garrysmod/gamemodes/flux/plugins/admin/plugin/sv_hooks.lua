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

function flAdmin:database_connected()
  create_table('fl_bans', function(t)
    t:primary_key 'id'
    t:string 'steam_id'
    t:string 'name'
    t:text 'reason'
    t:integer 'duration'
    t:timestamp 'unban_time'
    t:timestamp 'created_at'
    t:timestamp 'updated_at'
  end)

  -- Restore all bans.
  local query = fl.db:select("fl_bans")
    query:callback(function(result)
      if (istable(result) and #result > 0) then
        for k, v in ipairs(result) do
          fl.admin:AddBan(v.steam_id, v.name, v.banTime, v.unbanTime, v.duration, v.reason)
        end
      end
    end)
  query:execute()
end

function flAdmin:CheckPassword(steam_id64, ip, sv_pass, cl_pass, name)
  local steam_id = util.SteamIDFrom64(steam_id64)
  local entry = fl.admin:GetBans()[steam_id]

  if (entry and plugin.call("ShouldCheckBan", steam_id, ip, name) != false) then
    if (entry.duration != 0 and entry.unbanTime >= os.time() and plugin.call("ShouldExpireBan", steam_id, ip, name) != false) then
      self:RemoveBan(steam_id)

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
      player:SetUserGroup("admin")
    end
  elseif (istable(root_steamid)) then
    for k, v in ipairs(root_steamid) do
      if (v == player:SteamID()) then
        player:SetUserGroup("admin")
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
