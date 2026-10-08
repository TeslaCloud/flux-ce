--- Server side of the admin plugin: removal of temporary permissions, and the network
-- receivers behind the admin panel, which set a player's role, permissions and temporary
-- permissions, remove temporary permissions and change config values. Every receiver checks
-- the sender's own permission and the values it was sent; the ones that edit a player also
-- check the sender's immunity against that player, the way the SetGroup and Demote commands
-- do.

--- Checks a request of the admin panel to edit a player's role or permissions. The sender
-- needs the 'manage_permissions' permission and a role with a higher immunity than the
-- target's; an equal immunity is not enough, as for the SetGroup and Demote commands. Senders
-- may always edit themselves, and root players anyone. A sender who fails the immunity check
-- is notified.
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

--- Checks that a value received from a client is one of the three permission values.
-- @param value [Any]
-- @return [Boolean true for PERM_ALLOW, PERM_NO and PERM_NEVER]
local function is_permission_value(value)
  return value == PERM_ALLOW or value == PERM_NO or value == PERM_NEVER
end

--- Checks that a value received from a client can be a permission ID. The ID does not have
-- to be registered on the server, because a permission may only exist on the client (such as
-- 'admin_esp').
-- @param perm_id [Any]
-- @return [Boolean true for a non-empty string]
local function is_permission_id(perm_id)
  return isstring(perm_id) and perm_id != ''
end

--- Removes a temporary permission from a player, destroying its database record, taking it
-- off the player's record and updating the networked table.
-- @param target [Player]
-- @param perm_id [String permission ID]
function Bolt:delete_temp_permission(target, perm_id)
  local records = target.record.temp_permissions

  if records then
    for i = #records, 1, -1 do
      if records[i].permission_id == perm_id then
        records[i]:destroy()

        table.remove(records, i)
      end
    end
  end

  local perm_table = target:get_temp_permissions()

  perm_table[perm_id] = nil

  target:set_temp_permissions(perm_table)
end

Cable.receive('fl_bolt_set_role', function(actor, target, role_id)
  if !can_manage_player(actor, target) then return end
  if !isstring(role_id) or !Bolt:group_exists(role_id) then return end

  target:SetUserGroup(role_id)

  Command:notify_staff('command.setgroup.message', {
    player = get_player_name(actor),
    target = target:steam_name(true),
    group = role_id
  })
end)

Cable.receive('fl_bolt_set_permission', function(actor, target, perm_id, value)
  if !can_manage_player(actor, target) then return end
  if !is_permission_id(perm_id) or !is_permission_value(value) then return end

  target:set_permission(perm_id, value)
end)

Cable.receive('fl_temp_permission', function(actor, target, perm_id, value, duration)
  if !can_manage_player(actor, target) then return end
  if !is_permission_id(perm_id) or !is_permission_value(value) then return end
  if !isnumber(duration) or duration != duration or duration <= 0 or duration == math.huge then return end

  target:set_temp_permission(perm_id, value, duration)
end)

Cable.receive('fl_delete_temp_permission', function(actor, target, perm_id)
  if !can_manage_player(actor, target) or !is_permission_id(perm_id) then return end

  Bolt:delete_temp_permission(target, perm_id)
end)

Cable.receive('fl_config_change', function(actor, key, value)
  if !actor:can('manage_configuration') then return end

  local config_table = isstring(key) and Config.find(key)

  if !config_table then return end

  Config.set(key, value)

  Command:notify_staff('notification.config_changed', {
    player = get_player_name(actor),
    config = config_table.name or key,
    value = tostring(value)
  })
end)
