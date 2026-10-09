--- Server-side player methods of the Characters plugin: selecting the active character,
-- setting its fields and generic data and saving it.

local player_meta = FindMetaTable('Player')

--- Makes one of the player's characters their active one. Runs OnCharacterChange if another
-- character was active, networks the basic character data and runs OnActiveCharacterSet.
-- Nothing is checked here: the requests of players go through `Characters.can_use` first,
-- which is what keeps banned characters from being loaded.
-- @param id [Number/String character ID; nothing happens if the player has no such character]
function player_meta:set_active_character(id)
  id = tonumber(id)

  if !id then return end

  local real_character = self:get_character_by_id(id)

  if !real_character then return end

  local cur_char_id = self:get_character_id()

  if cur_char_id then
    --- Called on the server when a player who already has an active character selects a
    -- character, before the selected character becomes the active one.
    -- @param owner [Player]
    -- @param new_char [Character the character that is about to become active]
    -- @param old_char [Character the character that is still active]
    hook.Run('OnCharacterChange', self, real_character, self:get_character())
  end

  self.vitals_restored = false
  self:set_nv('active_character', tonumber(real_character.id))
  self.current_character = real_character

  local char_data = self:get_character()

  self:set_nv('name', char_data.name or self:steam_name())
  self:set_nv('gender', char_data.gender or CHAR_GENDER_MALE)
  self:set_nv('phys_desc', char_data.phys_desc or '')
  self:set_nv('model', char_data.model or 'models/humans/group01/male_02.mdl')

  --- Called on the server when a character has become the active character of a player, after
  -- its ID, name, gender, description and model have been networked. The Characters plugin
  -- spawns the player from its own handler of this hook; other plugins use it to apply what
  -- they keep on the character.
  -- @param owner [Player]
  -- @param character [Character the character that is now active]
  hook.Run('OnActiveCharacterSet', self, self:get_character())
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
