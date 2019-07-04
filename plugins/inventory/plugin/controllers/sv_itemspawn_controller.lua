MVC.handler('SpawnMenu::SpawnItem', function(player, item_id)
  if !player:can('spawn_items') then
    player:notify('error.no_permission', player:name())

    return
  end

  local item_table = Item.create(item_id)

  if item_table then
    local trace = player:GetEyeTraceNoCursor()

    Item.spawn(trace.HitPos, nil, item_table)
  end
end)
