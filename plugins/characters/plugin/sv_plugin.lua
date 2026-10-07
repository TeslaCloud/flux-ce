local player_meta = FindMetaTable('Player')

--- Makes one of the player's characters their active one. Runs OnCharacterChange if another
-- character was active, networks the basic character data and runs OnActiveCharacterSet.
-- @param id [Number/String character ID; nothing happens if the player has no such character]
function player_meta:set_active_character(id)
  id = tonumber(id)

  if !id then return end

  local real_character = self:get_character_by_id(id)

  if !real_character then return end

  local cur_char_id = self:get_character_id()

  if cur_char_id then
    hook.Run('OnCharacterChange', self, real_character, self:get_character())
  end

  self:set_nv('active_character', tonumber(real_character.id))
  self.current_character = real_character

  local char_data = self:get_character()

  self:set_nv('name', char_data.name or self:steam_name())
  self:set_nv('gender', char_data.gender or CHAR_GENDER_MALE)
  self:set_nv('phys_desc', char_data.phys_desc or '')
  self:set_nv('model', char_data.model or 'models/humans/group01/male_02.mdl')

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

--- Saves the player's active character, if they have one.
-- @see [Characters.save]
function player_meta:save_character()
  if self:is_character_loaded() then
    Characters.save(self, self:get_character())
  end
end
