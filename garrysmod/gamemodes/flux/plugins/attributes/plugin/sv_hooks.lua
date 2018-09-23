function flAttributes:PostCreateCharacter(player, char_id, char, char_data)
  for k, v in pairs(attributes.get_stored()) do
    local atts_table = {}

    atts_table[k] = {}
  end

  char.attributes = atts_table
end

function flAttributes:OnActiveCharacterSet(player, character)
  player:set_nv('attributes', character.attributes)
end
