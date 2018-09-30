function flAttributes:PostCreateCharacter(player, char_id, char, char_data)
  char.attributes = {}

  for k, v in pairs(attributes.get_stored()) do
    local attribute = attributes.find_by_id(k)

    local att = Attribute.new()
    att.character_id = char.character_id
    att.attr_id = k
    att.value = char_data.attributes[k] or attribute.min
    att:save()
  end
end

function flAttributes:OnCharacterDelete(player, char_id)
  local char = player.record.characters[char_id]

  if char.attributes then
    for k, v in pairs(char.attributes) do
      v:destroy()
    end
  end
end

function flAttributes:SaveCharacterData(player, char)
  for k, v in pairs(char.attributes) do
    v:save()
  end
end
