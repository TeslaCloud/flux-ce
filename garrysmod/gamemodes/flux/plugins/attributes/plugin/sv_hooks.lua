function AttributesPlugin:PostCreateCharacter(player, char_id, char, char_data)
  for k, v in pairs(Attributes.get_stored()) do
    local attribute = Attributes.find_by_id(k)

    local att = Attribute.new()
      att.attr_id = k
      att.value = char.attributes[k] or attribute.min
    table.insert(char.attributes, att)
  end
end
