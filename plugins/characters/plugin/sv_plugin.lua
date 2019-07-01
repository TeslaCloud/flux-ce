local player_meta = FindMetaTable('Player')

function player_meta:set_active_character(id)
  id = tonumber(id)

  if !id then return end

  local real_character = self:get_character_by_id(id)

  if !real_character then return end

  local cur_char_id = self:get_character_id()

  if cur_char_id then
    hook.run('OnCharacterChange', self, real_character, self:get_character())
  end

  self:set_nv('active_character', tonumber(real_character.id))
  self.current_character = real_character

  local char_data = self:get_character()

  self:set_nv('name', char_data.name or self:steam_name())
  self:set_nv('gender', char_data.gender or CHAR_GENDER_MALE)
  self:set_nv('phys_desc', char_data.phys_desc or '')
  self:set_nv('model', char_data.model or 'models/humans/group01/male_02.mdl')

  hook.run('OnActiveCharacterSet', self, self:get_character())
end

function player_meta:set_character_var(id, val)
  if isstring(id) then
    self:set_nv(id, val)
    self:get_character()[id] = val
  end
end

function player_meta:save_character()
  local char = self:get_character()

  if char then
    Characters.save(self, char)
  end
end
