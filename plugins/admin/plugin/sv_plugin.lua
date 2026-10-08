--- Server side of the admin plugin: removal of temporary permissions, and the network
-- receivers behind the admin panel, which set a player's role, permissions and temporary
-- permissions, remove temporary permissions and change config values after checking the
-- sender's own permission.

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
  if !actor:can('manage_permissions') then return end

  target:SetUserGroup(role_id)

  Command:notify_staff('command.setgroup.message', {
    player = get_player_name(actor),
    target = target:steam_name(true),
    group = role_id
  })
end)

Cable.receive('fl_bolt_set_permission', function(actor, target, perm_id, value)
  if !actor:can('manage_permissions') then return end

  target:set_permission(perm_id, value)
end)

Cable.receive('fl_temp_permission', function(actor, target, perm_id, value, duration)
  if !actor:can('manage_permissions') then return end

  target:set_temp_permission(perm_id, value, duration)
end)

Cable.receive('fl_delete_temp_permission', function(actor, target, perm_id)
  if !actor:can('manage_permissions') then return end

  Bolt:delete_temp_permission(target, perm_id)
end)

Cable.receive('fl_config_change', function(actor, key, value)
  if !actor:can('manage_configuration') then return end

  local config_table = Config.find(key)

  Config.set(key, value)

  Command:notify_staff('notification.config_changed', {
    player = get_player_name(actor),
    config = config_table.name,
    value = tostring(value)
  })
end)
