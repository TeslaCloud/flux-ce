function Bolt:CheckPassword(steam_id64, ip, sv_pass, cl_pass, name)
  local steam_id = util.SteamIDFrom64(steam_id64)
  local entry = self:get_bans()[steam_id]

  if entry and Plugin.call('ShouldCheckBan', steam_id, ip, name) != false then
    if entry.duration != 0 and entry.unban_time >= os.time() and Plugin.call('ShouldExpireBan', steam_id, ip, name) != false then
      self:remove_ban(steam_id)

      return true
    else
      return false, 'You are still banned: '..tostring(entry.reason)
    end
  end
end

function Bolt:CanTool(player, trace, tool_name)
  local tool = Flux.Tool:get(tool_name)

  if tool and tool.permission and !player:can(tool.permission) then
    return false
  end
end

function Bolt:PlayerCreated(player, record)
  record.banned = record.banned or false
end

function Bolt:ActiveRecordReady()
  Ban:all():get(function(objects)
    for k, v in ipairs(objects) do
      self:record_ban(v.steam_id, v)
    end
  end)
end

function Bolt:PlayerRestored(player, record)
  local root_steamid = Config.get('root_steamid')

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
    local perm_table = {}

    for k, v in pairs(record.permissions) do
      perm_table[v.permission_id] = v.object
    end

    player:set_permissions(perm_table)
  end

  if record.temp_permissions then
    local perm_table = {}

    for k, v in pairs(record.temp_permissions) do
      perm_table[v.permission_id] = {
        value = v.object,
        expires = time_from_timestamp(v.expires)
      }
    end

    player:set_permissions(perm_table)
  end

  Log:notify(player:name()..' ('..player:GetUserGroup()..') has connected to the server.', { action = 'player_events' })
end

function Bolt:CommandCheckImmunity(player, target, can_equal)
  return self:check_immunity(player, v, can_equal)
end

-- Vanish admins for newly connected players.
function Bolt:PlayerInitialSpawn(player)
  for k, v in ipairs(_player.GetAll()) do
    if (v.is_vanished or v:get_nv('observer')) and !player:can('moderator') then
      v:prevent_transmit(player, true)
    end
  end
end
