--- Server-side receivers of the player management page of the admin panel: setting a
-- player's role, permissions and temporary permissions and those of their active character,
-- and removing temporary permissions. Every receiver checks the sender's own permission, the
-- values it was sent and the sender's immunity against the player to edit, the way the
-- `role set` and `role remove` commands do.

--- Checks a request of the admin panel to edit a player's role or permissions. The sender
-- needs the 'manage_permissions' permission and a role with a higher immunity than the
-- target's; an equal immunity is not enough, as for the `role set` and `role remove`
-- commands. Senders may always edit themselves, and root players anyone. A sender who fails
-- the immunity check is notified.
-- @param actor [Player the player who sent the request]
-- @param target [Any the value received as the player to edit]
-- @return [Boolean true if target is a player with a loaded record whom the sender may edit]
local function can_manage_player(actor, target)
  if !actor:can('manage_permissions') then return false end
  if !isentity(target) or !IsValid(target) or !target:IsPlayer() or !target.record then return false end

  if !Bolt:check_immunity(actor, target) then
    actor:notify('error.command.higher_immunity', { target = get_player_name(target) })

    return false
  end

  return true
end

local function is_permission_value(value)
  return value == PERM_ALLOW or value == PERM_NO or value == PERM_NEVER
end

--- Checks that a value received from a client can be a permission ID. The ID does not have
-- to be registered on the server, because a player may still have a value set for a
-- permission of a plugin that is not loaded on the server.
-- @param perm_id [Any]
-- @return [Boolean true for a non-empty string]
local function is_permission_id(perm_id)
  return isstring(perm_id) and perm_id != ''
end

--- Checks that the sender of a request may set a value of a permission of a player or of a
-- character: as with the `permission` and `charpermission` commands, only a permission that
-- the sender has can be allowed or denied. Unsetting it is always possible. A sender who
-- fails the check is notified.
-- @param actor [Player the player who sent the request]
-- @param perm_id [String permission ID]
-- @param value [Number PERM_ value]
-- @return [Boolean]
local function can_set_value(actor, perm_id, value)
  if value == PERM_NO or actor:can(perm_id) then return true end

  actor:notify('error.permission_not_yours', { permission = perm_id })

  return false
end

Cable.receive('fl_bolt_set_role', function(actor, target, role_id)
  if !can_manage_player(actor, target) then return end
  if !isstring(role_id) or !Bolt:group_exists(role_id) then return end

  if !Bolt:check_role_immunity(actor, role_id, true) then
    actor:notify('error.no_permission')

    return
  end

  target:SetUserGroup(role_id)

  Command:notify_staff('command.role.set.message', {
    player = get_player_name(actor),
    target = target:steam_name(true),
    group = role_id
  })
end)

Cable.receive('fl_bolt_set_permission', function(actor, target, perm_id, value)
  if !can_manage_player(actor, target) then return end
  if !is_permission_id(perm_id) or !is_permission_value(value) then return end
  if !can_set_value(actor, perm_id, value) then return end

  target:set_permission(perm_id, value)
end)

Cable.receive('fl_temp_permission', function(actor, target, perm_id, value, duration)
  if !can_manage_player(actor, target) then return end
  if !is_permission_id(perm_id) or !is_permission_value(value) then return end
  if !Bolt:is_temp_duration(duration) or !can_set_value(actor, perm_id, value) then return end

  target:set_temp_permission(perm_id, value, duration)
end)

Cable.receive('fl_delete_temp_permission', function(actor, target, perm_id)
  if !can_manage_player(actor, target) or !is_permission_id(perm_id) then return end

  Bolt:delete_temp_permission(target, perm_id)
end)

--- Checks a request of the admin panel to edit the permissions of a player's active
-- character. The sender needs the 'charpermission' permission, which the `charpermission`
-- command needs as well, has to be allowed to edit the player, as checked by
-- can_manage_player, and the player has to have a character loaded.
-- @param actor [Player the player who sent the request]
-- @param target [Any the value received as the player whose character to edit]
-- @return [Character the active character of the target, nil if the request is to be ignored]
local function managed_character(actor, target)
  if !actor:can('charpermission') or !can_manage_player(actor, target) then return end

  return Bolt:get_active_character(target)
end

--- Tells staff that a player has changed a permission of a character from the admin panel,
-- with the same messages as the `charpermission` command.
-- @param actor [Player the player who made the change]
-- @param target [Player the player who has the character loaded]
-- @param character [Character]
-- @param phrase [String language phrase of the message]
-- @param perm_id [String permission ID]
-- @param duration=nil [Number seconds a temporary permission lasts]
local function announce_character_change(actor, target, character, phrase, perm_id, duration)
  Command:notify_staff(phrase, {
    player = get_player_name(actor),
    character = Bolt:get_character_label(target, character),
    permission = perm_id,
    time = duration and Flux.Lang:duration(duration) or nil
  })
end

Cable.receive('fl_bolt_set_character_permission', function(actor, target, perm_id, value)
  local character = managed_character(actor, target)

  if !character or !is_permission_id(perm_id) or !is_permission_value(value) then return end
  if !can_set_value(actor, perm_id, value) then return end
  if Bolt:get_character_permissions(character)[perm_id] == (value != PERM_NO and value or nil) then return end
  if !Bolt:set_character_permission(character, perm_id, value) then return end

  local phrase = value == PERM_ALLOW and 'grant' or value == PERM_NEVER and 'revoke' or 'reset'

  announce_character_change(actor, target, character, 'command.charpermission.'..phrase..'.message', perm_id)
end)

Cable.receive('fl_bolt_character_temp_permission', function(actor, target, perm_id, value, duration)
  local character = managed_character(actor, target)

  if !character or !is_permission_id(perm_id) then return end
  if value != PERM_ALLOW and value != PERM_NEVER then return end
  if !Bolt:is_temp_duration(duration) or !can_set_value(actor, perm_id, value) then return end
  if !Bolt:set_character_temp_permission(character, perm_id, value, duration) then return end

  local phrase = value == PERM_ALLOW ? 'grant' : 'revoke'

  announce_character_change(actor, target, character, 'command.charpermission.'..phrase..'.message_temporary',
    perm_id, duration)
end)

Cable.receive('fl_bolt_delete_character_temp_permission', function(actor, target, perm_id)
  local character = managed_character(actor, target)

  if !character or !is_permission_id(perm_id) then return end

  if Bolt:delete_character_temp_permission(character, perm_id) then
    announce_character_change(actor, target, character, 'command.charpermission.reset.message_temporary', perm_id)
  end
end)
