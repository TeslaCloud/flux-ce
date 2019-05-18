local player_meta = FindMetaTable('Player')

function player_meta:set_active_character(id)
  local cur_char_id = self:get_active_character_id()

  id = tonumber(id)

  if !id then return end

  if cur_char_id then
    hook.run('OnCharacterChange', self, self:get_character(), id)
  end

  local real_character = nil

  for k, v in ipairs(self.record.characters) do
    if v.character_id == id then
      real_character = v
      break
    end
  end

  if !real_character then return end

  self:set_nv('active_character', real_character.id)
  self.current_character = real_character

  local char_data = self:get_character()

  self:set_nv('name', char_data.name or self:steam_name())
  self:set_nv('phys_desc', char_data.phys_desc or '')
  self:set_nv('gender', char_data.gender or CHAR_GENDER_MALE)
  self:set_nv('key', char_data.character_id or -1)
  self:set_nv('model', char_data.model or 'models/humans/group01/male_02.mdl')

  hook.run('OnActiveCharacterSet', self, self:get_character())
end

function player_meta:set_character_var(id, val)
  if isstring(id) then
    self:set_nv(id, val)
    self:get_character()[id] = val
  end
end

function player_meta:set_character_data(key, value)
  error 'Player#set_character_data is deprecated!\n'
end

function player_meta:save_character()
  local char = self:get_character()

  if char then
    Characters.save(self, char)
  end
end
