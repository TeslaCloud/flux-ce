--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]mvc.Handler("SpawnMenu::SpawnItem", function(player, itemID)
  if (!player:HasPermission("spawn_items")) then
    player:Notify(L("Err_No_Permission", player:Name()))

    return
  end

  local itemTable = item.New(itemID)

  if (itemTable) then
    local trace = player:GetEyeTraceNoCursor()

    item.Spawn(trace.HitPos, nil, itemTable)
  end
end)
