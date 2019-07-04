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
  target:SetUserGroup(role_id)

  Flux.Player:broadcast('setgroup.message', { get_player_name(player), target:steam_name(true), role_id })
end)

Cable.receive('fl_bolt_set_permission', function(player, target, perm_id, value)
  target:set_permission(perm_id, value)
end)

Cable.receive('fl_temp_permission', function(player, target, perm_id, value, duration)
  target:set_temp_permission(perm_id, value, duration)
end)

Cable.receive('fl_config_change', function(player, key, value)
  Config.set(key, value)
end)
