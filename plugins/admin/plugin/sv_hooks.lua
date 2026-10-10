--- Server-side hooks of the admin plugin: the ban check on connect, loading of the bans and
-- of each player's role and permissions from the database, the permission checks for tools,
-- chairs and voice chat, expiry of temporary permissions, and giving or stripping the tool
-- gun and the physgun as permissions change.

--- Checks connecting players against the ban cache. A timed ban that has expired is lifted
-- and the player let in; any other ban rejects the connection with the message of
-- Bolt:get_ban_message, which names its reason and the time it has left, including a ban
-- whose end time cannot be read.
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

  --- Called on the server when a connecting player has a ban on record, before the ban is
  -- enforced or lifted.
  -- @param steam_id [String SteamID of the connecting player]
  -- @param ip [String Address the player connects from]
  -- @param name [String Name of the connecting player]
  -- @return [Boolean Return false to ignore the ban, so that the admin plugin neither
  --   rejects the player nor lifts the ban]
  if entry and Plugin.call('ShouldCheckBan', steam_id, ip, name) != false then
    local unban_time = time_from_timestamp(entry.unban_time)

    if tonumber(entry.duration) != 0 and unban_time and unban_time <= os.time() and
       --- Called on the server when the temporary ban of a connecting player has expired
       -- and the admin plugin is about to lift it and let them in.
       -- @param steam_id [String SteamID of the connecting player]
       -- @param ip [String Address the player connects from]
       -- @param name [String Name of the connecting player]
       -- @return [Boolean Return false to keep the ban, so that the player is rejected with
       --   the reason of the ban]
       Plugin.call('ShouldExpireBan', steam_id, ip, name) != false then
      self:remove_ban(steam_id)

      return true
    else
      return false, self:get_ban_message(entry)
    end
  end
end

--- Blocks tools that require a permission the player does not have.
-- @param actor [Player]
-- @param trace [Map trace result of the tool use]
-- @param tool_name [String tool ID]
-- @return [Boolean false to block the tool, nothing otherwise]
function Bolt:CanTool(actor, trace, tool_name)
  local tool = Flux.Tool:get(tool_name)

  if tool and tool.permission and !actor:can(tool.permission) then
    return false
  end
end

--- Decides whether a player may spawn a chair: a seat of the vehicle list, which is a
-- 'prop_vehicle_prisoner_pod'. Chairs take the 'spawn_chairs' permission instead of the
-- 'spawn_vehicles' permission that the gamemode asks of every other vehicle. A player who
-- has both is left to the gamemode and to the other handlers of this hook. For a player
-- who may only spawn chairs the gamemode has to be overruled, which also skips the handlers
-- that come after this one; the chair is passed on to the FLPlayerSpawnVehicle hook the way
-- the gamemode passes vehicles on.
-- @param actor [Player]
-- @param model [String model of the vehicle]
-- @param name [String name of the vehicle in the vehicle list]
-- @param tab [Map vehicle table from the vehicle list]
-- @return [Boolean false if the player may not spawn chairs, true if they may spawn chairs
--   but no other vehicles; nothing if it is not a chair or the player may spawn vehicles
--   as well, which leaves the decision to the gamemode]
function Bolt:PlayerSpawnVehicle(actor, model, name, tab)
  if !IsValid(actor) or !istable(tab) or tab.Class != 'prop_vehicle_prisoner_pod' then return end

  if !actor:can('spawn_chairs') then
    return false
  end

  if actor:can('spawn_vehicles') then return end

  --- Run by the admin plugin when a player who has the `spawn_chairs` permission but not
  -- the `spawn_vehicles` one tries to spawn a chair, in place of the gamemode, which runs it
  -- for every other vehicle.
  -- @param actor [Player The player spawning the chair]
  -- @param model [String Model of the chair]
  -- @param name [String Name of the chair in the vehicle list]
  -- @param tab [Map Vehicle table from the vehicle list]
  -- @return [Boolean Return false to prevent the chair from being spawned]
  if hook.Run('FLPlayerSpawnVehicle', actor, model, name, tab) == false then
    return false
  end

  return true
end

--- Mutes talkers that lack the 'voice' permission.
-- @param listener [Player the listener]
-- @param talker [Player]
-- @return [Boolean false if the talker may not be heard, nothing otherwise]
function Bolt:PlayerCanHearPlayersVoice(listener, talker)
  if !talker:can('voice') then
    return false
  end
end

--- Defaults the banned flag of a newly created user record to false.
-- @param actor [Player]
-- @param record [User the player's database record]
function Bolt:PlayerCreated(actor, record)
  record.banned = record.banned or false
end

--- Loads all bans from the database into the ban cache.
function Bolt:ActiveRecordReady()
  Ban:all():get(function(objects)
    for k, v in ipairs(objects) do
      self:record_ban(v.steam_id, v)
    end
  end):fetch()
end

--- Applies a loaded user record to the player: sets their role, makes the SteamIDs from the
-- root_steamid config root admins, networks stored permissions, sends the config again if
-- the player turns out to be allowed to edit it, shows vanished and observing admins to
-- players with the 'moderate' permission and logs the connection.
-- @param actor [Player]
-- @param record [User the player's database record]
function Bolt:PlayerRestored(actor, record)
  local root_steamid = Config.get('root_steamid')

  if record.role then
    actor:SetUserGroup(record.role)
  end

  if isstring(root_steamid) then
    if actor:SteamID() == root_steamid then
      actor:SetUserGroup('admin')
      actor.can_anything = true
    end
  elseif istable(root_steamid) then
    local steam_id = actor:SteamID()

    for k, v in ipairs(root_steamid) do
      if v == steam_id then
        actor:SetUserGroup('admin')
        actor.can_anything = true
      end
    end
  end

  if record.permissions then
    local perm_table = {}

    for k, v in pairs(record.permissions) do
      perm_table[v.permission_id] = v.object
    end

    actor:set_permissions(perm_table)
  end

  if record.temp_permissions then
    local perm_table = {}

    for k, v in pairs(record.temp_permissions) do
      perm_table[v.permission_id] = {
        value = v.object,
        expires = time_from_timestamp(v.expires) or 0
      }
    end

    actor:set_temp_permissions(perm_table)
  end

  self:update_config_access(actor)

  if actor:can('moderate') then
    for k, v in player.Iterator() do
      if v.is_vanished or v:get_nv('observer') then
        v:prevent_transmit(actor, false)
      end
    end
  end

  Log:notify(actor:name()..' has connected to the server.', { action = 'player_events' })
end

--- Remembers whether the player could edit configs when the config was first sent to them,
-- which the gamemode does right before this hook. Bolt:update_config_access compares against
-- it to tell when the config has to be sent again.
-- @param actor [Player the player whose client has finished loading]
function Bolt:PlayerInitialized(actor)
  actor.bolt_config_access = Config.can_manage(actor)
end

--- Checks role immunity for commands that target players, by way of Bolt:check_immunity:
-- the caller's role must have a higher immunity than the target's, except that callers may
-- always target themselves and root players may target anyone.
-- @param actor [Player the caller]
-- @param target [Player the player being targeted]
-- @param can_equal=false [Boolean also pass when both roles have the same immunity]
-- @return [Boolean false if the caller may not target that player]
function Bolt:CommandCheckImmunity(actor, target, can_equal)
  return self:check_immunity(actor, target, can_equal)
end

--- Hides vanished and observing admins from a newly connected player. The player's role is
-- not known yet at this point; Bolt:PlayerRestored shows them again if the player turns out
-- to have the 'moderate' permission.
-- @param actor [Player the player that just connected]
function Bolt:PlayerInitialSpawn(actor)
  for k, v in player.Iterator() do
    if v.is_vanished or v:get_nv('observer') then
      v:prevent_transmit(actor, true)
    end
  end
end

--- Removes the player's expired temporary permissions.
-- @param actor [Player]
function Bolt:PlayerOneMinute(actor)
  local now = os.time()

  for k, v in pairs(actor:get_temp_permissions()) do
    if v.expires <= now then
      self:delete_temp_permission(actor, k)
    end
  end
end

--- Gives or strips the tool gun or the physgun when the matching individual permission
-- changes, going by what the player may do now (role, individual and temporary permissions
-- together): unsetting the permission leaves the tool with a player whose role allows it,
-- and PERM_NEVER takes it away. Does nothing while the player is dead; they get the tools
-- they are allowed when they spawn. Any permission change also sends the config to the
-- player again if it has changed their right to edit configs.
-- @param target [Player]
-- @param perm_id [String permission ID]
-- @param value [Number new PERM_ value]
function Bolt:PlayerPermissionChanged(target, perm_id, value)
  self:update_config_access(target)

  if perm_id != 'toolgun' and perm_id != 'physgun' then return end
  if !target:Alive() then return end

  local weapon_class = perm_id == 'toolgun' and 'gmod_tool' or 'weapon_physgun'

  if target:can(perm_id) then
    target:Give(weapon_class)
  else
    target:StripWeapon(weapon_class)
  end
end

--- Gives or strips the tool gun and the physgun after the player's role has changed, going
-- by the 'toolgun' and 'physgun' permissions the player has now (role, individual and
-- temporary permissions together). Does nothing while the player is dead; they get the tools
-- they are allowed when they spawn. Also sends the config to the player again if the new
-- role has changed their right to edit configs.
-- @param target [Player]
-- @param group [Role the player's new role, nil if its ID is not registered]
-- @param old_group [Role the player's previous role]
function Bolt:PlayerUserGroupChanged(target, group, old_group)
  self:update_config_access(target)

  if !target:Alive() then return end

  if target:can('toolgun') then
    target:Give('gmod_tool')
  else
    target:StripWeapon('gmod_tool')
  end

  if target:can('physgun') then
    target:Give('weapon_physgun')
  else
    target:StripWeapon('weapon_physgun')
  end
end

--- Supplies the icon of the player's role for their chat messages.
-- @param speaker [Player the sender]
-- @param text [String message text]
-- @param team_chat [Boolean]
-- @return [Map icon data for the chatbox (icon, size, margin, is_data), or nothing if the
--   player is invalid]
function Bolt:ChatboxGetPlayerIcon(speaker, text, team_chat)
  if IsValid(speaker) then
    return { icon = speaker:get_role_table().icon or 'fa-user', size = 14, margin = 10, is_data = true }
  end
end

--- Get a list of all currently online staff members.
-- @return [Map - currently online staff members]
function Bolt:get_staff()
  return table.keep_if(player.GetAll(), function(k, v) return v:can('staff') end)
end
