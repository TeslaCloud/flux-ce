function Bolt:delete_temp_permission(player, perm_id)
  if player.record.temp_permissions then
    for k, v in pairs(player.record.temp_permissions) do
      if v.permission_id == perm_id then
        v:destroy()
      end
    end
  end

  local perm_table = player:get_temp_permissions()

  perm_table[perm_id] = nil

  player:set_temp_permissions(perm_table)
end

Cable.receive('fl_bolt_set_role', function(player, target, role_id)
  if !player:can("manage_permissions") then return end
  target:SetUserGroup(role_id)

  self:notify_staff('setgroup.message', {
    player = get_player_name(player),
    target = target:steam_name(true),
    group = role_id
  })
end)

Cable.receive('fl_bolt_set_permission', function(player, target, perm_id, value)
  if !player:can("manage_permissions") then return end
  target:set_permission(perm_id, value)
end)

Cable.receive('fl_temp_permission', function(player, target, perm_id, value, duration)
  if !player:can("manage_permissions") then return end
  target:set_temp_permission(perm_id, value, duration)
end)

Cable.receive('fl_config_change', function(player, key, value)
  if !player:can("manage_configuration") then return end
  local config_table = Config.find(key)

  Config.set(key, value)

  Command:notify_staff('notification.config_changed', {
    player = get_player_name(player),
    config = config_table.name,
    value = tostring(value)
  })
end)
