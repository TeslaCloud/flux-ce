--- Client side of the Observer plugin: blocks the default noclip, as observer mode is handled
-- by the server.

--- Blocks the default noclip clientside, since observer mode is handled by the server.
-- @param actor [Player]
-- @return [Boolean always false]
function Observer:PlayerEnterNoclip(actor)
  return false
end

--- Blocks the default noclip clientside, since observer mode is handled by the server.
-- @param actor [Player]
-- @return [Boolean always false]
function Observer:PlayerExitNoclip(actor)
  return false
end
