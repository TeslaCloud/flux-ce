--- Server-side hooks of Bolt, registered as `Bolt`: the ban check on connect, loading of the
-- bans and of each player's role and permissions from the database, telling open ban list
-- pages that the bans have changed, the permission checks for tools, chairs and voice chat,
-- expiry of temporary permissions, applying and deleting the permissions of characters, giving
-- or stripping the tool gun and the physgun as permissions change.

local voice_check_interval = 1

local hooks = {}

--- Checks connecting players against the ban cache, see `Bolt:get_enforced_ban`. A timed ban
-- that has expired is lifted and the connection left to the other checks, such as the server
-- password; any other ban rejects the connection with the message of Bolt:get_ban_message,
-- which names its reason and the time it has left, including a ban whose end time cannot be
-- read.
-- @param steam_id64 [String 64-bit SteamID of the connecting player]
-- @param ip [String]
-- @param _sv_pass [String server password]
-- @param _cl_pass [String password entered by the client]
-- @param name [String player name]
-- @return [Boolean false to reject (nothing otherwise), String rejection message (only when
--   rejecting)]
function hooks:CheckPassword(steam_id64, ip, _sv_pass, _cl_pass, name)
  local entry = Bolt:get_enforced_ban(util.SteamIDFrom64(steam_id64), ip, name)

  if entry then
    return false, Bolt:get_ban_message(entry)
  end
end

--- Blocks tools that require a permission the player does not have.
-- @param actor [Player]
-- @param _trace [Map trace result of the tool use]
-- @param tool_name [String tool ID]
-- @return [Boolean false to block the tool, nothing otherwise]
function hooks:CanTool(actor, _trace, tool_name)
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
-- that come after this one; the chair is passed on to the PlayerCanSpawnVehicle hook the way
-- the gamemode passes vehicles on.
-- @param actor [Player]
-- @param model [String model of the vehicle]
-- @param name [String name of the vehicle in the vehicle list]
-- @param tab [Map vehicle table from the vehicle list]
-- @return [Boolean false if the player may not spawn chairs, true if they may spawn chairs
--   but no other vehicles; nothing if it is not a chair or the player may spawn vehicles
--   as well, which leaves the decision to the gamemode]
function hooks:PlayerSpawnVehicle(actor, model, name, tab)
  if !IsValid(actor) or !istable(tab) or tab.Class != 'prop_vehicle_prisoner_pod' then return end

  if !actor:can('spawn_chairs') then
    return false
  end

  if actor:can('spawn_vehicles') then return end

  --- Run by Bolt when a player who has the `spawn_chairs` permission but not
  -- the `spawn_vehicles` one tries to spawn a chair, in place of the gamemode, which runs it
  -- for every other vehicle.
  -- @param actor [Player The player spawning the chair]
  -- @param model [String Model of the chair]
  -- @param name [String Name of the chair in the vehicle list]
  -- @param tab [Map Vehicle table from the vehicle list]
  -- @return [Boolean Return false to prevent the chair from being spawned]
  if hook.Run('PlayerCanSpawnVehicle', actor, model, name, tab) == false then
    return false
  end

  return true
end

--- Mutes talkers that lack the 'voice' permission. The engine asks for every pair of players
-- many times a second, so the answer is kept on the talker for a second, and forgotten as soon
-- as their role or one of their permissions changes.
-- @param _listener [Player the listener]
-- @param talker [Player]
-- @return [Boolean false if the talker may not be heard, nothing otherwise]
function hooks:PlayerCanHearPlayersVoice(_listener, talker)
  local cur_time = CurTime()

  if (talker.bolt_voice_until or 0) <= cur_time then
    talker.bolt_voice_muted = !talker:can('voice')
    talker.bolt_voice_until = cur_time + voice_check_interval
  end

  if talker.bolt_voice_muted then
    return false
  end
end

--- Gives a player who has just connected the `user` role until their record has loaded,
-- without signaling CAMI, unless they are kicked for a ban first, see `Bolt:kick_if_banned`.
-- While Bolt defers to another admin mod, the usergroup is left to that admin mod.
-- @param actor [Player]
function hooks:PlayerInitialSpawn(actor)
  if Bolt:kick_if_banned(actor) then return end

  if !Bolt:uses_external_admin() then
    actor:set_role_id('user', true)
  end
end

--- Kicks a player whose SteamID, or that of the owner of the game they play through family
-- sharing, is banned, once Steam has confirmed both, see `Bolt:kick_if_banned`.
-- @param actor [Player]
-- @param _steam_id [String]
-- @param _unique_id [String]
function hooks:PlayerAuthed(actor, _steam_id, _unique_id)
  Bolt:kick_if_banned(actor)
end

--- Loads the individual and the temporary permissions of a player together with their user
-- record.
-- @param preloads [Map relations of the user record, changed in place]
function hooks:AdjustPlayerRecordPreloads(preloads)
  preloads[#preloads + 1] = 'permissions'
  preloads[#preloads + 1] = 'temp_permissions'
end

--- Loads the lasting and the temporary permissions of characters together with them.
-- @param preloads [Map relations of the characters, changed in place]
function hooks:AdjustCharacterPreloads(preloads)
  preloads[#preloads + 1] = 'character_permissions'
  preloads[#preloads + 1] = 'character_temp_permissions'
end

--- Defaults the banned flag of a newly created user record to false.
-- @param _actor [Player]
-- @param record [User the player's database record]
function hooks:PlayerRecordCreated(_actor, record)
  record.banned = record.banned or false
end

--- Prints how to become an administrator to the server console while nobody can manage the
-- server: the bolt_root_steamid config is empty and no stored user has a role other than
-- `user`. Prints nothing while `bolt_external_admin` has Bolt defer to another admin mod,
-- which keeps the usergroups. The config is read rather than the mode, because the database
-- can be ready before `Bolt:setup_cami` has applied it.
local function print_admin_hint()
  if Bolt:get_cami_mode() == 'external' then return end

  local root_steamid = Config.get('bolt_root_steamid')

  if (isstring(root_steamid) and root_steamid != '') or (istable(root_steamid) and next(root_steamid) != nil) then
    return
  end

  User:where_not('role', 'user'):limit(1):get(function(users)
    if #users == 0 then
      MsgC(Color(255, 200, 0), t'notification.admin_hint', '\n')
    end
  end):fetch()
end

--- Loads all bans from the database into the ban cache, lifts the timed ones that have
-- expired and kicks the players on the server who are banned. Then prints how to become an
-- administrator while the server has none.
function hooks:ActiveRecordReady()
  Ban:all():get(function(objects)
    for _, ban in ipairs(objects) do
      Bolt:record_ban(ban.steam_id, ban)
    end
  end):fetch()

  Bolt:remove_expired_bans()

  for _, client in player.Iterator() do
    Bolt:kick_if_banned(client)
  end

  print_admin_hint()
end

--- Applies a loaded user record to the player: sets their role without signaling CAMI, makes
-- the SteamIDs from the bolt_root_steamid config root admins, networks stored permissions,
-- sends the config again if the player turns out to be allowed to edit it and tells everybody
-- that the player has connected. When Bolt defers to another admin mod, the usergroup is left
-- to that admin mod and only the root flag is set. The root flag is the `bolt_root` networked
-- variable, which only the root player receives.
-- @param actor [Player]
-- @param record [User the player's database record]
function hooks:PlayerRestored(actor, record)
  local sets_role = !Bolt:uses_external_admin()

  if sets_role and record.role then
    actor:set_role_id(record.role, true)
  end

  if Bolt:is_root_steam_id(actor:SteamID()) then
    actor:set_private_nv('bolt_root', true)

    if sets_role then
      actor:set_role_id('admin', true)
    end
  end

  if record.permissions then
    local perm_table = {}

    for _, perm_row in pairs(record.permissions) do
      perm_table[perm_row.permission_id] = perm_row.object
    end

    actor:set_permissions(perm_table)
  end

  if record.temp_permissions then
    local perm_table = {}

    for _, perm_row in pairs(record.temp_permissions) do
      perm_table[perm_row.permission_id] = {
        value = perm_row.object,
        expires = time_from_timestamp(perm_row.expires) or 0
      }
    end

    actor:set_temp_permissions(perm_table)
  end

  Bolt:update_config_access(actor)

  local arguments = { name = actor:steam_name() }

  Log:write(t('notification.player_connected', arguments), 'player_events')
  Flux.Player:broadcast('notification.player_connected', arguments)
end

--- Remembers whether the player could edit configs when the config was first sent to them,
-- which the gamemode does right before this hook. Bolt:update_config_access compares against
-- it to tell when the config has to be sent again.
-- @param actor [Player the player whose client has finished loading]
function hooks:PlayerInitialized(actor)
  actor.bolt_config_access = Config.can_manage(actor)
end

--- Checks role immunity for commands that target players, by way of Bolt:check_immunity:
-- the caller's role must have a higher immunity than the target's, except that callers may
-- always target themselves and root players may target anyone.
-- @param actor [Player the caller]
-- @param target [Player the player being targeted]
-- @param can_equal=false [Boolean also pass when both roles have the same immunity]
-- @return [Boolean false if the caller may not target that player, nothing otherwise]
function hooks:CommandCheckImmunity(actor, target, can_equal)
  if !Bolt:check_immunity(actor, target, can_equal) then
    return false
  end
end

--- Removes the expired temporary permissions of the player and of their active character.
-- @param actor [Player]
function hooks:PlayerOneMinute(actor)
  local now = os.time()

  for perm_id, entry in pairs(actor:get_temp_permissions()) do
    if entry.expires <= now then
      Bolt:delete_temp_permission(actor, perm_id)
    end
  end

  Bolt:expire_character_permissions(actor)
end

--- Gives or strips the weapon of the tool gun or the physgun permission, going by what a
-- player may do now. Does nothing while the player is dead; they get the tools they are
-- allowed when they spawn.
-- @param target [Player]
-- @param perm_id [String 'toolgun' or 'physgun']
local function sync_tool(target, perm_id)
  if !target:Alive() then return end

  local weapon_class = perm_id == 'toolgun' ? 'gmod_tool' : 'weapon_physgun'

  if target:can(perm_id) then
    target:Give(weapon_class)
  else
    target:StripWeapon(weapon_class)
  end
end

--- Gives or strips the tool gun or the physgun when the matching individual permission, or
-- the value that the active character sets for it, changes, going by what the player may do
-- now (character, individual and temporary permissions and role together): unsetting the
-- permission leaves the tool with a player whose role allows it, and PERM_NEVER takes it
-- away. Does nothing while the player is dead; they get the tools they are allowed when they
-- spawn. Any permission change also sends the config to the player again if it has changed
-- their right to edit configs, and makes the voice check ask again.
-- @param target [Player]
-- @param perm_id [String permission ID]
-- @param _value [Number new PERM_ value]
function hooks:PlayerPermissionChanged(target, perm_id, _value)
  target.bolt_voice_until = nil

  Bolt:update_config_access(target)

  if perm_id == 'toolgun' or perm_id == 'physgun' then
    sync_tool(target, perm_id)
  end
end

--- Makes the voice check ask again when a temporary permission of the player has changed.
-- @param target [Player]
-- @param _perm_id [String permission ID]
-- @param _value [Number the temporary value, PERM_NO when it was removed]
function hooks:PlayerTempPermissionChanged(target, _perm_id, _value)
  target.bolt_voice_until = nil
end

--- Gives or strips the tool gun and the physgun after the player's role has changed, going
-- by the 'toolgun' and 'physgun' permissions the player has now (role, individual, temporary
-- and character permissions together). Does nothing while the player is dead; they get the
-- tools they are allowed when they spawn. Also sends the config to the player again if the
-- new role has changed their right to edit configs, and makes the voice check ask again.
-- @param target [Player]
-- @param _group [Role the player's new role, nil when no registered role stands for its usergroup]
-- @param _old_group [Role the player's previous role, nil when no registered role stands for its usergroup]
function hooks:PlayerUserGroupChanged(target, _group, _old_group)
  target.bolt_voice_until = nil

  Bolt:update_config_access(target)

  sync_tool(target, 'toolgun')
  sync_tool(target, 'physgun')
end

--- Supplies the icon of the player's role for their chat messages.
-- @param speaker [Player the sender]
-- @param _text [String message text]
-- @param _team_chat [Boolean]
-- @return [Map icon data for the chatbox (icon, size, margin, is_data), or nothing if the
--   player is invalid]
function hooks:GetChatPlayerIcon(speaker, _text, _team_chat)
  if IsValid(speaker) then
    return { icon = speaker:get_role_table().icon or 'fa-user', size = 14, margin = 10, is_data = true }
  end
end

--- Lets open ban list pages know that a ban has been added.
-- @param _steam_id [String SteamID that has been banned]
-- @param _ban [Ban the ban record]
function hooks:BanAdded(_steam_id, _ban)
  Bolt:send_ban_list_changed()
end

--- Lets open ban list pages know that a ban has been lifted.
-- @param _steam_id [String SteamID that is no longer banned]
-- @param _data [Map column values of the deleted ban record]
function hooks:BanRemoved(_steam_id, _data)
  Bolt:send_ban_list_changed()
end

--- Applies the permissions of a character that has become the active character of a player.
-- Expired temporary permissions of the character are deleted first.
-- @param owner [Player]
-- @param character [Character]
function hooks:ActiveCharacterSet(owner, character)
  Bolt:remove_expired_character_permissions(character)
  Bolt:apply_character_permissions(owner, character)
end

--- Deletes the permissions of a character that a player is about to delete, from the
-- character and from the database. The foreign keys of the tables delete the rows with the
-- character as well, but they only exist where the Characters plugin was present when the
-- migrations ran.
-- @param _actor [Player the player who deletes the character]
-- @param id [Number ID of the character]
-- @param character [Character the character that is about to be deleted]
function hooks:PreDeleteCharacter(_actor, id, character)
  if istable(character) then
    character.character_permissions = {}
    character.character_temp_permissions = {}
  end

  id = tonumber(id)

  if !id then return end

  CharacterPermission:where('character_id', id):delete_all()
  CharacterTempPermission:where('character_id', id):delete_all()
end

--- Takes the permissions of a character away from the player who is dropping it.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function hooks:ActiveCharacterCleared(owner, _character)
  Bolt:apply_character_permissions(owner, nil)
end

Plugin.add_hooks('Bolt', hooks)
