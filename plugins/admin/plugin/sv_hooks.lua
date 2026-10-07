--- Checks connecting players against the ban cache. A timed ban that passes the expiry check
-- is lifted and the player let in; any other ban rejects the connection with its reason.
-- @param steam_id64 [String 64-bit SteamID of the connecting player]
-- @param ip [String]
-- @param sv_pass [String server password]
-- @param cl_pass [String password entered by the client]
-- @param name [String player name]
-- @return [Boolean true to allow or false to reject (nothing if there is no ban), String
--   rejection message (only when rejecting)]
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

--- Blocks tools that require a permission the player does not have.
-- @param player [Player]
-- @param trace [Map trace result of the tool use]
-- @param tool_name [String tool ID]
-- @return [Boolean false to block the tool, nothing otherwise]
function Bolt:CanTool(player, trace, tool_name)
  local tool = Flux.Tool:get(tool_name)

  if tool and tool.permission and !player:can(tool.permission) then
    return false
  end
end

--- Mutes talkers that lack the 'voice' permission.
-- @param player [Player the listener]
-- @param talker [Player]
-- @return [Boolean false if the talker may not be heard, nothing otherwise]
function Bolt:PlayerCanHearPlayersVoice(player, talker)
  if !talker:can('voice') then
    return false
  end
end

--- Defaults the banned flag of a newly created user record to false.
-- @param player [Player]
-- @param record [User the player's database record]
function Bolt:PlayerCreated(player, record)
  record.banned = record.banned or false
end

--- Loads all bans from the database into the ban cache.
function Bolt:ActiveRecordReady()
  Ban:all():get(function(objects)
    for k, v in ipairs(objects) do
      self:record_ban(v.steam_id, v)
    end
  end)
end

--- Applies a loaded user record to the player: sets their role, makes the SteamIDs from the
-- root_steamid config root admins, networks stored permissions and logs the connection.
-- @param player [Player]
-- @param record [User the player's database record]
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

  Log:notify(player:name()..' has connected to the server.', { action = 'player_events' })
end

--- Checks role immunity for commands that target players, by way of Bolt:check_immunity.
-- @param player [Player the caller]
-- @param target [Player the player being targeted]
-- @param can_equal=false [Boolean also pass when both roles have the same immunity]
-- @return [Boolean false if the caller may not target that player]
function Bolt:CommandCheckImmunity(player, target, can_equal)
  return self:check_immunity(player, v, can_equal)
end

--- Hides vanished and observing admins from a newly connected player, unless that player has
-- the 'moderator' permission.
-- @param player [Player the player that just connected]
function Bolt:PlayerInitialSpawn(player)
  for k, v in ipairs(_player.all()) do
    if (v.is_vanished or v:get_nv('observer')) and !player:can('moderator') then
      v:prevent_transmit(player, true)
    end
  end
end

--- Removes the player's expired temporary permissions.
-- @param player [Player]
function Bolt:PlayerOneMinute(player)
  for k, v in pairs(player:get_temp_permissions()) do
    if time_from_timestamp(v.expires) <= os.time() then
      self:delete_temp_permission(player, k)
    end
  end
end

--- Gives or strips the tool gun and the physgun when the matching permission changes.
-- @param player [Player]
-- @param perm_id [String permission ID]
-- @param value [Number new PERM_ value]
function Bolt:PlayerPermissionChanged(player, perm_id, value)
  if perm_id == 'toolgun' then
    if value == PERM_ALLOW then
      player:Give('gmod_tool')
    elseif value == PERM_NO then
      player:StripWeapon('gmod_tool')
    end
  elseif perm_id == 'physgun' then
    if value == PERM_ALLOW then
      player:Give('weapon_physgun')
    elseif value == PERM_NO then
      player:StripWeapon('weapon_physgun')
    end
  end
end

--- Gives or strips the tool gun and the physgun to match the player's new role.
-- @param player [Player]
-- @param group [Role the player's new role]
-- @param old_group [Role the player's previous role]
function Bolt:PlayerUserGroupChanged(player, group, old_group)
  if group:can('toolgun') then
    player:Give('gmod_tool')
  else
    player:StripWeapon('gmod_tool')
  end

  if group:can('physgun') then
    player:Give('weapon_physgun')
  else
    player:StripWeapon('weapon_physgun')
  end
end

--- Supplies the icon of the player's role for their chat messages.
-- @param player [Player the sender]
-- @param text [String message text]
-- @param team_chat [Boolean]
-- @return [Map icon data for the chatbox (icon, size, margin, is_data), or nothing if the
--   player is invalid]
function Bolt:ChatboxGetPlayerIcon(player, text, team_chat)
  if IsValid(player) then
    return { icon = player:get_role_table().icon or 'fa-user', size = 14, margin = 10, is_data = true }
  end
end

--- Get a list of all currently online staff members.
-- @return [Map - currently online staff members]
function Bolt:get_staff()
  return table.keep_if(player.all(), function(k, v) return v:can('staff') end)
end
