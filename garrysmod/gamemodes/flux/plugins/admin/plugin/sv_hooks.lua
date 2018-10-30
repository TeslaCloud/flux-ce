function Bolt:PlayerCreated(player, record)
  record.banned = record.banned or false
end

function Bolt:ActiveRecordReady()
  Ban:all():get(function(objects)
    for k, v in ipairs(objects) do
      fl.admin:record_ban(v.steam_id, v)
    end
  end)
end

function Bolt:CheckPassword(steam_id64, ip, sv_pass, cl_pass, name)
  local steam_id = util.SteamIDFrom64(steam_id64)
  local entry = fl.admin:get_bans()[steam_id]

  if entry and plugin.call('ShouldCheckBan', steam_id, ip, name) != false then
    if entry.duration != 0 and entry.unbanTime >= os.time() and plugin.call('ShouldExpireBan', steam_id, ip, name) != false then
      self:remove_ban(steam_id)

      return true
    else
      return false, 'You are still banned: '..tostring(entry.reason)
    end
  end
end

function Bolt:PlayerRestored(player, record)
  local root_steamid = config.get('root_steamid')

  if record.role then
    player:SetUserGroup(record.role)
  end

  if isstring(root_steamid) then
    if player:SteamID() == root_steamid then
      player:SetUserGroup('admin')
      player.can_anything = true
    end
  elseif istable(root_steamid) then
    for k, v in ipairs(root_steamid) do
      if v == player:SteamID() then
        player:SetUserGroup('admin')
        player.can_anything = true
      end
    end
  end

  if record.permissions then
    player:SetCustomPermissions(record.permissions)
  end

  Log:notify(player:Name()..' ('..player:GetUserGroup()..') has connected to the server.', { action = 'player_events' })
end

function Bolt:CommandCheckImmunity(player, target, can_equal)
  return fl.admin:CheckImmunity(player, v, can_equal)
end

function Bolt:OnCommandCreated(id, data)
  fl.admin:PermissionFromCommand(data)
end
