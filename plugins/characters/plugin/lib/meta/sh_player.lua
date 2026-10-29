--- Player extensions of the Characters plugin: the characters of a player and the fields of
-- the active one. On the server they are `Character` records, on the client the networked
-- tables that the server sends to the owner of the characters.

local player_meta = FindMetaTable('Player')

--- Finds one of the player's own characters by its ID. On the client the active character
-- of the local player is found as well when it belongs to somebody else, such as a
-- character that the player is playing for its owner.
-- @param id [Number character ID]
-- @return [Character/Map the character record on the server or its networked data on the
--   client, nil if the player has no such character]
function player_meta:get_character_by_id(id)
  local characters = self:get_all_characters()

  for i = 1, #characters do
    local character = characters[i]

    if id == tonumber(character.id) then
      return character
    end
  end

  local borrowed = CLIENT and self.borrowed_character

  if istable(borrowed) and id != nil and id == tonumber(borrowed.id) then
    return borrowed
  end
end

--- Returns the networked ID of the player's active character.
-- @return [Number character ID, or nil if no character has been selected]
function player_meta:get_character_id()
  return self:get_nv('active_character')
end

--- Returns the player's active character. Bots get a plain table that is created on demand.
-- @return [Character/Map the character record on the server or its networked data on the
--   client, nil if no character is active]
function player_meta:get_character()
  if SERVER and self.current_character then
    return self.current_character
  elseif self:IsBot() then
    self.char_data = self.char_data or {}

    return self.char_data
  end

  return self:get_character_by_id(self:get_character_id())
end

--- Checks whether the player has an active character. Always true for bots.
-- @return [Boolean true if a character is active, false or nil otherwise]
function player_meta:is_character_loaded()
  if self:IsBot() then return true end

  local id = self:get_character_id()

  return id and id > 0
end

--- Returns a field of the player's active character. On the client the value is read from
-- the player's networked variable of the same name instead.
-- @param id [String field name]
-- @param default=nil [Any value to return when the field is not set]
-- @return [Any]
function player_meta:get_character_var(id, default)
  if SERVER then
    return self:get_character()[id] or default
  else
    return self:get_nv(id, default)
  end
end

--- Returns a value from the generic data of the player's active character. The server
-- knows all of it; a client only knows the keys registered with
-- `Characters.network_data`, and only for the local player.
-- ```
-- local position = target:get_character_data('spawn_position')
-- ```
-- @param key [String]
-- @param default=nil [Any value to return when nothing is stored under the key or no
--   character is active]
-- @return [Any]
-- @see [Characters.get_custom_data]
function player_meta:get_character_data(key, default)
  if !self:is_character_loaded() then return default end

  return Characters.get_custom_data(self:get_character(), key, default)
end

--- Checks whether the player's active character is banned. A player whose active character
-- gets banned stays dead until they load another one. On the client only the local player
-- can be checked.
-- @return [Boolean false when the player has no active character]
function player_meta:is_character_banned()
  if !self:is_character_loaded() then return false end

  local character = self:get_character()

  return character != nil and tobool(character.banned)
end

--- Returns the physical description of the player's character.
-- @return [String the description, or a placeholder text if none is set]
function player_meta:get_phys_desc()
  return self:get_character_var('phys_desc', 'This character has no description!')
end

--- Returns the gender of the player's character as a string.
-- @return [String 'male', 'female' or 'no_gender']
function player_meta:get_gender()
  return Characters.gender_names[self:get_character_var('gender', CHAR_GENDER_NONE)]
end

--- Returns all characters that belong to the player. Clients only know their own characters.
-- @return [List character records on the server, networked character data on the client]
function player_meta:get_all_characters()
  if SERVER then
    return self.record.characters
  else
    self.characters = self.characters or {}
    return self.characters
  end
end
