--- Server hooks of the Spawn Saver plugin: write the spot of a player into their character
-- when it is saved, move the player there when it is loaded, and keep both from happening
-- while the player is not where their character would be expected.

--- Checks whether a player is somewhere their character should not be saved at or moved
-- from: dead, ragdolled, in observer mode or in noclip. Sitting in a vehicle does not count.
-- @param target [Player]
-- @return [Boolean]
local function is_out_of_place(target)
  if !target:Alive() or target:get_nv('observer') then
    return true
  end

  if isfunction(target.is_ragdolled) and target:is_ragdolled() then
    return true
  end

  return target:GetMoveType() == MOVETYPE_NOCLIP and !target:InVehicle()
end

--- Writes the place where the player stands into their active character before it is
-- saved. A dead player makes the character forget its spot, and so does turning the
-- 'spawn_where_left' config off. Banned characters, whose players stay dead, and characters
-- that are being loaded and have not been given their spot yet are left alone.
-- @param owner [Player]
-- @param character [Character the character that is being saved]
function SpawnSaver:SaveCharacterData(owner, character)
  if owner:IsBot() or tobool(character.banned) then return end
  if owner:get_character() != character or owner.spawn_point_character != character then return end

  if !Config.get('spawn_where_left') or !owner:Alive() or owner:Health() <= 0 then
    Characters.set_custom_data(character, self.data_key, nil)

    return
  end

  self:save_spawn_point(owner, character)
end

--- Moves the player to the spot saved with the character they have loaded, and lets the
-- position of the player be saved with that character from now on.
-- @param owner [Player]
-- @param character [Character the loaded character]
function SpawnSaver:PostCharacterLoaded(owner, character)
  if !owner:IsBot() and Config.get('spawn_where_left') then
    self:restore_spawn_point(owner, character)
  end

  owner.spawn_point_character = character
end

--- Keeps the spot that was saved before while the player is ragdolled, in observer mode or
-- in noclip.
-- @param target [Player]
-- @param character [Character the character that is being saved]
-- @return [Boolean false when the position of the player should not be saved, otherwise nil]
function SpawnSaver:ShouldSavePlayerSpawn(target, character)
  if is_out_of_place(target) then
    return false
  end
end

--- Leaves the player at the regular spawn point while they are dead, ragdolled, in observer
-- mode or in noclip.
-- @param target [Player]
-- @param character [Character the loaded character]
-- @param spawn_point [Map the saved spot: map, position and angles]
-- @return [Boolean false when the player should not be moved, otherwise nil]
function SpawnSaver:ShouldRestorePlayerSpawn(target, character, spawn_point)
  if is_out_of_place(target) then
    return false
  end
end
