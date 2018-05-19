--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

netstream.Hook("ClientIncludedSchema", function(player)
  hook.Run("ClientIncludedSchema", player)
  hook.Run("PlayerInitialized", player)
end)

netstream.Hook("SoftUndo", function(player)
  fl.undo:DoPlayer(player)
end)

netstream.Hook("LocalPlayerCreated", function(player)
  netstream.Start(player, "SharedTables", fl.sharedTable)

  player:SendConfig()
  player:SyncNetVars()
end)

netstream.Hook("Flux::Player::Language", function(player, lang)
  player:SetNetVar("language", lang)
end)
