local player_meta = FindMetaTable("Player")

function player_meta:SetActiveCharacter(id)
  local cur_char_id = self:GetActiveCharacterID()

  if cur_char_id then
    hook.run("OnCharacterChange", self, self:GetCharacter(), id)
  end

  self:set_nv('active_character', tonumber(id))
  self.current_character = self.record.characters[tonumber(id)]

  local char_data = self:GetCharacter()

  self:set_nv('name', char_data.name or self:SteamName())
  self:set_nv('phys_desc', char_data.phys_desc or "")
  self:set_nv('gender', char_data.gender or CHAR_GENDER_MALE)
  self:set_nv('key', char_data.key or -1)
  self:set_nv('model', char_data.model or 'models/humans/group01/male_02.mdl')

  hook.run("OnActiveCharacterSet", self, self:GetCharacter())
end

function player_meta:SetCharacterVar(id, val)
  if isstring(id) then
    self:set_nv(id, val)
    self:GetCharacter()[id] = val
  end
end

function player_meta:SetCharacterData(key, value)
  local char_data = self:GetCharacterVar('data', {})

  char_data[key] = value

  self:SetCharacterVar("data", char_data)
end

function player_meta:SaveCharacter()
  local char = self:GetCharacter()

  if char then
    character.Save(self, char)
  end
end
