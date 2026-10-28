--- Server-side hooks of the admin plugin: the ban check on connect, loading of the bans and
-- of each player's role and permissions from the database, telling open ban list pages that
-- the bans have changed, the permission checks for tools, chairs and voice chat, expiry of
-- temporary permissions, applying and deleting the permissions of characters, giving or
-- stripping the tool gun and the physgun as permissions change, and keeping hidden players
-- (vanished or observing) and everything attached to them hidden as players join, respawn
-- and change permissions.

--- Checks connecting players against the ban cache. A timed ban that has expired is lifted
-- and the connection left to the other checks, such as the server password; any other ban
-- rejects the connection with the message of Bolt:get_ban_message, which names its reason
-- and the time it has left, including a ban whose end time cannot be read.
-- @param steam_id64 [String 64-bit SteamID of the connecting player]
-- @param ip [String]
-- @param _sv_pass [String server password]
-- @param _cl_pass [String password entered by the client]
-- @param name [String player name]
-- @return [Boolean false to reject (nothing otherwise), String rejection message (only when
--   rejecting)]
function Bolt:CheckPassword(steam_id64, ip, _sv_pass, _cl_pass, name)
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
       -- and the admin plugin is about to lift it and leave the connection to the other checks.
       -- @param steam_id [String SteamID of the connecting player]
       -- @param ip [String Address the player connects from]
       -- @param name [String Name of the connecting player]
       -- @return [Boolean Return false to keep the ban, so that the player is rejected with
       --   the reason of the ban]
       Plugin.call('ShouldExpireBan', steam_id, ip, name) != false then
      self:remove_ban(steam_id)
    else
      return false, self:get_ban_message(entry)
    end
  end
end

--- Blocks tools that require a permission the player does not have.
-- @param actor [Player]
-- @param _trace [Map trace result of the tool use]
-- @param tool_name [String tool ID]
-- @return [Boolean false to block the tool, nothing otherwise]
function Bolt:CanTool(actor, _trace, tool_name)
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
-- @param _listener [Player the listener]
-- @param talker [Player]
-- @return [Boolean false if the talker may not be heard, nothing otherwise]
function Bolt:PlayerCanHearPlayersVoice(_listener, talker)
  if !talker:can('voice') then
    return false
  end
end

--- Defaults the banned flag of a newly created user record to false.
-- @param _actor [Player]
-- @param record [User the player's database record]
function Bolt:PlayerCreated(_actor, record)
  record.banned = record.banned or false
end

--- Loads all bans from the database into the ban cache.
function Bolt:ActiveRecordReady()
  Ban:all():get(function(objects)
    for _, ban in ipairs(objects) do
      self:record_ban(ban.steam_id, ban)
    end
  end):fetch()
end

--- Applies a loaded user record to the player: sets their role, makes the SteamIDs from the
-- root_steamid config root admins, networks stored permissions, sends the config again if
-- the player turns out to be allowed to edit it, shows hidden players (vanished or observing)
-- to players with the 'moderate' permission and logs the connection.
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

    for _, root_id in ipairs(root_steamid) do
      if root_id == steam_id then
        actor:SetUserGroup('admin')
        actor.can_anything = true
      end
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

  self:update_config_access(actor)
  actor:update_hidden_players()

  Log:notify(actor:name()..' has connected to the server.', { action = 'player_events' })
end

--- Remembers whether the player could edit configs when the config was first sent to them,
-- which the gamemode does right before this hook. Bolt:update_config_access compares against
-- it to tell when the config has to be sent again. Also applies once more which hidden
-- players the player may see, now that their client is in the game and their role is known.
-- @param actor [Player the player whose client has finished loading]
function Bolt:PlayerInitialized(actor)
  actor.bolt_config_access = Config.can_manage(actor)
  actor:update_hidden_players()
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

--- Hides hidden players (vanished or observing) from a newly connected player. The player's
-- role is not known yet at this point; Bolt:PlayerRestored and Bolt:PlayerInitialized show
-- them again if the player turns out to have the 'moderate' permission.
-- @param actor [Player the player that just connected]
function Bolt:PlayerInitialSpawn(actor)
  actor:update_hidden_players()
end

--- Makes a vanished player invisible again after a respawn, which has made them visible.
-- @param actor [Player]
function Bolt:PostPlayerSpawn(actor)
  actor:hide_vanished_body()
end

do
  local created = {}

  --- Returns the player an entity is attached to, directly or through other entities, or
  -- the owner of a weapon.
  -- @param entity [Entity]
  -- @return [Player the player, nil if there is none]
  local function get_holder(entity)
    local parent = entity:GetParent()

    while IsValid(parent) and !parent:IsPlayer() do
      parent = parent:GetParent()
    end

    if !IsValid(parent) and entity:IsWeapon() then
      parent = entity:GetOwner()
    end

    if IsValid(parent) and parent:IsPlayer() then
      return parent
    end
  end

  --- Hides the entities that have been attached to a hidden player since the last tick, such
  -- as the weapons they are given when they spawn or their flashlight, from everyone the
  -- player is hidden from. Hiding the player only hides what they have at that moment.
  local function hide_created()
    local entities = created

    created = {}

    for _, ent in ipairs(entities) do
      if IsValid(ent) then
        local holder = get_holder(ent)

        if holder and holder:is_hidden() then
          holder:update_visibility()
        end
      end
    end
  end

  --- Queues every new entity to be checked on the next tick, once it has been attached to
  -- whatever it belongs to.
  -- @param entity [Entity]
  function Bolt:OnEntityCreated(entity)
    created[#created + 1] = entity

    if #created == 1 then
      timer.Simple(0, hide_created)
    end
  end

  --- Queues a weapon that a player picks up to be checked on the next tick, as it is not a
  -- new entity.
  -- @param weapon [Weapon]
  -- @param _actor [Player]
  function Bolt:WeaponEquip(weapon, _actor)
    self:OnEntityCreated(weapon)
  end
end

--- Networks a weapon dropped by a hidden player to everyone again: it no longer belongs to
-- the player.
-- @param _actor [Player]
-- @param weapon [Weapon]
function Bolt:PlayerDroppedWeapon(_actor, weapon)
  if !IsValid(weapon) then return end

  for _, client in player.Iterator() do
    weapon:prevent_transmit(client, false)
  end
end

--- Keeps hidden players (vanished or observing) from picking up weapons that lie in the
-- world. Weapons that they are given are let through: those are created in the same tick.
-- @param actor [Player]
-- @param weapon [Weapon]
-- @return [Boolean false for a hidden player and a weapon that lies in the world]
function Bolt:PlayerCanPickupWeapon(actor, weapon)
  if actor:is_hidden() and weapon:GetCreationTime() < CurTime() then
    return false
  end
end

--- Keeps hidden players (vanished or observing) from carrying objects in their hands, which
-- would show other players an object floating in the air.
-- @param actor [Player]
-- @param _entity [Entity]
-- @param _drag [Boolean]
-- @return [Boolean false for a hidden player]
function Bolt:PlayerPickupObject(actor, _entity, _drag)
  if actor:is_hidden() then
    return false
  end
end

--- Removes the expired temporary permissions of the player and of their active character.
-- @param actor [Player]
function Bolt:PlayerOneMinute(actor)
  local now = os.time()

  for perm_id, entry in pairs(actor:get_temp_permissions()) do
    if entry.expires <= now then
      self:delete_temp_permission(actor, perm_id)
    end
  end

  self:expire_character_permissions(actor)
end

--- Gives or strips the tool gun or the physgun when the matching individual permission, or
-- the value that the active character sets for it, changes, going by what the player may do
-- now (character, individual and temporary permissions and role together): unsetting the
-- permission leaves the tool with a player whose role allows it, and PERM_NEVER takes it
-- away. Does nothing while the player is dead; they get the tools they are allowed when they
-- spawn. Any permission change also sends the config to the player again if it has changed
-- their right to edit configs.
-- @param target [Player]
-- @param perm_id [String permission ID]
-- @param _value [Number new PERM_ value]
function Bolt:PlayerPermissionChanged(target, perm_id, _value)
  self:update_config_access(target)
  target:update_hidden_players()

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
-- by the 'toolgun' and 'physgun' permissions the player has now (role, individual, temporary
-- and character permissions together). Does nothing while the player is dead; they get the
-- tools they are allowed when they spawn. Also sends the config to the player again if the
-- new role has changed their right to edit configs.
-- @param target [Player]
-- @param _group [Role the player's new role, nil if its ID is not registered]
-- @param _old_group [Role the player's previous role]
function Bolt:PlayerUserGroupChanged(target, _group, _old_group)
  self:update_config_access(target)
  target:update_hidden_players()

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
-- @param _text [String message text]
-- @param _team_chat [Boolean]
-- @return [Map icon data for the chatbox (icon, size, margin, is_data), or nothing if the
--   player is invalid]
function Bolt:ChatboxGetPlayerIcon(speaker, _text, _team_chat)
  if IsValid(speaker) then
    return { icon = speaker:get_role_table().icon or 'fa-user', size = 14, margin = 10, is_data = true }
  end
end

--- Lets open ban list pages know that a ban has been added.
-- @param _steam_id [String SteamID that has been banned]
-- @param _ban [Ban the ban record]
function Bolt:OnBanAdded(_steam_id, _ban)
  self:send_ban_list_changed()
end

--- Lets open ban list pages know that a ban has been lifted.
-- @param _steam_id [String SteamID that is no longer banned]
-- @param _data [Map column values of the deleted ban record]
function Bolt:OnBanRemoved(_steam_id, _data)
  self:send_ban_list_changed()
end

--- Applies the permissions of a character that has become the active character of a player.
-- Expired temporary permissions of the character are deleted first.
-- @param owner [Player]
-- @param character [Character]
function Bolt:OnActiveCharacterSet(owner, character)
  self:remove_expired_character_permissions(character)
  self:apply_character_permissions(owner, character)
end

--- Deletes the permissions of a character that a player is about to delete, from the
-- character and from the database. The foreign keys of the tables delete the rows with the
-- character as well, but they only exist where the Characters plugin was present when the
-- migrations ran.
-- @param _actor [Player the player who deletes the character]
-- @param id [Number ID of the character]
-- @param character [Character the character that is about to be deleted]
function Bolt:OnCharacterDelete(_actor, id, character)
  if istable(character) then
    character.character_permissions = {}
    character.character_temp_permissions = {}
  end

  id = tonumber(id)

  if !id then return end

  for _, table_name in ipairs({ 'character_permissions', 'character_temp_permissions' }) do
    local query = ActiveRecord.Database:delete(table_name)
      query:where('character_id', id)
    query:execute()
  end
end

--- Takes the permissions of a character away from the player who is dropping it.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function Bolt:OnActiveCharacterCleared(owner, _character)
  self:apply_character_permissions(owner, nil)
end
