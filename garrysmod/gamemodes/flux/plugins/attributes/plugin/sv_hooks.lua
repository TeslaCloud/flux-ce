function flAttributes:PostCreateCharacter(player, charID, char)
  char.attributes = char.attributes or {}
end

function flAttributes:OnActiveCharacterSet(player, character)
  player:set_nv("Attributes", character.attributes)
end
