function Attributes:PostCreateCharacter(player, char_id, char, char_data)
  for k, v in pairs(attributes.get_stored()) do
    local attribute = attributes.find_by_id(k)

    local att = Attribute.new()
      att.character_id = char.id
      att.attr_id = k
      att.value = char_data.attributes[k] or attribute.min
    att:save()

    char.attributes[att.id] = att
  end
end
