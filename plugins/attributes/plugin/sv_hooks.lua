function AttributesPlugin:PostCreateCharacter(player, char, char_data)
  for k, v in pairs(Attributes.get_stored()) do
    local attribute = Attribute.new(k)
      attribute.attribute_id = k
      attribute.level = char_data.attributes[k] or v.min
      attribute.progress = 0
    table.insert(char.attributes, attribute)
  end
end

function AttributesPlugin:OnActiveCharacterSet(player, char)
  player:set_nv('attributes', player:get_attributes())
end
