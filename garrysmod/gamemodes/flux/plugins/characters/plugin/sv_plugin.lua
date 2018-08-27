local player_meta = FindMetaTable("Player")

function player_meta:SetActiveCharacter(id)
  local curChar = self:GetActiveCharacterID()

  if (curChar) then
    hook.run("OnCharacterChange", self, self:GetCharacter(), id)
  end

  self:set_nv("ActiveCharacter", id)

  local charData = self:GetCharacter()

  self:set_nv("name", charData.name or self:SteamName())
  self:set_nv("phys_desc", charData.phys_desc or "")
  self:set_nv("gender", charData.gender or CHAR_GENDER_MALE)
  self:set_nv("key", charData.key or -1)
  self:set_nv("model", charData.model or "models/humans/group01/male_02.mdl")
  self:set_nv("inventory", charData.inventory)

  hook.run("OnActiveCharacterSet", self, self:GetCharacter())
end

function player_meta:SetCharacterVar(id, val)
  if (isstring(id)) then
    self:set_nv(id, val)
    self:GetCharacter()[id] = val
  end
end

function player_meta:SetInventory(newInv)
  if (!istable(newInv)) then return end

  self:SetCharacterVar("inventory", newInv)
  self:SaveCharacter()
end

function player_meta:SetCharacterData(key, value)
  local charData = self:GetCharacterVar("data", {})

  charData[key] = value

  self:SetCharacterVar("data", charData)
end

function player_meta:SaveCharacter()
  local char = self:GetCharacter()

  if (char) then
    character.Save(self, char.id)
  end
end
