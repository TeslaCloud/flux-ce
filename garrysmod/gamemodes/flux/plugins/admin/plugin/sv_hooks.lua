function flAdmin:SavePlayerData(player, save_table)
  save_table.role = player:GetUserGroup()
  save_table.roles = fl.serialize(player:get_roles())
  save_table.permissions = fl.serialize(player:GetCustomPermissions())
end

function flAdmin:RestorePlayer(player, result)
  if (result.permissions) then
    player:SetCustomPermissions(result.permissions)
  end

  if (result.roles) then
    player:SetSecondaryGroups(result.roles)
  end

  if (result.role) then
    player:SetUserGroup(result.role)
  end
end

function flAdmin:ActiveRecordReady()
  Ban:all():get(function(objects)
    for k, v in ipairs(objects) do
      fl.admin:record_ban(v.steam_id, v)
    end
  end)
end

function flAdmin:CheckPassword(steam_id64, ip, sv_pass, cl_pass, name)
  local steam_id = util.SteamIDFrom64(steam_id64)
  local entry = fl.admin:get_bans()[steam_id]

  if (entry and plugin.call("ShouldCheckBan", steam_id, ip, name) != false) then
    if (entry.duration != 0 and entry.unbanTime >= os.time() and plugin.call("ShouldExpireBan", steam_id, ip, name) != false) then
      self:remove_ban(steam_id)

      return true
    else
      return false, "You are still banned: "..tostring(entry.reason)
    end
  end
end

function flAdmin:PlayerRestored(player, record)
  local root_steamid = config.Get("root_steamid")

  if (isstring(root_steamid)) then
    if (player:SteamID() == root_steamid) then
      player:SetUserGroup('moderator')
    end
  elseif (istable(root_steamid)) then
    for k, v in ipairs(root_steamid) do
      if (v == player:SteamID()) then
        player:SetUserGroup('moderator')
      end
    end
  end

  ServerLog(player:Name().." ("..player:GetUserGroup()..") has connected to the server.")
end

function flAdmin:CommandCheckImmunity(player, target, can_equal)
  return fl.admin:CheckImmunity(player, v, can_equal)
end

function flAdmin:OnCommandCreated(id, data)
  fl.admin:PermissionFromCommand(data)
end
