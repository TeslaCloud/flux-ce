function Attributes:PostCreateCharacter(player, char_id, char, char_data)
  for k, v in pairs(attributes.get_stored()) do
    local attribute = attributes.find_by_id(k)

    local att = Attribute.new()
      att.character_id = char:get_id()
      att.attr_id = k
      att.value = char_data.attributes[k] or attribute.min
    char.attributes[att:get_id()] = att
  end
end
