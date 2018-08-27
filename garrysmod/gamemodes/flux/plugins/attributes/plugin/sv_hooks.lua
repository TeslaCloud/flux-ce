function flAttributes:RestoreCharacter(player, charID, data)
  local char = character.Get(player, charID)

  if (char) then
    char.attributes = util.JSONToTable(data.attributes or "")

    character.Save(player, charID)
  end
end

function flAttributes:PostCreateCharacter(player, charID, data)
  local char = character.Get(player, charID)

  if (char and data.attributes) then
    char.attributes = data.attributes

    character.Save(player, charID)
  end
end

function flAttributes:OnActiveCharacterSet(player, character)
  player:set_nv("Attributes", character.attributes)
end
