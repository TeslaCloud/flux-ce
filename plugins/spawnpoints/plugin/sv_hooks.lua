--- Server hooks of the Spawn Points plugin: load the spawn points of the map and hand the
-- game the point a player should spawn at.

--- Loads the spawn points when the framework loads its data.
function SpawnPoints:LoadData()
  self:load()
end

--- Gives the game the spawn point of a player, in place of a spawn entity of the map. The
-- game puts the player at the returned entity and turns them the way it faces before any
-- spawn hook runs, so whatever moves the player afterwards keeps the last word. Nothing is
-- returned, which leaves the choice to the map, for a level transition, for a player who
-- has no character to spawn as, and when no point has been chosen.
-- @param actor [Player the player who is spawning]
-- @param transition [Boolean whether the player is arriving through a level transition]
-- @return [Entity the stand-in entity moved to the chosen point, or nil to use the spawn of
--   the map]
-- @see [SpawnPoints:choose_point]
function SpawnPoints:PlayerSelectSpawn(actor, transition)
  if transition then return end

  if Characters and (!actor:is_character_loaded() or actor:is_character_banned()) then return end

  local point = self:choose_point(actor)

  if !point then return end

  local anchor = self:get_anchor()

  if !IsValid(anchor) then return end

  anchor:SetPos(point.pos)
  anchor:SetAngles(isangle(point.ang) and point.ang or Angle(0, 0, 0))

  return anchor
end
