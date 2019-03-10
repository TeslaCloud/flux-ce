MVC.handler('SpawnMenu::SpawnItem', function(player, item_id)
  if !player:can('spawn_items') then
    player:notify('err.no_permission', player:name())

    return
  end

  local item_table = item.new(item_id)

  if item_table then
    local trace = player:GetEyeTraceNoCursor()

    item.spawn(trace.HitPos, nil, item_table)
  end
end)
