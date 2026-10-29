--- Server-side player extensions of the Characters plugin: selecting and dropping the active
-- character, setting its fields and generic data and saving it.

local player_meta = FindMetaTable('Player')

--- Makes one of the player's own characters their active one.
-- @param id [Number/String character ID; nothing happens if the player has no such character]
-- @see [Characters.activate]
function player_meta:set_active_character(id)
  id = tonumber(id)

  if !id then return end

  local real_character = self:get_character_by_id(id)

  if !real_character then return end

  Characters.activate(self, real_character)
end

--- Leaves the player without an active character. The active character is saved first and
-- the OnActiveCharacterCleared hook is run while it is still active; then the player's name
-- goes back to their Steam name and their gender, description and model to the defaults.
-- The player is neither spawned nor killed here.
function player_meta:clear_active_character()
  local character = self.current_character

  if character then
    self:save_character()

    --- Called on the server when a player is left without an active character, after the
    -- character has been saved and while it is still the active one. Handlers take back what
    -- they have given the player for the character.
    -- @param owner [Player]
    -- @param character [Character the character that is being dropped]
    hook.Run('OnActiveCharacterCleared', self, character)
  end

  if !self:IsBot() then
    Cable.send(self, 'fl_character_borrowed', nil)
  end

  self.current_character = nil
  self.vitals_restored = false

  self:set_nv('active_character', nil)
  self:set_nv('name', self:steam_name())
  self:set_nv('gender', CHAR_GENDER_MALE)
  self:set_nv('phys_desc', '')
  self:set_nv('model', Characters.default_model)
end

--- Sets a field on the player's active character and networks it under the same name.
-- @param id [String field name; nothing happens when it is not a string]
-- @param val [Any]
function player_meta:set_character_var(id, val)
  if isstring(id) then
    self:set_nv(id, val)
    self:get_character()[id] = val
  end
end

--- Sets a value in the generic data of the player's active character. Unlike
-- `Player:set_character_var`, the value needs no column of its own and is not networked to
-- every player: it is saved with the character the next time the character is saved, and
-- sent to the player themselves only if the key is registered with
-- `Characters.network_data`.
-- ```
-- target:set_character_data('spawn_position', target:GetPos())
-- ```
-- @param key [String nothing happens when it is not a string]
-- @param value [Any anything serializable, so no functions; nil removes the key]
-- @see [Characters.set_custom_data]
function player_meta:set_character_data(key, value)
  if !self:is_character_loaded() then return end

  local character = self:get_character()

  if character then
    Characters.set_custom_data(character, key, value)
  end
end

--- Saves the player's active character, if they have one.
-- @see [Characters.save]
function player_meta:save_character()
  if self:is_character_loaded() then
    Characters.save(self, self:get_character())
  end
end
