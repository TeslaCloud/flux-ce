--- Server side of the Spawn Saver plugin: reads, writes and applies the spot that is saved
-- with a character.

SpawnSaver.data_key = 'spawn_point'

--- Returns the spot saved with a character, if it was saved on the map that is running now.
-- @param character [Character]
-- @return [Map the spot: map [String], position [Vector] and angles [Angle]; nil when the
--   character has none or it belongs to another map]
function SpawnSaver:get_spawn_point(character)
  local spawn_point = Characters.get_custom_data(character, self.data_key)

  if istable(spawn_point) and spawn_point.map == game.GetMap() and isvector(spawn_point.position) then
    return spawn_point
  end
end

--- Writes the place where a player stands into the data of a character, unless a
-- ShouldSavePlayerSpawn hook is against it. The spot reaches the database the next time the
-- character is saved.
-- @param target [Player the player whose position and eye angles are taken]
-- @param character [Character the character to keep them with]
-- @return [Boolean true when the spot was written]
function SpawnSaver:save_spawn_point(target, character)
  --- Decides whether the place where a player stands is written into their character.
  -- Called on the server every time the active character of a living player is saved,
  -- while the 'spawn_where_left' config is on. The plugin itself refuses for players who
  -- are ragdolled, in observer mode or in noclip.
  -- @param target [Player the player whose character is being saved]
  -- @param character [Character their active character]
  -- @return [Boolean return false to keep the spot that was saved before]
  if hook.Run('ShouldSavePlayerSpawn', target, character) == false then return false end

  Characters.set_custom_data(character, self.data_key, {
    map = game.GetMap(),
    position = target:GetPos(),
    angles = target:EyeAngles()
  })

  return true
end

--- Moves a player to the spot saved with a character. Nothing happens when the character has
-- no spot for the current map, when the spot is outside of the world or when a
-- ShouldRestorePlayerSpawn hook is against it. A player who would be stuck there is moved
-- to the nearest free spot, and put back where they were when there is none.
-- @param target [Player]
-- @param character [Character the character whose spot is used]
-- @return [Boolean true when the player was moved]
function SpawnSaver:restore_spawn_point(target, character)
  local spawn_point = self:get_spawn_point(character)

  if !spawn_point or !util.IsInWorld(spawn_point.position) then return false end

  --- Decides whether a player is moved to the spot saved with their character. Called on
  -- the server when a character that has a spot inside the world of the current map is
  -- loaded, after its player has spawned, while the 'spawn_where_left' config is on. The
  -- plugin itself refuses for players who are dead, ragdolled, in observer mode or in
  -- noclip.
  -- @param target [Player the player who has loaded the character]
  -- @param character [Character the loaded character]
  -- @param spawn_point [Map the saved spot: map, position and angles]
  -- @return [Boolean return false to leave the player at the regular spawn point]
  if hook.Run('ShouldRestorePlayerSpawn', target, character, spawn_point) == false then return false end

  local origin = target:GetPos()

  target:SetPos(spawn_point.position)

  if target:stuck() then
    target:unstuck()

    if target:stuck() then
      target:SetPos(origin)

      return false
    end
  end

  if isangle(spawn_point.angles) then
    target:SetEyeAngles(spawn_point.angles)
  end

  return true
end
