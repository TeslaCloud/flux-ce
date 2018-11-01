mvc.handler('SpawnMenu::SpawnItem', function(player, itemID)
  if !player:can('spawn_items') then
    player:notify('err.no_permission', player:name())

    return
  end

  local item_table = item.New(itemID)

  if item_table then
    local trace = player:GetEyeTraceNoCursor()

    item.Spawn(trace.HitPos, nil, item_table)
  end
end)
