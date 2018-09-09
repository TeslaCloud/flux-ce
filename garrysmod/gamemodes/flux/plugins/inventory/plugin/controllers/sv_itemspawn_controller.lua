mvc.handler("SpawnMenu::SpawnItem", function(player, itemID)
  if !player:can("spawn_items") then
    player:notify(L("Err_No_Permission", player:Name()))

    return
  end

  local item_table = item.New(itemID)

  if item_table then
    local trace = player:GetEyeTraceNoCursor()

    item.Spawn(trace.HitPos, nil, item_table)
  end
end)
