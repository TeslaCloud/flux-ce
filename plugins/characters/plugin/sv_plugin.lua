--- Server-side player methods of the Characters plugin: selecting and dropping the active
-- character, setting its fields and generic data and saving it.

local player_meta = FindMetaTable('Player')
local default_model = 'models/humans/group01/male_02.mdl'

--- Makes a character the active character of a player. Runs OnCharacterChange if another
-- character was active, networks the basic character data and runs OnActiveCharacterSet. The
-- character does not have to belong to the player: one of another user record is sent to the
-- player on its own, so that their client knows the character it is playing. Nothing is
-- checked here: the requests of players go through `Characters.can_use` first, which is what
-- keeps banned characters from being loaded.
-- @param target [Player]
-- @param character [Character any character record; nothing happens when it is not a table]
function Characters.activate(target, character)
  if !istable(character) then return end

  if target:get_character_id() then
    --- Called on the server when a player who already has an active character selects a
    -- character, before the selected character becomes the active one.
    -- @param owner [Player]
    -- @param new_char [Character the character that is about to become active]
    -- @param old_char [Character the character that is still active]
    hook.Run('OnCharacterChange', target, character, target:get_character())
  end

  if !target:IsBot() then
    local user = character.user
    local borrowed = istable(user) and user != target.record and Characters.to_networkable(target, character) or nil

    Cable.send(target, 'fl_character_borrowed', borrowed)
  end

  target.vitals_restored = false
  target:set_nv('active_character', tonumber(character.id))
  target.current_character = character

  target:set_nv('name', character.name or target:steam_name())
  target:set_nv('gender', character.gender or CHAR_GENDER_MALE)
  target:set_nv('phys_desc', character.phys_desc or '')
  target:set_nv('model', character.model or default_model)

  --- Called on the server when a character has become the active character of a player, after
  -- its ID, name, gender, description and model have been networked. The Characters plugin
  -- spawns the player from its own handler of this hook; other plugins use it to apply what
  -- they keep on the character.
  -- @param owner [Player]
  -- @param character [Character the character that is now active]
  hook.Run('OnActiveCharacterSet', target, target:get_character())
end

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
  self:set_nv('model', default_model)
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
