local player_meta = FindMetaTable("Player")

function player_meta:SetActiveCharacter(id)
  local curChar = self:GetActiveCharacterID()

  if (curChar) then
    hook.Run("OnCharacterChange", self, self:GetCharacter(), id)
  end

  self:SetNetVar("ActiveCharacter", id)

  local charData = self:GetCharacter()

  self:SetNetVar("name", charData.name or self:SteamName())
  self:SetNetVar("physDesc", charData.physDesc or "")
  self:SetNetVar("gender", charData.gender or CHAR_GENDER_MALE)
  self:SetNetVar("key", charData.key or -1)
  self:SetNetVar("model", charData.model or "models/humans/group01/male_02.mdl")
  self:SetNetVar("inventory", charData.inventory)

  hook.Run("OnActiveCharacterSet", self, self:GetCharacter())
end

function player_meta:SetCharacterVar(id, val)
  if (isstring(id)) then
    self:SetNetVar(id, val)
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
