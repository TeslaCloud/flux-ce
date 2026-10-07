--- Blocks the default noclip clientside, since observer mode is handled by the server.
-- @param player [Player]
-- @return [Boolean always false]
function Observer:PlayerEnterNoclip(player)
  return false
end

--- Blocks the default noclip clientside, since observer mode is handled by the server.
-- @param player [Player]
-- @return [Boolean always false]
function Observer:PlayerExitNoclip(player)
  return false
end
